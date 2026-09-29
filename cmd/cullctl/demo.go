package main

import (
	"embed"
	"fmt"
	"time"

	"github.com/cull-app/cull/core"
)

//go:embed fixtures/hoard.json
var fixtureFS embed.FS

func fixturePath(name string) string { return "fixtures/" + name }

func runDemo() error {
	items, err := loadEmbeddedBookmarks(fixturePath("hoard.json"))
	if err != nil {
		return err
	}
	now := time.Now()

	printTable(items, now)

	stats := core.ReportStats{
		SavedThisWeek:  23,
		OpenedThisWeek: 2,
		ForgedThisWeek: 1,
		TotalHoard:     len(items),
		StreakWeeks:    0,
	}
	rep := core.BuildCullReport(items, stats, now, isoWeek(now), core.ToneBlunt)
	printReport(rep, core.ToneBlunt)

	fmt.Println("  Dedupe check against the fixture hoard:")
	seen := make([]core.Fingerprint, 0, len(items))
	for _, it := range items {
		seen = append(seen, core.Fingerprint{ID: it.ID, URL: it.URL, SimHash: core.SimHash64(it.ReadableText)})
	}
	dupes := 0
	for i, it := range items {
		others := append(append([]core.Fingerprint{}, seen[:i]...), seen[i+1:]...)
		if r := core.FindDuplicate(others, it.URL, it.ReadableText); r.Found() {
			dupes++
			fmt.Printf("    · %-44s %s via %s\n", truncate(it.Title, 44), r.Tier, r.MatchID)
		}
	}
	if dupes == 0 {
		fmt.Println("    · none")
	}
	fmt.Println()
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}
