package core

import (
	"fmt"
	"math/rand/v2"
	"regexp"
	"strconv"
	"strings"
)

type Tone int

const (
	ToneSoft Tone = iota
	ToneBlunt
	ToneSavage
)

func (t Tone) String() string {
	switch t {
	case ToneSoft:
		return "soft"
	case ToneSavage:
		return "savage"
	default:
		return "blunt"
	}
}

type RoastVars struct {
	Title            string
	Domain           string
	Category         Category
	Count            int
	AgeDays          int
	DuplicateCount   int
	OpenCount        int
	ImplementedCount int
	Total            int
	StreakWeeks      int

	Grouped bool

	Actionability float64
}

type Roast struct {
	Line     string `json:"line"`
	Tone     Tone   `json:"tone"`
	Template string `json:"template"`
	Pool     string `json:"pool"`
}

var pools = map[Tone]map[string][]string{
	ToneBlunt: {
		"": {
			"{age day days} old. Never opened.",
			"Saved once, read never. {age day days} of that.",
			"Opened {opens time} in {age day days}. That is the whole relationship.",
			"You have {total} saved. This one has been here for {age day days} of them.",
			"'{title}' has been waiting {age day days}. Waiting is not the same as planning.",
			"{domain}. {age day days}. You know what it is about. You have not checked.",
			"Reading about it was the part you did.",
			"{age day days}, and no reason has arrived yet. That is usually the answer.",
		},
		"to-build": {
			"A tutorial. The part where you build it has not started.",
			"{actionability} chance of becoming a project. It is currently a bookmark.",
			"Things in this folder are things you meant to make.",
			"There is a starting point here. It is not been taken.",
		},
		"tool hoard": {
			"{count tool} saved, {implemented} in use. Finishing one beats choosing four.",
			"Another tool. The last {count tool} are still waiting on you.",
			"You do not need another tool. You need the last one to be finished.",
			"{count tool} tools is a collection. One in use is a setup.",
		},
		"productivity porn": {
			"{count article} about being productive. You have been {implemented}.",
			"Reading about focus does not focus anything.",
			"You saved {count article} on doing less. You saved {count article}.",
			"This is about the work. It is not the work.",
			"{count article} on motivation. The bottleneck has never been motivation.",
		},
		"inspiration": {
			"'{title}' is {age day days} old and has produced nothing yet.",
			"{count moodboard} collected, {implemented} made.",
			"Waiting on a moodboard is not the same as starting badly.",
			"This was for something you would begin next week. That was {age day days} ago.",
		},
		"self-callout": {
			"Your own note, {age day days} unread.",
			"You wrote this. It is still advice you have not taken.",
			"Saved your own words and left them there.",
		},
		"reference": {
			"Reference material, {age day days} old. Not referred to yet.",
			"This one is fine. It is also not in use. Both are true.",
			"Saved for a project that has not been specified.",
		},
		"watch later": {
			"{count video} queued, {implemented} watched.",
			"The list does not get shorter by adding to it.",
			"'{title}'. Still later. Later was {age day days} ago.",
		},
		"rotting": {
			"{age day days} and not coming back. Worth keeping anyway?",
			"Past the point where interest and storage are in proportion.",
			"This one has been done for a while.",
		},
		"duplicate": {
			"Saved {duplicates time}. Once was enough.",
			"{duplicates copy copies} of the same {category} link.",
			"You have {duplicates copy copies} of this. The first one was the one.",
		},
		"implemented": {
			"Opened {opens time}. This one is doing its job.",
			"{opens time} on this one. Worth keeping.",
		},
		"weekly": {
			"{total} saved, {implemented} opened.",
			"This week: {total} in, {implemented} used. The rest is pending.",
		},
		"streak": {
			"{streak week} without a purge.",
			"{streak week} of this. It is not accumulating.",
		},
	},
	ToneSavage: {
		"": {
			"{age day days}. Zero opens. You already knew.",
			"'{title}'. {age day days}. You are not going to open this and you know it.",
			"Opened {opens time} in {age day days}. That is the entire story.",
			"{age day days} of storage for something that has never been useful to you.",
			"You have {total} links and this is one of the ones that helped with none of it.",
			"If this had mattered you would have used it. You did not, and that is information.",
			"'{title}'. Reading about the work is doing something. Just not the work.",
			"{age day days}. The interest left before the bookmark did.",
		},
		"to-build": {
			"Buildable. Unbuilt. That is the whole summary.",
			"{actionability} chance of becoming a project, and it became a bookmark instead.",
			"You collected the tutorial. The tutorial did not collect itself.",
		},
		"tool hoard": {
			"{count tool} saved, {implemented} in use. That is a {implemented}% collection rate.",
			"You are storing chrome, not capability.",
			"{count tool} in a row without opening the first one.",
			"Every new tool makes the last {count tool} less likely to be finished.",
		},
		"productivity porn": {
			"{count article} about productivity. {implemented} productivity.",
			"'{title}'. About focus, from a feed. While {total} links go unread.",
			"You saved {count article} about doing less and then saved {count article} more.",
			"{implemented} shipped against {count article} about shipping.",
		},
		"inspiration": {
			"You collect inspiration the way other people collect debt.",
			"{count moodboard} saved, {implemented} made. The moodboards are winning.",
			"Your actual work is invisible and the ideas are not.",
		},
		"self-callout": {
			"You wrote this and then did not read it. That is the whole problem, in miniature.",
			"{duplicates copy copies} of your own advice, all unread.",
			"You already know what this says. You saved it anyway.",
		},
		"reference": {
			"A reference you have not referred to in {age day days}.",
			"Storage, for {age day days}, on the chance that a project gets specified.",
		},
		"watch later": {
			"{count video} saved. {implemented} watched. The queue is not the watching.",
			"You have {count video} here and no evening that is going to open them.",
		},
		"rotting": {
			"{age day days}. This is not a bookmark any more, it is just storage.",
			"Done. Quietly, completely, {age day days} ago.",
		},
		"duplicate": {
			"Saved {duplicates time}, opened {opens time}. You are running a savings scheme.",
			"{duplicates copy copies}, {implemented} actions. No interest.",
		},
		"implemented": {
			"Opened {opens time}. It is on the small list of ones that earned their place.",
			"Used {opens time}. Keep this one.",
		},
		"weekly": {
			"{total} in, {implemented} used. The gap is where the time went.",
			"{total} saved this week. {implemented} of them will still matter in a year.",
		},
		"streak": {
			"{streak week}, and the last {total} are the ones that broke it.",
			"{streak week} without a purge. That is not restraint, that is delay.",
		},
	},
	ToneSoft: {
		"": {
			"{age day days} old, never opened.",
			"Saved {age day days} ago. Still here whenever you want it.",
			"Opened {opens time}. Kept.",
			"None of these have been read. No rush, and also: no rush.",
		},
		"to-build": {
			"Something buildable, {age day days} in the folder.",
			"Not started. Available whenever you pick it up.",
		},
		"tool hoard": {
			"{count tool} saved here. One of them is usually the one.",
			"Tools are cheap and finishing is not.",
		},
		"productivity porn": {
			"{count article} here about productivity.",
			"Some of this is about feeling productive. Worth separating from the rest.",
		},
		"inspiration": {
			"'{title}'. {age day days} old.",
			"Kept. Nothing depends on it yet.",
		},
		"self-callout": {
			"Your own note to yourself, unread.",
			"Saved by you, for you.",
		},
		"reference": {
			"Reference, {age day days} old.",
			"Saved for a project not yet specified.",
		},
		"watch later": {
			"{count video} queued.",
			"'{title}'. {age day days} later.",
		},
		"rotting": {
			"{age day days}. No longer relevant.",
			"Done, {age day days} ago.",
		},
		"duplicate": {
			"{duplicates copy copies} of this one.",
			"Saved {duplicates time}.",
		},
		"implemented": {
			"Opened {opens time}.",
			"This one got used.",
		},
		"weekly": {
			"{total} saved, {implemented} opened.",
			"This week: {total} in, {implemented} used.",
		},
		"streak": {
			"{streak week} of not culling.",
			"{streak week} of this.",
		},
	},
}

var nounSlot = regexp.MustCompile(`\{(count|age|opens|duplicates|implemented|total|streak) ([a-z]+)(?: ([a-z]+))?\}`)

func (v RoastVars) intField(name string) int {
	switch name {
	case "count":
		return v.Count
	case "age":
		return v.AgeDays
	case "opens":
		return v.OpenCount
	case "duplicates":
		return v.DuplicateCount
	case "implemented":
		return v.ImplementedCount
	case "total":
		return v.Total
	case "streak":
		return v.StreakWeeks
	}
	return 0
}

var plainSlots = []string{
	"{title}", "{domain}", "{category}", "{age}", "{count}",
	"{duplicates}", "{opens}", "{implemented}", "{total}", "{streak}",
	"{actionability}",
}

func Render(tmpl string, v RoastVars) string {
	out := nounSlot.ReplaceAllStringFunc(tmpl, func(m string) string {
		g := nounSlot.FindStringSubmatch(m)
		noun, pluralNoun := g[2], g[3]
		if pluralNoun == "" {
			pluralNoun = noun + "s"
		}
		n := v.intField(g[1])
		return fmt.Sprintf("%d %s", n, pluralize(n, noun, pluralNoun))
	})

	repl := strings.NewReplacer(
		"{title}", fallback(v.Title, fallback(v.Domain, "that link")),
		"{domain}", fallback(v.Domain, "somewhere"),
		"{category}", string(v.Category),
		"{age}", strconv.Itoa(v.AgeDays),
		"{count}", strconv.Itoa(v.Count),
		"{duplicates}", strconv.Itoa(v.DuplicateCount),
		"{opens}", strconv.Itoa(v.OpenCount),
		"{implemented}", strconv.Itoa(v.ImplementedCount),
		"{total}", strconv.Itoa(v.Total),
		"{streak}", strconv.Itoa(v.StreakWeeks),
		"{actionability}", strconv.FormatFloat(clamp(v.Actionability, 0, 1)*100, 'f', 0, 64)+"%",
	)
	out = repl.Replace(out)
	return cleanup(out)
}

func pluralize(n int, singular, plural string) string {
	if n == 1 {
		return singular
	}
	return plural
}

func fallback(s, def string) string {
	if strings.TrimSpace(s) == "" {
		return def
	}
	return s
}

func cleanup(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	s = strings.ReplaceAll(s, " ,", ",")
	s = strings.ReplaceAll(s, " .", ".")
	s = strings.ReplaceAll(s, " !", "!")
	s = strings.ReplaceAll(s, " ?", "?")
	return s
}

func SlotsUsed(tmpl string) []string {
	var out []string
	for _, s := range plainSlots {
		if strings.Contains(tmpl, s) {
			out = append(out, s)
		}
	}
	for _, m := range nounSlot.FindAllString(tmpl, -1) {
		out = append(out, m)
	}
	return out
}

type candidate struct {
	tmpl string
	pool string
}

func resolveTone(t Tone) (Tone, map[string][]string) {
	if byP, ok := pools[t]; ok {
		return t, byP
	}
	return ToneBlunt, pools[ToneBlunt]
}

func RoastFor(v RoastVars, week int, tone Tone) Roast {
	tone, byP := resolveTone(tone)
	used := map[string]bool{}
	return roastWithAvoid(v, week, tone, byP, used)
}

func RoastReport(items []RoastVars, week int, tone Tone) []Roast {
	tone, byP := resolveTone(tone)
	used := make(map[string]bool, len(items))
	out := make([]Roast, 0, len(items))
	for _, v := range items {
		out = append(out, roastWithAvoid(v, week, tone, byP, used))
	}
	return out
}

func roastWithAvoid(v RoastVars, week int, tone Tone, byP map[string][]string, used map[string]bool) Roast {
	candidates := candidatePool(byP, v)

	rng := rand.New(rand.NewPCG(
		uint64(week)*0x9E3779B97F4A7C15,
		stableHash(v.Title+v.Domain+string(v.Category)),
	))

	pool := make([]candidate, len(candidates))
	copy(pool, candidates)
	rng.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })

	for _, c := range pool {
		if !used[c.tmpl] {
			used[c.tmpl] = true
			return Roast{Line: Render(c.tmpl, v), Tone: tone, Template: c.tmpl, Pool: c.pool}
		}
	}
	if len(pool) == 0 {

		return Roast{Line: "Still here. Still unread.", Tone: tone, Pool: "fallback"}
	}
	return Roast{Line: Render(pool[0].tmpl, v), Tone: tone, Template: pool[0].tmpl, Pool: pool[0].pool}
}

func candidatePool(byP map[string][]string, v RoastVars) []candidate {
	primary := ""

	switch {

	case v.Grouped:
		primary = string(v.Category)
		if _, ok := byP[primary]; !ok {
			primary = ""
		}
	case v.DuplicateCount > 0 && len(byP["duplicate"]) > 0:
		primary = "duplicate"
	case v.OpenCount > 0 && len(byP["implemented"]) > 0:
		primary = "implemented"
	default:
		primary = string(v.Category)
		if _, ok := byP[primary]; !ok {
			primary = ""
		}
	}

	merged := make([]candidate, 0, 32)
	for _, t := range byP[primary] {
		merged = append(merged, candidate{tmpl: t, pool: primary})
	}

	if v.Grouped {
		return dedupeCandidates(merged)
	}

	for _, t := range byP[""] {
		merged = append(merged, candidate{tmpl: t, pool: ""})
	}
	return dedupeCandidates(merged)
}

func dedupeCandidates(in []candidate) []candidate {
	seen := make(map[string]bool, len(in))
	out := make([]candidate, 0, len(in))
	for _, c := range in {
		if !seen[c.tmpl] {
			seen[c.tmpl] = true
			out = append(out, c)
		}
	}
	return out
}

func stableHash(s string) uint64 {
	return fnv1a64(strings.ToLower(s))
}

func TemplateCount(tone Tone) int {
	byP, ok := pools[tone]
	if !ok {
		return 0
	}
	seen := map[string]bool{}
	n := 0
	for _, list := range byP {
		for _, t := range list {
			if !seen[t] {
				seen[t] = true
				n++
			}
		}
	}
	return n
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
