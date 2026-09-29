package main

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/cull-app/cull/core"
	"github.com/cull-app/cull/db"
	"github.com/cull-app/cull/ingest"
)

func dbPath() string {
	if p := os.Getenv("CULL_DB"); p != "" {
		return p
	}
	return "cull.db"
}

func openStore() (*db.Store, error) { return db.Open(dbPath()) }

func save(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: cullctl save <url> [url...]")
	}
	store, err := openStore()
	if err != nil {
		return err
	}
	defer store.Close()

	p := ingest.NewPipeline(store)
	p.Tone = store.Tone()
	if purged, err := store.PurgeExpired(time.Now()); err == nil && purged > 0 {
		fmt.Printf("  purged %d link(s) past the 30-day recovery window\n\n", purged)
	}

	ctx := context.Background()
	for i, raw := range args {
		now := time.Now()
		out := p.Ingest(ctx, raw, isoWeek(now))

		switch {
		case out.Err != nil && !out.Saved:
			fmt.Fprintf(os.Stderr, "  blocked: %s\n         %v\n", raw, out.Err)
		case out.Saved:
			verb := "saved"
			if out.Err != nil {
				verb = "saved (no content)"
			}
			fmt.Printf("  %s  %s\n", strings.ToUpper(verb), out.Bookmark.Title)
			fmt.Printf("        %s\n", out.Bookmark.URL)
			fmt.Printf("        category: %s   hoard: %.0f (%s)   actionability: %.2f\n",
				out.Verdict.Category, out.Verdict.Hoard.Total,
				out.Verdict.Hoard.Band, out.Verdict.Action.Total)
			fmt.Printf("        %s\n", out.Verdict.Hoard.Explanation)
			fmt.Printf("        > %s\n", out.Roast)
		default:
			fmt.Printf("  DUPLICATE  %s\n", out.Bookmark.Title)
			fmt.Printf("        merged into %s\n", out.MergedInto)
			fmt.Printf("        > %s\n", out.Roast)
		}
		fmt.Printf("        (%v)\n", out.Elapsed.Round(time.Millisecond))
		if i < len(args)-1 {
			fmt.Println()
		}
	}
	return nil
}

func list(args []string) error {
	limit := 50
	if len(args) > 0 {
		fmt.Sscanf(args[0], "%d", &limit)
	}
	store, err := openStore()
	if err != nil {
		return err
	}
	defer store.Close()

	items, err := store.All()
	if err != nil {
		return err
	}
	if len(items) == 0 {
		fmt.Println("  nothing saved yet. try: cullctl save <url>")
		return nil
	}

	total := len(items)
	sort.SliceStable(items, func(i, j int) bool {
		return items[i].Verdict.Hoard.Total > items[j].Verdict.Hoard.Total
	})
	if limit > 0 && len(items) > limit {
		items = items[:limit]
	}

	fmt.Printf("HOARD  %d link(s)\n\n", total)
	fmt.Printf("  %-38s %-19s %6s %6s  %s\n", "TITLE", "CATEGORY", "HOARD", "ACT", "BAND")
	fmt.Println("  " + strings.Repeat("-", 88))
	for _, b := range items {
		title := b.Title
		if len(title) > 36 {
			title = title[:35] + "…"
		}
		dupes := ""
		if b.DuplicateCount > 0 {
			dupes = fmt.Sprintf("  x%d", b.DuplicateCount+1)
		}
		fmt.Printf("  %-38s %-19s %6.1f %6.2f  %s%s\n",
			title, b.Verdict.Category, b.Verdict.Hoard.Total,
			b.Verdict.Action.Total, b.Verdict.Hoard.Band, dupes)
	}
	return nil
}

func find(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: cullctl find <query>")
	}
	store, err := openStore()
	if err != nil {
		return err
	}
	defer store.Close()

	res, err := store.Search(strings.Join(args, " "), 20)
	if err != nil {
		return err
	}
	if len(res) == 0 {
		fmt.Printf("  nothing matches %q\n", strings.Join(args, " "))
		return nil
	}
	fmt.Printf("%d result(s)\n\n", len(res))
	for _, r := range res {
		fmt.Printf("  %s\n", r.Title)
		fmt.Printf("    %s\n", r.URL)
		fmt.Printf("    %s\n", r.Score)
		fmt.Printf("    %s · hoard %.0f · bm25 %.3f\n\n", r.Verdict.Category, r.Verdict.Hoard.Total, r.Rank)
	}
	return nil
}

func reportFromStore(toneFlag string) error {
	tone, err := parseTone(toneFlag)
	if err != nil {
		return err
	}
	store, err := openStore()
	if err != nil {
		return err
	}
	defer store.Close()

	items, err := store.All()
	if err != nil {
		return err
	}
	if len(items) == 0 {
		fmt.Println("  nothing saved yet.")
		return nil
	}

	now := time.Now()
	week := isoWeek(now)

	start := now.AddDate(0, 0, -7)
	saved, _ := store.CountEvents(db.EventSaved, start, now)
	opened, _ := store.CountEvents(db.EventOpened, start, now)
	forged, _ := store.CountEvents(db.EventForged, start, now)

	coreItems := make([]core.Item, 0, len(items))
	for _, b := range items {
		coreItems = append(coreItems, core.MakeItem(b.Scorable, now))
	}

	rep := core.BuildCullReport(coreItems, core.ReportStats{
		SavedThisWeek:  saved,
		OpenedThisWeek: opened,
		ForgedThisWeek: forged,
		TotalHoard:     len(items),
	}, now, week, tone)
	printReport(rep, tone)
	return nil
}

func stats(args []string) error {
	store, err := openStore()
	if err != nil {
		return err
	}
	defer store.Close()

	now := time.Now()
	items, _ := store.All()

	lags := make([]float64, 0, len(items))
	for _, b := range items {
		if b.OpenCount > 0 && !b.LastOpenedAt.IsZero() {
			lags = append(lags, core.DaysSince(b.CreatedAt, b.LastOpenedAt))
		}
	}
	sort.Float64s(lags)
	median := 0.0
	if n := len(lags); n > 0 {
		if n%2 == 1 {
			median = lags[n/2]
		} else {
			median = (lags[n/2-1] + lags[n/2]) / 2
		}
	}

	forged, _ := store.CountEvents(db.EventForged, time.Unix(0, 0), now)
	implRate := 0.0
	if len(items) > 0 {
		implRate = float64(forged) / float64(len(items)) * 100
	}
	culled, _ := store.CountEvents(db.EventCulled, time.Unix(0, 0), now)
	cullRate := 0.0
	if culled > 0 {
		cullRate = 100
	}
	shared, _ := store.CountEvents(db.EventRoastShare, time.Unix(0, 0), now)
	shareRate := 0.0
	if shared > 0 {
		shareRate = 100
	}

	fmt.Println("METRICS")
	fmt.Printf("  hoard size            %d\n", len(items))
	fmt.Printf("  implementation rate   %.1f%%  (forged %d of %d saved)\n", implRate, forged, len(items))
	fmt.Printf("  cull rate             %.0f%%\n", cullRate)
	fmt.Printf("  roast share rate      %.0f%%\n", shareRate)
	if len(lags) == 0 {
		fmt.Printf("  save-to-open lag      no link has been opened yet\n")
	} else {
		fmt.Printf("  save-to-open lag      %.0f days median (of %d opened)\n", median, len(lags))
	}
	return nil
}
