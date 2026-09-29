package core

import (
	"fmt"
	"sort"
	"time"
)

const CullStaleDays = 14

const MaxIndividualProposals = 11

type ProposalKind int

const (
	ProposalGroup ProposalKind = iota
	ProposalIndividual
)

func (k ProposalKind) String() string {
	if k == ProposalGroup {
		return "group"
	}
	return "individual"
}

type Item struct {
	Scorable
	Verdict Verdict
}

func MakeItem(s Scorable, now time.Time) Item {
	return Item{Scorable: s, Verdict: Judge(s, now)}
}

type Proposal struct {
	Kind     ProposalKind
	Category Category

	Count int

	AvgActionability float64

	Line string

	Pool string

	Items []Scorable
}

type CullReport struct {
	Week int

	SavedThisWeek  int
	OpenedThisWeek int
	ForgedThisWeek int
	TotalHoard     int
	StreakWeeks    int

	Headline string

	Proposals []Proposal

	Cullable int
}

func ShouldPropose(s Scorable, v Verdict, now time.Time) bool {
	if v.Hoard.Total < CullProposeThreshold {
		return false
	}

	if s.LastOpenedAt.IsZero() {
		return true
	}
	return now.Sub(s.LastOpenedAt).Hours()/24 >= CullStaleDays
}

func BuildCullReport(items []Item, stats ReportStats, now time.Time, week int, tone Tone) CullReport {
	rep := CullReport{
		Week:           week,
		SavedThisWeek:  stats.SavedThisWeek,
		OpenedThisWeek: stats.OpenedThisWeek,
		ForgedThisWeek: stats.ForgedThisWeek,
		TotalHoard:     stats.TotalHoard,
		StreakWeeks:    stats.StreakWeeks,
	}

	byCategory := map[Category][]Item{}
	for _, it := range items {
		if ShouldPropose(it.Scorable, it.Verdict, now) {
			byCategory[it.Verdict.Category] = append(byCategory[it.Verdict.Category], it)
		}
	}

	var individuals []Item
	categories := make([]Category, 0, len(byCategory))
	for cat := range byCategory {
		categories = append(categories, cat)
	}
	sort.Slice(categories, func(i, j int) bool { return categories[i] < categories[j] })

	budget := MaxIndividualProposals

	for _, cat := range categories {
		group := byCategory[cat]
		avg := 0.0
		for _, it := range group {
			avg += it.Verdict.Action.Total
		}
		avg /= float64(len(group))

		sort.SliceStable(group, func(i, j int) bool {
			return group[i].Verdict.Hoard.Total > group[j].Verdict.Hoard.Total
		})

		if len(group) > 3 && avg < PornThreshold {
			n := len(group)
			if n > budget {
				n = budget
			}
			if n <= 0 {
				continue
			}
			rep.Proposals = append(rep.Proposals, Proposal{
				Kind:             ProposalGroup,
				Category:         cat,
				Count:            n,
				AvgActionability: round2(avg),
				Items:            scorableOf(group[:n]),
			})
			budget -= n
			continue
		}
		individuals = append(individuals, group...)
	}

	sort.SliceStable(individuals, func(i, j int) bool {
		return individuals[i].Verdict.Hoard.Total > individuals[j].Verdict.Hoard.Total
	})
	if len(individuals) > budget {
		individuals = individuals[:max(budget, 0)]
	}
	for _, it := range individuals {
		rep.Proposals = append(rep.Proposals, Proposal{
			Kind:             ProposalIndividual,
			Category:         it.Verdict.Category,
			Count:            1,
			AvgActionability: round2(it.Verdict.Action.Total),
			Items:            []Scorable{it.Scorable},
		})
	}

	vars := make([]RoastVars, len(rep.Proposals))
	for i, p := range rep.Proposals {
		total := 0
		for _, s := range p.Items {
			total += s.OpenCount
		}
		vars[i] = RoastVars{
			Title:          firstTitle(p.Items),
			Domain:         firstDomain(p.Items),
			Category:       p.Category,
			Count:          p.Count,
			AgeDays:        int(DaysSince(firstCreated(p.Items), now)),
			DuplicateCount: maxInt(p.Items, func(s Scorable) int { return s.DuplicateCount }),
			OpenCount:      total,
			Total:          stats.TotalHoard,
			StreakWeeks:    stats.StreakWeeks,
			Grouped:        p.Kind == ProposalGroup,
			Actionability:  p.AvgActionability,
		}

		if p.Kind == ProposalGroup {
			vars[i].ImplementedCount = stats.ForgedThisWeek
		}
	}
	roasts := RoastReport(vars, week, tone)
	for i := range rep.Proposals {
		rep.Proposals[i].Line = roasts[i].Line
		rep.Proposals[i].Pool = roasts[i].Pool
		rep.Cullable += rep.Proposals[i].Count
	}

	rep.Headline = headlineFor(rep)
	return rep
}

type ReportStats struct {
	SavedThisWeek  int
	OpenedThisWeek int
	ForgedThisWeek int
	TotalHoard     int
	StreakWeeks    int
}

func headlineFor(r CullReport) string {
	if r.Cullable == 0 {
		switch {
		case r.SavedThisWeek == 0:
			return "You saved nothing this week. I am suspicious, but I respect it."
		case r.OpenedThisWeek >= r.SavedThisWeek:
			return fmt.Sprintf("You saved %d and opened %d. New record for actually reading things.", r.SavedThisWeek, r.OpenedThisWeek)
		default:
			return fmt.Sprintf("You saved %d this week. You opened %d. No shame. Yet.", r.SavedThisWeek, r.OpenedThisWeek)
		}
	}
	return fmt.Sprintf("You saved %d this week. %d of them are rotting. Shall I?", r.SavedThisWeek, r.Cullable)
}

func scorableOf(items []Item) []Scorable {
	out := make([]Scorable, 0, len(items))
	for _, it := range items {
		out = append(out, it.Scorable)
	}
	return out
}

func firstTitle(items []Scorable) string {
	if len(items) == 0 {
		return ""
	}
	return items[0].Title
}

func firstDomain(items []Scorable) string {
	if len(items) == 0 {
		return ""
	}
	return items[0].Domain
}

func firstCreated(items []Scorable) time.Time {
	if len(items) == 0 {
		return time.Time{}
	}
	return items[0].CreatedAt
}

func maxInt(items []Scorable, f func(Scorable) int) int {
	m := 0
	for _, s := range items {
		if v := f(s); v > m {
			m = v
		}
	}
	return m
}
