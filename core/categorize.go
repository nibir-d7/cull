package core

import (
	"bufio"
	"embed"
	"strings"
	"sync"
)

//go:embed data/domains.txt
var domainFS embed.FS

//go:embed data/domains.txt
var domainData string

var (
	domainOnce  sync.Once
	domainIndex map[string]Category
)

func loadDomains() map[string]Category {
	domainOnce.Do(func() {
		domainIndex = make(map[string]Category, 256)
		sc := bufio.NewScanner(strings.NewReader(domainData))
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}

			fields := strings.Fields(line)
			if len(fields) < 2 {
				continue
			}
			dom := normalizeDomain(fields[0])
			cat := Category(strings.ToLower(strings.Join(fields[1:], " ")))
			if !cat.Valid() {
				continue
			}
			domainIndex[dom] = cat
		}
	})
	return domainIndex
}

func DomainCategory(domain string) (Category, bool) {
	dom := normalizeDomain(domain)
	if dom == "" {
		return "", false
	}
	idx := loadDomains()
	if c, ok := idx[dom]; ok {
		return c, true
	}

	for d, c := range idx {
		if strings.HasSuffix(dom, "."+d) {
			return c, true
		}
	}
	return "", false
}

func DomainOf(raw string) string { return normalizeDomain(raw) }

func normalizeDomain(raw string) string {
	d := strings.ToLower(strings.TrimSpace(raw))
	if d == "" {
		return ""
	}
	if i := strings.Index(d, "://"); i >= 0 {
		d = d[i+3:]
	}
	if i := strings.IndexAny(d, "/?#"); i >= 0 {
		d = d[:i]
	}
	if i := strings.LastIndex(d, "@"); i >= 0 {
		d = d[i+1:]
	}
	if i := strings.Index(d, ":"); i >= 0 {
		d = d[:i]
	}
	d = strings.TrimPrefix(d, "www.")
	return strings.TrimSuffix(d, ".")
}

type CategorizeInput struct {
	Domain        string
	Title         string
	ReadableText  string
	Actionability float64
}

const selfCalloutLedeChars = 500

type rule struct {
	name string
	test func(in CategorizeInput) (Category, bool)
}

var rules = []rule{

	{
		name: "code-hosting",
		test: func(in CategorizeInput) (Category, bool) {
			switch {
			case isDomain(in.Domain, "github.com", "gitlab.com", "codeberg.org", "sourceforge.net"):
				return CategoryToBuild, true
			}
			return "", false
		},
	},

	{
		name: "figma-actionable",
		test: func(in CategorizeInput) (Category, bool) {
			if containsAny(strings.ToLower(in.Title+" "+in.ReadableText), "figma", "penpot", "sketch file") &&
				in.Actionability >= 0.5 {
				return CategoryToBuild, true
			}
			return "", false
		},
	},

	{
		name: "social-tool",
		test: func(in CategorizeInput) (Category, bool) {
			if !isDomain(in.Domain, "twitter.com", "x.com", "t.co", "threads.net", "bsky.app", "linkedin.com") {
				return "", false
			}
			if containsAny(strings.ToLower(in.Title+" "+in.ReadableText),
				"tool", "app", "saas", "extension", "plugin", "library", "framework") {
				return CategoryToolHoard, true
			}
			return "", false
		},
	},

	{
		name: "video",
		test: func(in CategorizeInput) (Category, bool) {
			if isDomain(in.Domain, "youtube.com", "youtu.be", "vimeo.com", "twitch.tv", "dailymotion.com") {
				return CategoryWatchLater, true
			}
			return "", false
		},
	},

	{
		name: "self-callout",
		test: func(in CategorizeInput) (Category, bool) {
			body := collapseSpaces(in.ReadableText)
			if len(body) > selfCalloutLedeChars {
				body = body[:selfCalloutLedeChars]
			}
			hay := strings.ToLower(in.Title + " " + body)

			if containsAny(hay,
				"i should have", "i keep saying", "i'll get to it", "i will get to it",
				"why we fail", "what went wrong", "lessons learned the hard way",
				"i burned out", "note to self", "one day i", "next time i",
				"i never finished", "i gave up on", "stopped halfway") {
				return CategorySelfCallout, true
			}
			return "", false
		},
	},

	{
		name: "productivity-porn",
		test: func(in CategorizeInput) (Category, bool) {
			if in.Actionability >= PornThreshold {
				return "", false
			}
			hay := strings.ToLower(in.Title + " " + in.ReadableText)
			if containsAny(hay, "productivity", "motivation", "mindset", "habits", "routine",
				"self-improvement", "self improvement", "hustle", "burnout", "morning routine") {
				return CategoryProductivityPorn, true
			}
			return "", false
		},
	},

	{
		name: "actionable-on-build-platform",
		test: func(in CategorizeInput) (Category, bool) {
			if in.Actionability < ReferenceThreshold {
				return "", false
			}
			if isDomain(in.Domain, "stackoverflow.com", "medium.com", "dev.to", "hashnode.dev",
				"npmjs.com", "pypi.org", "crates.io", "pkg.go.dev", "readthedocs.io") {
				return CategoryToBuild, true
			}
			return "", false
		},
	},

	{
		name: "inspiration",
		test: func(in CategorizeInput) (Category, bool) {
			if in.Actionability >= ReferenceThreshold {
				return "", false
			}
			if isDomain(in.Domain, "dribbble.com", "behance.net", "pinterest.com", "awwwards.com",
				"are.na", "cosmos.so", "instagram.com", "unsplash.com") {
				return CategoryInspiration, true
			}
			return "", false
		},
	},

	{
		name: "domain-map",
		test: func(in CategorizeInput) (Category, bool) {
			return DomainCategory(in.Domain)
		},
	},
}

func Categorize(in CategorizeInput) Category {
	for _, r := range rules {
		if cat, ok := r.test(in); ok {
			return cat
		}
	}
	return CategoryReference
}

func RuleNames() []string {
	out := make([]string, 0, len(rules))
	for _, r := range rules {
		out = append(out, r.name)
	}
	return out
}

func isDomain(raw string, hosts ...string) bool {
	d := normalizeDomain(raw)
	if d == "" {
		return false
	}
	for _, h := range hosts {
		if d == h || strings.HasSuffix(d, "."+h) {
			return true
		}
	}
	return false
}

func containsAny(haystack string, needles ...string) bool {
	for _, n := range needles {
		if strings.Contains(haystack, n) {
			return true
		}
	}
	return false
}

func collapseSpaces(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	space := false
	for _, r := range s {
		if r == ' ' || r == '\t' || r == '\n' || r == '\r' {
			space = true
			continue
		}
		if space && b.Len() > 0 {
			b.WriteByte(' ')
		}
		space = false
		b.WriteRune(r)
	}
	return b.String()
}
