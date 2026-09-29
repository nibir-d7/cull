package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/cull-app/cull/core"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "demo":
		err = runDemo()
	case "rules":
		err = runRules()
	case "report":
		err = runReport(os.Args[2:])
	case "roast":
		err = runRoast(os.Args[2:])
	case "bench":
		err = runBench()
	case "save":
		err = save(os.Args[2:])
	case "list":
		err = list(os.Args[2:])
	case "find":
		err = find(os.Args[2:])
	case "stats":
		err = stats(os.Args[2:])
	case "reset":
		err = reset()
	case "-h", "--help", "help":
		usage()
		return
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", os.Args[1])
		usage()
		os.Exit(2)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `cullctl -- the CULL engine, in your terminal

  Offline (no database)
    cullctl demo                     judge a fixture hoard, print the weekly report
    cullctl rules                    list categories and the rule order
    cullctl roast [flags]            render a single roast line
    cullctl bench                    time the engine

  With the local store (cull.db, or $CULL_DB)
    cullctl save <url> [url...]      ingest a link, print its verdict
    cullctl list [limit]             show the hoard
    cullctl find <query>             full-text search, BM25-ranked
    cullctl report --tone=blunt      the Sunday report, from real data
    cullctl stats                    the four north-star metrics
    cullctl reset                    delete the local database

`)
}

func reset() error {
	for _, suffix := range []string{"", "-wal", "-shm"} {
		p := dbPath() + suffix
		if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	fmt.Printf("  removed %s\n", dbPath())
	return nil
}

func parseCategory(s string) (core.Category, error) {
	norm := strings.ToLower(strings.TrimSpace(s))
	norm = strings.Join(strings.Fields(strings.ReplaceAll(norm, "-", " ")), " ")
	c := core.Category(norm)
	if !c.Valid() {
		names := make([]string, 0, len(core.AllCategories))
		for _, k := range core.AllCategories {
			names = append(names, string(k))
		}
		return "", fmt.Errorf("unknown category %q (want one of: %s)", s, strings.Join(names, ", "))
	}
	return c, nil
}

func parseTone(s string) (core.Tone, error) {
	switch strings.ToLower(s) {
	case "soft", "":
		return core.ToneSoft, nil
	case "blunt":
		return core.ToneBlunt, nil
	case "savage":
		return core.ToneSavage, nil
	}
	return core.ToneBlunt, fmt.Errorf("unknown tone %q (want soft, blunt or savage)", s)
}

type jsonBookmark struct {
	URL          string `json:"url"`
	Title        string `json:"title"`
	Text         string `json:"text"`
	Category     string `json:"category"`
	OpenCount    int    `json:"open_count"`
	Duplicate    int    `json:"duplicate_count"`
	CreatedAt    string `json:"created_at"`
	LastOpenedAt string `json:"last_opened_at"`
}

func loadBookmarks(path string) ([]core.Item, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parseBookmarks(raw, path)
}

func loadEmbeddedBookmarks(name string) ([]core.Item, error) {
	raw, err := fixtureFS.ReadFile(name)
	if err != nil {
		return nil, err
	}
	return parseBookmarks(raw, name)
}

func parseBookmarks(raw []byte, label string) ([]core.Item, error) {
	var in []jsonBookmark
	if err := json.Unmarshal(raw, &in); err != nil {
		return nil, fmt.Errorf("parse %s: %w", label, err)
	}

	now := time.Now()
	items := make([]core.Item, 0, len(in))
	for i, b := range in {
		s := core.Scorable{
			ID:             fmt.Sprintf("bm-%03d", i),
			URL:            b.URL,
			Domain:         domainOf(b.URL),
			Title:          b.Title,
			ReadableText:   b.Text,
			OpenCount:      b.OpenCount,
			DuplicateCount: b.Duplicate,
		}
		s.CreatedAt = parseTime(b.CreatedAt, now.AddDate(0, 0, -30))
		s.LastOpenedAt = parseTime(b.LastOpenedAt, time.Time{})
		items = append(items, core.MakeItem(s, now))
	}
	return items, nil
}

func parseTime(s string, def time.Time) time.Time {
	if strings.TrimSpace(s) == "" {
		return def
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return def
	}
	return t
}

func domainOf(rawURL string) string {
	u := rawURL
	if i := strings.Index(u, "://"); i >= 0 {
		u = u[i+3:]
	}
	if i := strings.IndexAny(u, "/?#"); i >= 0 {
		u = u[:i]
	}
	return strings.TrimPrefix(strings.ToLower(u), "www.")
}

func runRules() error {
	fmt.Println("CATEGORIES")
	for i, c := range core.AllCategories {
		fmt.Printf("  %d. %s\n", i+1, c)
	}

	fmt.Println("\nRULE CASCADE (first match wins)")
	for i, name := range core.RuleNames() {
		fmt.Printf("  %d. %s\n", i+1, name)
	}
	fmt.Printf("\nthresholds: propose at >= %.0f, label graveyard at >= %.0f, stale after %d days unopened\n",
		core.CullProposeThreshold, core.GraveyardThreshold, core.CullStaleDays)
	return nil
}

func runReport(args []string) error {
	fs := flag.NewFlagSet("report", flag.ExitOnError)
	toneFlag := fs.String("tone", "blunt", "roast tone: soft, blunt, savage")
	if err := fs.Parse(args); err != nil {
		return err
	}
	tone, err := parseTone(*toneFlag)
	if err != nil {
		return err
	}

	if fs.NArg() == 0 {
		return reportFromStore(*toneFlag)
	}

	items, err := loadBookmarks(fs.Arg(0))
	if err != nil {
		return err
	}
	now := time.Now()
	printTable(items, now)
	rep := core.BuildCullReport(items, core.ReportStats{
		SavedThisWeek:  len(items) / 4,
		TotalHoard:     len(items),
		StreakWeeks:    3,
		ForgedThisWeek: 1,
	}, now, isoWeek(now), tone)
	printReport(rep, tone)
	return nil
}

func runRoast(args []string) error {
	fs := flag.NewFlagSet("roast", flag.ExitOnError)
	title := fs.String("title", "", "link title")
	domain := fs.String("domain", "", "domain")
	cat := fs.String("category", "", "category (blank to use 'reference')")
	toneFlag := fs.String("tone", "blunt", "soft, blunt, savage")
	age := fs.Int("age", 47, "age in days")
	count := fs.Int("count", 1, "group size")
	dups := fs.Int("dups", 0, "duplicate count")
	opens := fs.Int("opens", 0, "open count")
	total := fs.Int("total", 200, "total links in hoard")
	week := fs.Int("week", 0, "week number (default: current)")
	verbose := fs.Bool("v", false, "show the template that was used")
	if err := fs.Parse(args); err != nil {
		return err
	}

	tone, err := parseTone(*toneFlag)
	if err != nil {
		return err
	}
	if *week == 0 {
		*week = isoWeek(time.Now())
	}

	if strings.TrimSpace(*cat) == "" {
		cat = new(string)
		*cat = string(core.CategoryReference)
	}
	category, err := parseCategory(*cat)
	if err != nil {
		return err
	}

	r := core.RoastFor(core.RoastVars{
		Title:          *title,
		Domain:         *domain,
		Category:       category,
		Count:          *count,
		AgeDays:        *age,
		DuplicateCount: *dups,
		OpenCount:      *opens,
		Total:          *total,
	}, *week, tone)

	fmt.Println(r.Line)
	if *verbose {
		fmt.Printf("\n  tone: %s\n  pool: %s\n  week: %d\n  template: %s\n", r.Tone, r.Pool, *week, r.Template)
	}
	return nil
}

func isoWeek(t time.Time) int {
	_, w := t.ISOWeek()
	return w
}

func printTable(items []core.Item, now time.Time) {
	sorted := make([]core.Item, len(items))
	copy(sorted, items)
	sort.SliceStable(sorted, func(i, j int) bool {
		return sorted[i].Verdict.Hoard.Total > sorted[j].Verdict.Hoard.Total
	})

	fmt.Printf("HOARD  %d links\n\n", len(sorted))
	fmt.Printf("  %-38s %-19s %6s %6s  %s\n", "TITLE", "CATEGORY", "HOARD", "ACT", "BAND")
	fmt.Println("  " + strings.Repeat("-", 88))
	for _, it := range sorted {
		title := it.Title
		if len(title) > 36 {
			title = title[:35] + "…"
		}
		fmt.Printf("  %-38s %-19s %6.1f %6.2f  %s\n",
			title, it.Verdict.Category, it.Verdict.Hoard.Total, it.Verdict.Action.Total,
			it.Verdict.Hoard.Band)
	}
	fmt.Println()
}

func printReport(rep core.CullReport, tone core.Tone) {
	fmt.Println("═" + strings.Repeat("═", 78))
	fmt.Printf("  WEEK %d ROAST   (%s)\n", rep.Week, tone)
	fmt.Println("═" + strings.Repeat("═", 78))
	fmt.Println()
	fmt.Printf("  %s\n\n", rep.Headline)

	if len(rep.Proposals) == 0 {
		fmt.Println("  Nothing to cull. Suspicious, but fine.")
		return
	}

	for i, p := range rep.Proposals {
		label := strings.ToUpper(p.Kind.String())
		if p.Kind == core.ProposalGroup {
			label = fmt.Sprintf("GROUP · %s", p.Category)
		}
		fmt.Printf("  %d. %-28s %d link%s  (avg actionability %.2f)\n",
			i+1, label, p.Count, plural(p.Count), p.AvgActionability)
		fmt.Printf("     %q\n", p.Line)
		for _, s := range p.Items {
			title := s.Title
			if len(title) > 44 {
				title = title[:43] + "…"
			}
			age := int(core.DaysSince(s.CreatedAt, time.Now()))
			fmt.Printf("       · %-46s %s\n", title, pluralAge(age))
		}
		fmt.Println()
	}

	cta := "CULL 1"
	if rep.Cullable > 1 {
		cta = fmt.Sprintf("CULL %d NOW", rep.Cullable)
	}
	fmt.Println("  " + strings.Repeat("─", 78))
	fmt.Printf("  %d of %d links are rotting.\n", rep.Cullable, rep.TotalHoard)
	fmt.Printf("  [ %s ]\n", cta)
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func pluralAge(days int) string {
	if days == 1 {
		return "1 day old"
	}
	return fmt.Sprintf("%d days old", days)
}

func runBench() error {
	items, err := loadEmbeddedBookmarks(fixturePath("hoard.json"))
	if err != nil {
		return err
	}
	now := time.Now()

	start := time.Now()
	n := 200
	for i := 0; i < n; i++ {
		for _, it := range items {
			_ = core.Judge(it.Scorable, now)
		}
	}
	per := time.Since(start) / time.Duration(n)
	fmt.Printf("judge:  %v for %d links  (%.2f ms per link)\n",
		per, len(items), float64(per.Microseconds())/1000.0/float64(len(items)))

	start = time.Now()
	for i := 0; i < n; i++ {
		_ = core.BuildCullReport(items, core.ReportStats{TotalHoard: len(items)}, now, 10, core.ToneBlunt)
	}
	fmt.Printf("report: %v for %d links\n", time.Since(start)/time.Duration(n), len(items))
	return nil
}
