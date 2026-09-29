package bind

import (
	"context"
	"fmt"
	"time"

	"github.com/cull-app/cull/core"
	"github.com/cull-app/cull/db"
	"github.com/cull-app/cull/ingest"
)

type Link struct {
	ID             string
	URL            string
	Domain         string
	Title          string
	Excerpt        string
	Category       string
	CategoryLabel  string
	HoardScore     float64
	Actionability  float64
	Band           int
	BandLabel      string
	OpenCount      int
	DuplicateCount int
	AgeDays        int
	Explanation    string
	Culled         bool
	CreatedAt      int64
}

type Proposal struct {
	Kind             int
	Category         string
	Count            int
	AvgActionability float64
	Line             string
	Titles           []string
}

type Report struct {
	Week      int
	Headline  string
	Culled    int
	Total     int
	Cta       string
	Proposals []Proposal
}

type Stats struct {
	Total        int
	Culled       int
	Duplicates   int
	SavedToday   int
	Opened       int
	Tone         int
	AverageScore float64
}

type Outcome struct {
	Saved    bool
	ID       string
	Category string
	Score    float64
	Action   float64
	Roast    string
	Reason   string
}

type Store struct {
	inner *db.Store
}

func NewStore(path string) (*Store, error) {
	inner, err := db.Open(path)
	if err != nil {
		return nil, err
	}
	return &Store{inner: inner}, nil
}

func (s *Store) Close() error {
	return s.inner.Close()
}

func (s *Store) Save(url string, week int) (Outcome, error) {
	p := ingest.NewPipeline(s.inner)
	p.Tone = s.inner.Tone()
	p.Week = week

	res := p.Ingest(context.Background(), url, week)

	out := Outcome{
		ID:       res.Bookmark.ID,
		Category: string(res.Bookmark.Category),
		Score:    res.Bookmark.HoardScore,
		Action:   res.Bookmark.Actionability,
		Roast:    res.Roast,
		Saved:    res.Saved,
		Reason:   res.MergedInto,
	}
	if res.Err != nil {
		out.Reason = res.Err.Error()
	}
	return out, nil
}

func (s *Store) List(limit int) ([]Link, error) {
	all, err := s.inner.All()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	return toLinks(all, now, limit), nil
}

func (s *Store) Search(query string, limit int) ([]Link, error) {
	if query == "" {
		return nil, nil
	}
	res, err := s.inner.Search(query, limit)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	bookmarks := make([]db.Bookmark, 0, len(res))
	for _, r := range res {
		bookmarks = append(bookmarks, r.Bookmark)
	}
	return toLinks(bookmarks, now, 0), nil
}

func (s *Store) Cullable(limit int) ([]Link, error) {
	all, err := s.inner.All()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	out := make([]Link, 0, len(all))
	for _, b := range all {
		bm := b
		verdict := core.Judge(bm.Scorable, now)
		if core.ShouldPropose(bm.Scorable, verdict, now) {
			out = append(out, toLink(bm, now, verdict))
		}
		if limit > 0 && len(out) >= limit {
			break
		}
	}
	return out, nil
}

func (s *Store) Graveyard(limit int) ([]Link, error) {
	all, err := s.inner.Graveyard(time.Now())
	if err != nil {
		return nil, err
	}
	return toLinks(all, time.Now(), limit), nil
}

func (s *Store) Cull(id string, nowMillis int64) error {
	return s.inner.Cull(id, time.UnixMilli(nowMillis))
}

func (s *Store) Restore(id string) error {
	return s.inner.Restore(id)
}

func (s *Store) TouchOpen(id string, nowMillis int64) error {
	return s.inner.TouchOpen(id, time.UnixMilli(nowMillis))
}

func (s *Store) Report(tone int, week int) (Report, error) {
	all, err := s.inner.All()
	if err != nil {
		return Report{}, err
	}
	now := time.Now()
	items := make([]core.Item, 0, len(all))
	for _, b := range all {
		items = append(items, core.MakeItem(b.Scorable, now))
	}

	cullable := 0
	for _, b := range all {
		verdict := core.Judge(b.Scorable, now)
		if core.ShouldPropose(b.Scorable, verdict, now) {
			cullable++
		}
	}

	rep := core.BuildCullReport(items, core.ReportStats{
		SavedThisWeek: len(items),
		TotalHoard:    len(items),
	}, now, week, core.Tone(tone))

	out := Report{
		Week:     rep.Week,
		Headline: rep.Headline,
		Culled:   cullable,
		Total:    len(items),
		Cta:      "CULL NOW",
	}
	if cullable == 1 {
		out.Cta = "CULL 1"
	}
	if cullable > 1 {
		out.Cta = "CULL " + fmt.Sprintf("CULL %d NOW", cullable) + " NOW"
	}

	for _, p := range rep.Proposals {
		titles := make([]string, 0, len(p.Items))
		for _, it := range p.Items {
			titles = append(titles, it.Title)
		}
		out.Proposals = append(out.Proposals, Proposal{
			Kind:             int(p.Kind),
			Category:         string(p.Category),
			Count:            p.Count,
			AvgActionability: p.AvgActionability,
			Line:             p.Line,
			Titles:           titles,
		})
	}
	return out, nil
}

func (s *Store) Stats() (Stats, error) {
	all, err := s.inner.All()
	if err != nil {
		return Stats{}, err
	}
	now := time.Now()
	st := Stats{Total: len(all), Tone: int(s.inner.Tone())}
	total := 0.0
	for _, b := range all {
		if b.DuplicateCount > 0 {
			st.Duplicates++
		}
		if b.OpenCount > 0 {
			st.Opened++
		}
		if b.CreatedAt.Year() == now.Year() && b.CreatedAt.YearDay() == now.YearDay() {
			st.SavedToday++
		}
		total += b.HoardScore
	}
	if len(all) > 0 {
		st.AverageScore = total / float64(len(all))
	}
	return st, nil
}

func (s *Store) SetTone(tone int) error {
	var name string
	switch tone {
	case 0:
		name = "soft"
	case 1:
		name = "blunt"
	case 2:
		name = "savage"
	default:
		return fmt.Errorf("tone %d is out of range; want 0 soft, 1 blunt, 2 savage", tone)
	}
	return s.inner.SetSetting(db.SettingTone, name)
}

func (s *Store) Tone() int {
	return int(s.inner.Tone())
}

func (s *Store) SchemaVersion() (int, error) {
	return s.inner.SchemaVersion()
}

func toLinks(in []db.Bookmark, now time.Time, limit int) []Link {
	out := make([]Link, 0, len(in))
	for _, b := range in {
		verdict := core.Judge(b.Scorable, now)
		out = append(out, toLink(b, now, verdict))
		if limit > 0 && len(out) >= limit {
			break
		}
	}
	return out
}

func toLink(b db.Bookmark, now time.Time, verdict core.Verdict) Link {
	age := int(core.DaysSince(b.CreatedAt, now))
	return Link{
		ID:             b.ID,
		URL:            b.URL,
		Domain:         b.Domain,
		Title:          b.Title,
		Excerpt:        b.Excerpt,
		Category:       string(b.Category),
		CategoryLabel:  string(b.Category),
		HoardScore:     b.HoardScore,
		Actionability:  b.Actionability,
		Band:           int(verdict.Hoard.Band),
		BandLabel:      verdict.Hoard.Band.String(),
		OpenCount:      b.OpenCount,
		DuplicateCount: b.DuplicateCount,
		AgeDays:        age,
		Explanation:    verdict.Hoard.Explanation,
		Culled:         b.CulledAt > 0,
		CreatedAt:      b.CreatedAt.UnixMilli(),
	}
}

func isoWeek(t time.Time) int {
	_, w := t.ISOWeek()
	return w
}
