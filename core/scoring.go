package core

import (
	"fmt"
	"math"
	"regexp"
	"sort"
	"strings"
	"time"
)

type Category string

const (
	CategoryToBuild          Category = "to-build"
	CategoryToolHoard        Category = "tool hoard"
	CategoryProductivityPorn Category = "productivity porn"
	CategoryInspiration      Category = "inspiration"
	CategorySelfCallout      Category = "self-callout"
	CategoryReference        Category = "reference"
	CategoryWatchLater       Category = "watch later"
	CategoryRotting          Category = "rotting"
)

var AllCategories = []Category{
	CategoryReference,
	CategoryToBuild,
	CategoryInspiration,
	CategoryToolHoard,
	CategoryWatchLater,
	CategoryProductivityPorn,
	CategorySelfCallout,
	CategoryRotting,
}

func (c Category) String() string { return string(c) }

func (c Category) Valid() bool {
	for _, k := range AllCategories {
		if k == c {
			return true
		}
	}
	return false
}

type HoardBand int

const (
	BandFresh HoardBand = iota
	BandStale
	BandRotting
	BandGraveyard
)

func (b HoardBand) String() string {
	switch b {
	case BandFresh:
		return "fresh"
	case BandStale:
		return "stale"
	case BandRotting:
		return "rotting"
	default:
		return "graveyard"
	}
}

const (
	WeightAgeDecay   = 0.4
	WeightNeglect    = 0.4
	WeightDuplicate  = 0.2
	MaxAgeDays       = 60.0
	OpenCountToClear = 3.0
	DuplicateStep    = 25.0
)

const CullProposeThreshold = 75.0

const GraveyardThreshold = 86.0

type Scorable struct {
	ID             string
	URL            string
	Domain         string
	Title          string
	ReadableText   string
	OpenCount      int
	DuplicateCount int
	CreatedAt      time.Time
	LastOpenedAt   time.Time
}

type HoardScore struct {
	Total       float64   `json:"total"`
	Band        HoardBand `json:"band"`
	AgeDecay    float64   `json:"ageDecay"`
	Neglect     float64   `json:"neglect"`
	Duplication float64   `json:"duplication"`
	AgeDays     float64   `json:"ageDays"`
	Explanation string    `json:"explanation"`
}

func ComputeHoardScore(s Scorable, now time.Time) HoardScore {
	ageDays := DaysSince(s.CreatedAt, now)

	ageDecay := clamp(ageDays/MaxAgeDays, 0, 1) * 100
	neglect := clamp(1-(float64(s.OpenCount)/OpenCountToClear), 0, 1) * 100
	dup := clamp(float64(s.DuplicateCount)*DuplicateStep, 0, 100)

	total := (ageDecay * WeightAgeDecay) + (neglect * WeightNeglect) + (dup * WeightDuplicate)
	total = clamp(total, 0, 100)

	h := HoardScore{
		Total:       round1(total),
		Band:        bandFor(total),
		AgeDecay:    round1(ageDecay),
		Neglect:     round1(neglect),
		Duplication: round1(dup),
		AgeDays:     round1(ageDays),
	}
	h.Explanation = explainHoard(h, s)
	return h
}

func bandFor(score float64) HoardBand {
	switch {
	case score <= 30:
		return BandFresh
	case score <= 60:
		return BandStale
	case score < GraveyardThreshold:
		return BandRotting
	default:
		return BandGraveyard
	}
}

func explainHoard(h HoardScore, s Scorable) string {
	var parts []string
	if h.AgeDecay >= 60 {
		parts = append(parts, fmt.Sprintf("%d days old", int(h.AgeDays)))
	}
	if s.OpenCount == 0 {
		parts = append(parts, "opened never")
	} else if s.OpenCount < OpenCountToClear {
		parts = append(parts, fmt.Sprintf("opened %d time%s", s.OpenCount, plural(s.OpenCount)))
	}
	if s.DuplicateCount > 0 {
		parts = append(parts, fmt.Sprintf("saved %dx", s.DuplicateCount))
	}
	if len(parts) == 0 {
		return "Nothing wrong with this one yet."
	}
	return "Because it is " + humanList(parts) + "."
}

func humanList(parts []string) string {
	switch len(parts) {
	case 0:
		return ""
	case 1:
		return parts[0]
	case 2:
		return parts[0] + " and " + parts[1]
	default:
		return strings.Join(parts[:len(parts)-1], ", ") + " and " + parts[len(parts)-1]
	}
}

const (
	ActionSaturationPoint = 8.0
	PornPenalty           = 0.5
	ActionableThreshold   = 0.70
	ReferenceThreshold    = 0.40
	PornThreshold         = 0.30
)

var actionVerbs = []string{
	"how to", "tutorial", "build", "template", "boilerplate", "github",
	"figma file", "tool", "api", "clone", "step by step", "walkthrough",
	"cheat sheet", "starter", "open source", "install", "setup", "implement",
	"refactor", "deploy", "snippet", "source code", "documentation", "learn",
	"course", "blueprint", "framework", "library", "sdk", "command line",
	"scaffold", "migrate", "optimize", "debug", "ship", "prototype",
}

var inspirationPorn = []string{
	"why you should", "10 ways", "20 ways", "50 ways", "ultimate list",
	"ultimate guide", "productivity", "motivation", "motivational",
	"you're doing it wrong", "you are doing it wrong", "mindset",
	"self improvement", "self-improvement", "life hack", "lifehacks",
	"morning routine", "daily routine", "habit", "hustle", "grind",
	"burnout", "success", "top 10", "best tools", "a year of",
	"what i learned", "lessons learned", "things i wish", "notes on",
	"unlock your", "game changer", "changed my life", "here's why",
}

var (
	actionVerbPatterns = compilePatterns(actionVerbs)
	pornPatterns       = compilePatterns(inspirationPorn)
)

func compilePatterns(terms []string) []*regexp.Regexp {
	out := make([]*regexp.Regexp, 0, len(terms))
	for _, t := range terms {
		out = append(out, regexp.MustCompile(`(?i)\b`+regexp.QuoteMeta(t)+`\b`))
	}
	return out
}

type ActionScore struct {
	Total       float64  `json:"total"`
	ActionHits  int      `json:"actionHits"`
	PornHits    int      `json:"pornHits"`
	Matched     []string `json:"matched"`
	Explanation string   `json:"explanation"`
}

func ComputeActionability(title, readableText string) ActionScore {
	haystack := title + " \n " + readableText

	action, actionHits := countDistinct(actionVerbPatterns, actionVerbs, haystack)
	porn, pornHits := countDistinct(pornPatterns, inspirationPorn, haystack)

	raw := (float64(actionHits) - PornPenalty*float64(pornHits)) / ActionSaturationPoint
	total := clamp(raw, 0, 1)

	as := ActionScore{
		Total:      round2(total),
		ActionHits: actionHits,
		PornHits:   pornHits,
		Matched:    append(action, porn...),
	}
	as.Explanation = explainAction(as)
	return as
}

func countDistinct(patterns []*regexp.Regexp, terms []string, haystack string) ([]string, int) {
	var hits []string
	for i, re := range patterns {
		if re.MatchString(haystack) {
			hits = append(hits, terms[i])
		}
	}
	sort.Strings(hits)
	return hits, len(hits)
}

func explainAction(a ActionScore) string {
	switch {
	case a.Total >= ActionableThreshold:
		return fmt.Sprintf("%d build signals. This one is forgeable.", a.ActionHits)
	case a.Total >= ReferenceThreshold:
		return fmt.Sprintf("%d build signals. Solid reference.", a.ActionHits)
	case a.PornHits > a.ActionHits:
		return fmt.Sprintf("%d inspiration signals, %d build signals. It's a vibe, not a plan.", a.PornHits, a.ActionHits)
	default:
		return "Neither useful nor inspiring. Just a link."
	}
}

type Verdict struct {
	Category      Category    `json:"category"`
	Hoard         HoardScore  `json:"hoard"`
	Action        ActionScore `json:"action"`
	ShouldPropose bool        `json:"shouldPropose"`
}

func Judge(s Scorable, now time.Time) Verdict {
	h := ComputeHoardScore(s, now)
	a := ComputeActionability(s.Title, s.ReadableText)
	cat := Categorize(CategorizeInput{
		Domain:        s.Domain,
		Title:         s.Title,
		ReadableText:  s.ReadableText,
		Actionability: a.Total,
	})
	return Verdict{
		Category:      cat,
		Hoard:         h,
		Action:        a,
		ShouldPropose: h.Total >= CullProposeThreshold,
	}
}

func DaysSince(t, now time.Time) float64 {
	if t.IsZero() {
		return 0
	}
	d := now.Sub(t).Hours() / 24
	if d < 0 {
		return 0
	}
	return d
}

func clamp(v, lo, hi float64) float64 {
	return math.Min(math.Max(v, lo), hi)
}

func round1(f float64) float64 { return math.Round(f*10) / 10 }
func round2(f float64) float64 { return math.Round(f*100) / 100 }

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
