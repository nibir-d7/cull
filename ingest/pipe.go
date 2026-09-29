package ingest

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/cull-app/cull/core"
	"github.com/cull-app/cull/db"
)

type IngestTarget interface {
	Insert(b db.Bookmark) error
	Get(id string) (db.Bookmark, error)
	IncrementDuplicate(originalID string) error
	All() ([]db.Bookmark, error)
	Record(name string, at time.Time, bookmarkID string, props map[string]any) error
}

type Outcome struct {
	Bookmark db.Bookmark

	Saved bool

	MergedInto string

	Verdict core.Verdict

	Roast string

	Tone core.Tone

	Err error

	Elapsed time.Duration
}

func (o Outcome) Ok() bool { return o.Saved && o.Err == nil }

type Pipeline struct {
	Store IngestTarget
	Fetch *Fetcher
	Tone  core.Tone
	Week  int
	Now   func() time.Time

	MaxCandidates int
}

func NewPipeline(store IngestTarget) *Pipeline {
	return &Pipeline{
		Store:         store,
		Fetch:         NewFetcher(),
		Now:           time.Now,
		MaxCandidates: 5000,
	}
}

func (p *Pipeline) Ingest(ctx context.Context, rawURL string, week int) Outcome {

	start := time.Now()
	out := Outcome{Tone: p.Tone}

	elapsed := func() time.Duration { return time.Since(start) }

	u, err := ValidateURL(rawURL)
	if err != nil {
		out.Err = err
		out.Elapsed = elapsed()
		return out
	}

	if existing, ok := p.findByURL(rawURL); ok {
		return p.merge(out, existing, core.DedupeExactURL, start)
	}

	doc, fetchErr := p.Fetch.Fetch(ctx, rawURL)
	if fetchErr != nil {

		if errors.Is(fetchErr, ErrBlocked) {
			out.Err = fetchErr
			out.Elapsed = elapsed()
			return out
		}

		doc.URL = u.String()
		doc.Domain = DomainOf(u.String())
		if doc.Title == "" {
			doc.Title = titleFromURL(u.String())
		}
		doc.Excerpt = doc.Title
		doc.Method = MethodURL
	}

	sim := core.SimHash64(doc.Title + " " + doc.Readable)

	if existing, ok := p.findByContent(sim, rawURL); ok {
		return p.merge(out, existing, core.DedupeSimilarContent, start)
	}

	now := p.clock()
	b := db.Bookmark{
		Scorable: core.Scorable{
			ID:           newID(),
			URL:          doc.URL,
			Domain:       doc.Domain,
			Title:        doc.Title,
			ReadableText: doc.Readable,
			CreatedAt:    now,
		},
		Excerpt:       doc.Excerpt,
		FaviconURL:    doc.FaviconURL,
		SimHash:       sim,
		HasSimHash:    doc.Readable != "" || doc.Title != "",
		ExtractMethod: doc.Method,
	}
	v := core.Judge(b.Scorable, now)
	b.Category = v.Category
	b.HoardScore = v.Hoard.Total
	b.Actionability = v.Action.Total
	b.ScoredAt = now.Unix()

	if err := p.Store.Insert(b); err != nil {
		out.Err = fmt.Errorf("ingest: save %s: %w", doc.URL, err)
		out.Elapsed = elapsed()
		return out
	}

	b.Verdict = v
	out.Bookmark = b
	out.Verdict = v
	out.Saved = true
	out.Err = fetchErr
	out.Roast = core.RoastFor(roastVars(b, v), week, p.Tone).Line
	out.Elapsed = elapsed()

	_ = p.Store.Record(db.EventSaved, now, b.ID, map[string]any{
		"category":      string(v.Category),
		"hoard_score":   v.Hoard.Total,
		"actionability": v.Action.Total,
		"method":        doc.Method,
	})
	return out
}

func (p *Pipeline) merge(out Outcome, existing db.Bookmark, tier core.DedupeTier, start time.Time) Outcome {
	if err := p.Store.IncrementDuplicate(existing.ID); err != nil {

		out.Err = fmt.Errorf("ingest: bump duplicate count: %w", err)
	}
	existing.DuplicateCount++
	existing.Scorable = withDupCount(existing.Scorable, existing.DuplicateCount)
	v := core.Judge(existing.Scorable, p.clock())

	out.Bookmark = existing
	out.Verdict = v
	out.Saved = false
	out.MergedInto = existing.ID
	out.Elapsed = time.Since(start)
	out.Roast = duplicateRoast(v, existing, tier, p.Tone)

	_ = p.Store.Record(db.EventSaved, p.clock(), existing.ID, map[string]any{
		"duplicate": true,
		"tier":      tier.String(),
	})
	return out
}

func withDupCount(s core.Scorable, n int) core.Scorable {
	s.DuplicateCount = n
	return s
}

func (p *Pipeline) findByURL(rawURL string) (db.Bookmark, bool) {
	all, err := p.Store.All()
	if err != nil {
		return db.Bookmark{}, false
	}
	want := core.NormalizeURL(rawURL)
	for _, b := range all {
		if core.NormalizeURL(b.URL) == want {
			return b, true
		}
	}
	return db.Bookmark{}, false
}

func (p *Pipeline) findByContent(sim uint64, rawURL string) (db.Bookmark, bool) {
	if sim == 0 {
		return db.Bookmark{}, false
	}
	all, err := p.Store.All()
	if err != nil {
		return db.Bookmark{}, false
	}

	var fps []core.Fingerprint
	var keep []db.Bookmark
	for i, b := range all {
		if !b.HasSimHash || b.SimHash == 0 {
			continue
		}
		if i >= p.MaxCandidates {
			break
		}
		fps = append(fps, core.Fingerprint{ID: b.ID, URL: b.URL, SimHash: b.SimHash})
		keep = append(keep, b)
	}
	if len(fps) == 0 {
		return db.Bookmark{}, false
	}

	res := core.FindDuplicateByHash(fps, rawURL, sim)
	if !res.Found() {
		return db.Bookmark{}, false
	}
	for i, f := range fps {
		if f.ID == res.MatchID {
			return keep[i], true
		}
	}
	return db.Bookmark{}, false
}

func roastVars(b db.Bookmark, v core.Verdict) core.RoastVars {
	age := 0
	if !b.CreatedAt.IsZero() {
		age = int(core.DaysSince(b.CreatedAt, time.Now()))
	}
	return core.RoastVars{
		Title:          b.Title,
		Domain:         b.Domain,
		Category:       v.Category,
		Count:          1,
		AgeDays:        age,
		DuplicateCount: b.DuplicateCount,
		OpenCount:      b.OpenCount,
		Total:          1,
		Actionability:  v.Action.Total,
	}
}

func duplicateRoast(v core.Verdict, b db.Bookmark, tier core.DedupeTier, tone core.Tone) string {
	vars := roastVars(b, v)
	if tier == core.DedupeExactURL {
		vars.Count = b.DuplicateCount
		vars.DuplicateCount = b.DuplicateCount
		return core.Render("You already saved this exact link. That is {count time} now.", vars)
	}

	vars.Count = b.DuplicateCount
	vars.DuplicateCount = b.DuplicateCount
	return core.Render("Same article, different link. You have saved it {count time}. Still 0 actions.", vars)
}

func (p *Pipeline) clock() time.Time {
	if p.Now != nil {
		return p.Now()
	}
	return time.Now()
}

func newID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {

		return fmt.Sprintf("bm-%d", time.Now().UnixNano())
	}
	return "bm-" + hex.EncodeToString(b[:])
}
