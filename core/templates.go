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
			"{title} — {age day days} old. Still here. Still untouched.",
			"Opened {opens time}. Saved {age day days}. Shipped nothing.",
			"{age day days} on the shelf. It does not improve with age.",
			"{domain}. {age day days}. One bookmark, zero lessons.",
			"Opened {opens time} in {age day days}. That is the whole relationship.",
			"Saved it, then forgot it existed. I did not.",
			"{age day days}. No opens. It is decorative at this point.",
			"This link has outlasted your last three projects.",
			"Saved for later. 'Later' was {age day days} ago.",
			"You have {total} saved. This one has been rotting for {age day days} of them.",
		},
		"to-build": {
			"A buildable thing you did not build. On brand.",
			"This had a {actionability} chance of becoming a project. It became a bookmark.",
			"You saved a tutorial. Tutorials do not build themselves.",
			"There is a starter here with your name on it. You have not started it.",
			"This is the one you will actually build. In 2029.",
		},
		"tool hoard": {
			"You saved {count tool}. Installed 0. The graveyard has excellent lighting.",
			"{count tool} saved, {implemented} shipped. That is a hobby, not a stack.",
			"You keep adding tools instead of using the last {count tool} of them.",
			"New tool, same outcome: {count tool} saved, nothing running.",
			"You do not need another tool. You need to finish the last one.",
		},
		"productivity porn": {
			"You saved {count article} about being productive. You have been {implemented}.",
			"Productivity content about productivity. Groundbreaking.",
			"You read {count article} about focus. You have {total} unopened links. Beautiful.",
			"Saving a productivity article is the opposite of being productive.",
			"You saved {count article} on motivation. Motivation was never the bottleneck.",
		},
		"inspiration": {
			"'{title}' is lovely. It has been {age day days} and it produced nothing.",
			"You saved {count moodboard}. You made {implemented}. Still beautiful, though.",
			"Unsaved inspiration is wallpaper with extra steps.",
			"This was for the project you would start next week. That was {age day days} ago.",
		},
		"self-callout": {
			"You wrote this to yourself, then ignored yourself. Bold.",
			"Your own advice, saved and unread. Bold.",
			"You saved your own note to self. You did not take your own note.",
		},
		"reference": {
			"Reference material, {age day days} old. Referenced never.",
			"This one's fine. It is also entirely unused. Both are true.",
			"Good reference. Never consulted. Filed under 'maybe'.",
		},
		"watch later": {
			"{count video} saved, 0 watched. The list does not shrink by adding to it.",
			"Watch later. {age day days} later. Still later.",
			"{count video} saved. That is not a queue, it is a graveyard with autoplay.",
		},
		"rotting": {
			"This has been rotting since day one. It is not coming back.",
			"Graveyard. That is the official category. I am not being dramatic.",
			"{age day days} dead. Unlike your interest, which is fully dead.",
		},
		"duplicate": {
			"You have saved this {duplicates time}. Once would have been enough. So would zero.",
			"This link, {duplicates time}. You are not going to read it. You never were.",
			"{duplicates copy copies} of the same {category} link. Your hoarding has a theme.",
		},
		"implemented": {
			"Fine. This one you actually used. {opens time} of opens. Almost proud. Almost.",
			"{opens time} on this one. It made the cut. Enjoy it while it lasts.",
			"Opened {opens time}. Still alive. Good for it.",
		},
		"weekly": {
			"You saved {total} this week. You opened {implemented}. Bold week.",
			"{total} saved, {implemented} used. That is the whole story.",
			"{total} new links, zero regret. Impressive.",
		},
		"streak": {
			"{streak week} without a big purge. Proud of you. A little.",
			"{streak week} and you only saved {total}. That is restraint. Rare.",
		},
	},
	ToneSavage: {
		"": {
			"{age day days}. Zero opens. Even a forgotten coupon expires faster.",
			"'{title}'. {age day days}. The page is gathering dust and so are your plans.",
			"You saved this and opened it {opens time}. That is {opens time}. Anyway.",
			"{age day days} of storage for something that helped you 0% of the time.",
			"Congratulations: {age day days} and this link has never once been useful.",
			"You have {total} links. This one contributed nothing. Math checks out.",
			"If you had needed this you would have used it. You did not need it.",
			"This link and your last three projects are all still 'pending'.",
		},
		"to-build": {
			"A buildable thing. Unbuilt. Add it to the pile.",
			"That {actionability} chance of becoming a project became a bookmark instead.",
			"You collected the tutorial. The tutorial did not collect itself.",
		},
		"tool hoard": {
			"{count tool} saved. {implemented} in use. That is a {implemented}% tool collection rate.",
			"Your tool hoard is a museum. Curators cry. You keep buying tickets.",
			"{count tool} in a row without opening the first. That is not taste, that is scrolling.",
			"You are hoarding chrome, not capability.",
		},
		"productivity porn": {
			"{count article} about productivity. {implemented} productivity. Math checks out.",
			"You saved {count article} about doing less, then saved {count article} more. Beautiful.",
			"'{title}'. Productivity porn. The algorithm knows you better than you do.",
			"{implemented} shipped, {count article} about shipping. Tell me about your process.",
		},
		"inspiration": {
			"You collect inspiration like it pays rent. It does not. Nothing shipped does either.",
			"You have saved {count moodboard}. You made {implemented}. The moodboards are winning.",
			"You saved {count moodboard}. Your actual work is invisible.",
		},
		"self-callout": {
			"You saved {duplicates copy copies} of your own advice. That is a cry for help, not a bookmark.",
			"You wrote it, saved it, never read it. That is not self-awareness, that is a museum.",
			"Your own post. Saved. Unopened. Accountability: zero.",
		},
		"reference": {
			"A reference you will never reference. Storage for its own sake.",
			"{age day days} in the hoard. Still has not justified {age day days} of storage.",
		},
		"watch later": {
			"{count video}. {implemented} watched past 30 seconds. The backlog wins.",
			"You have {count video} saved. You will not watch them. You know this. I know this.",
		},
		"rotting": {
			"{age day days}. Zero opens. That is not a bookmark, it is a headstone.",
			"Graveyard. Officially. Come on.",
		},
		"duplicate": {
			"Saved {duplicates time}. Opened {opens time}. You are running a savings scheme with yourself.",
			"{duplicates copy copies}, {implemented} actions. A savings account with no interest rate.",
		},
		"implemented": {
			"You opened this {opens time}. Shocking. You might be a real person.",
			"Used {opens time}. Do not let it go to your head.",
		},
		"weekly": {
			"{total} links this week, {implemented} opened. Your hoard is winning.",
			"You saved {total}. You built {implemented}. The savings rate is a rounding error.",
		},
		"streak": {
			"{streak week} and {total} new links. The restraint lasted exactly {total} links.",
			"{streak week} without hoarding. Genuinely historic. Nobody will ever know.",
		},
	},
	ToneSoft: {
		"": {
			"This has been here for {age day days}. Maybe let it go?",
			"Saved {age day days} ago, opened {opens time}. Want to keep it?",
			"It has been {age day days}. No pressure, but it is not going to read itself.",
			"{age day days} is a long time for something unopened. Your call.",
		},
		"to-build": {
			"This one looked buildable. Want to give it 20 minutes?",
			"Still an unbuilt idea. No shame, just an option.",
		},
		"tool hoard": {
			"You have {count tool} saved. Might be worth picking one and actually using it.",
			"{count tool} here. Want to triage down to the two you actually like?",
		},
		"productivity porn": {
			"Some of these are about feeling productive rather than being productive.",
			"You saved {count article} like this. I can prune them if you want.",
		},
		"inspiration": {
			"Beautiful save. It will be here if you need it, in {age day days} or otherwise.",
			"Still here whenever you are ready.",
		},
		"self-callout": {
			"You saved your own note to yourself. Might be worth rereading.",
			"Kind of brave to save your own advice. Worth a re-read?",
		},
		"reference": {
			"Good reference, whenever you get to it. No rush. (There is a little rush.)",
			"Solid reference. Keep it if you think you will need it.",
		},
		"watch later": {
			"{count video} in your watch-later pile. Want to pick one for tonight?",
			"Still queued. No judgement, from me of all things.",
		},
		"rotting": {
			"Sitting for {age day days}. Ready to let it go whenever you are.",
			"It has been {age day days}. I can clear it if you want.",
		},
		"duplicate": {
			"You have {duplicates copy copies} of this one. Happy to clean that up.",
			"I found {duplicates copy copies} of this. Want them merged?",
		},
		"implemented": {
			"This one got {opens time} of opens. Nice.",
			"You actually used this one. Good.",
		},
		"weekly": {
			"This week: {total} saved, {implemented} opened. Not bad. Room to improve.",
			"{total} saved, {implemented} opened. A reasonable week.",
		},
		"streak": {
			"{streak week} of this now. Quietly impressive.",
			"{streak week} streak. Keep it going.",
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
