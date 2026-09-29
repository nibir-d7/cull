package db

import (
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/cull-app/cull/core"

	_ "modernc.org/sqlite"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

const GraveyardDays = 30

var ErrNotFound = errors.New("db: bookmark not found")

type Store struct {
	sql  *sql.DB
	path string
}

func Open(path string) (*Store, error) {
	dsn := path
	if path != ":memory:" {
		dsn = "file:" + path + "?_pragma=busy_timeout(3000)"
	}

	s, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("db: open %s: %w", path, err)
	}

	s.SetMaxOpenConns(1)

	if err := applyPragmas(s); err != nil {
		s.Close()
		return nil, err
	}
	if err := Migrate(s); err != nil {
		s.Close()
		return nil, err
	}
	if err := seedSettings(s); err != nil {
		s.Close()
		return nil, err
	}

	return &Store{sql: s, path: path}, nil
}

func applyPragmas(s *sql.DB) error {

	for _, pragma := range []string{
		"PRAGMA journal_mode = WAL",
		"PRAGMA synchronous = NORMAL",
		"PRAGMA foreign_keys = ON",
		"PRAGMA temp_store = MEMORY",
		"PRAGMA busy_timeout = 3000",
	} {
		if _, err := s.Exec(pragma); err != nil {
			return fmt.Errorf("db: %s: %w", pragma, err)
		}
	}
	var fk int
	if err := s.QueryRow("PRAGMA foreign_keys").Scan(&fk); err != nil {
		return fmt.Errorf("db: verify foreign_keys: %w", err)
	}
	if fk != 1 {
		return errors.New("db: foreign_keys pragma did not take effect")
	}
	return nil
}

func (s *Store) Close() error { return s.sql.Close() }

func (s *Store) DB() *sql.DB { return s.sql }

func Migrate(s *sql.DB) error {
	_, err := s.Exec(`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version    INTEGER PRIMARY KEY,
			name       TEXT    NOT NULL,
			checksum   TEXT    NOT NULL,
			applied_at INTEGER NOT NULL
		)`)
	if err != nil {
		return fmt.Errorf("db: create schema_migrations: %w", err)
	}

	applied := map[int]string{}
	rows, err := s.Query("SELECT version, checksum FROM schema_migrations")
	if err != nil {
		return fmt.Errorf("db: read schema_migrations: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var v int
		var sum string
		if err := rows.Scan(&v, &sum); err != nil {
			return err
		}
		applied[v] = sum
	}
	if err := rows.Err(); err != nil {
		return err
	}

	files, err := migrationFiles()
	if err != nil {
		return err
	}

	for _, f := range files {
		version := f.version
		body, err := migrationFS.ReadFile("migrations/" + f.name)
		if err != nil {
			return err
		}
		sum := checksum(body)

		if prev, ok := applied[version]; ok {
			if prev != sum {
				return fmt.Errorf(
					"db: migration %d (%s) was modified after being applied "+
						"(recorded %s, found %s). Migrations are append-only: "+
						"add a new numbered migration instead of editing this one.",
					version, f.name, prev[:12], sum[:12])
			}
			continue
		}

		if err := applyMigration(s, version, f.name, string(body), sum); err != nil {
			return err
		}
	}
	return nil
}

type migrationFile struct {
	version int
	name    string
}

func migrationFiles() ([]migrationFile, error) {
	entries, err := fs.ReadDir(migrationFS, "migrations")
	if err != nil {
		return nil, err
	}
	var out []migrationFile
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".up.sql") {
			continue
		}
		base := strings.TrimSuffix(e.Name(), ".up.sql")
		versionStr, _, ok := strings.Cut(base, "_")
		if !ok {
			return nil, fmt.Errorf("db: migration %q is not named <version>_<name>.up.sql", e.Name())
		}
		v, err := strconv.Atoi(versionStr)
		if err != nil {
			return nil, fmt.Errorf("db: migration %q has a non-numeric version: %w", e.Name(), err)
		}
		out = append(out, migrationFile{version: v, name: e.Name()})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	return out, nil
}

func applyMigration(s *sql.DB, version int, name, body, sum string) error {
	tx, err := s.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(body); err != nil {
		return fmt.Errorf("db: apply %s: %w", name, err)
	}
	if _, err := tx.Exec(
		`INSERT INTO schema_migrations(version, name, checksum, applied_at) VALUES (?,?,?,?)`,
		version, name, sum, time.Now().Unix()); err != nil {
		return err
	}
	return tx.Commit()
}

func checksum(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func (s *Store) SchemaVersion() (int, error) {
	var v sql.NullInt64
	err := s.sql.QueryRow("SELECT max(version) FROM schema_migrations").Scan(&v)
	if err != nil {
		return 0, err
	}
	return int(v.Int64), nil
}

const (
	SettingTone        = "tone"
	SettingPro         = "pro"
	SettingOnboarded   = "onboarded"
	SettingFirstRunAt  = "first_run_at"
	SettingLastRoastAt = "last_roast_at"
)

var defaultSettings = map[string]string{
	SettingTone:       "blunt",
	SettingPro:        "0",
	SettingOnboarded:  "0",
	SettingFirstRunAt: "",
}

func seedSettings(s *sql.DB) error {
	for k, v := range defaultSettings {

		if v == "" {
			continue
		}
		if _, err := s.Exec(
			`INSERT OR IGNORE INTO settings(key, value, updated_at) VALUES (?,?,?)`,
			k, v, time.Now().Unix()); err != nil {
			return fmt.Errorf("db: seed setting %s: %w", k, err)
		}
	}
	return nil
}

func (s *Store) Setting(key, def string) string {
	var v string
	if err := s.sql.QueryRow(`SELECT value FROM settings WHERE key = ?`, key).Scan(&v); err != nil {
		return def
	}
	return v
}

func (s *Store) SetSetting(key, value string) error {
	_, err := s.sql.Exec(`
		INSERT INTO settings(key, value, updated_at) VALUES (?,?,?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
		key, value, time.Now().Unix())
	return err
}

func (s *Store) Tone() core.Tone {
	switch s.Setting(SettingTone, "blunt") {
	case "soft":
		return core.ToneSoft
	case "savage":
		return core.ToneSavage
	default:
		return core.ToneBlunt
	}
}

type Bookmark struct {
	core.Scorable
	Category       core.Category
	Excerpt        string
	ScreenshotPath string
	FaviconURL     string
	HoardScore     float64
	Actionability  float64
	SimHash        uint64
	HasSimHash     bool
	DuplicateOf    string
	CulledAt       int64
	ScoredAt       int64
	ExtractMethod  string
	Verdict        core.Verdict
}

func NormalizeURL(raw string) string { return core.NormalizeURL(raw) }

func (s *Store) Insert(b Bookmark) error {
	var simhash any
	if b.HasSimHash {
		simhash = int64(b.SimHash)
	}
	_, err := s.sql.Exec(`
		INSERT INTO bookmarks (
			id, url, url_normalized, title, excerpt, domain, readable_text,
			screenshot_path, favicon_url, category, hoard_score, actionability,
			simhash, duplicate_count, duplicate_of, open_count,
			created_at, last_opened_at, culled_at, scored_at, extract_method
		) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		b.ID, b.URL, NormalizeURL(b.URL), b.Title, b.Excerpt, b.Domain, b.ReadableText,
		nullString(b.ScreenshotPath), nullString(b.FaviconURL), b.Category.String(),
		b.HoardScore, b.Actionability, simhash, b.DuplicateCount, nullString(b.DuplicateOf),
		b.OpenCount, b.CreatedAt.Unix(), nullInt(b.LastOpenedAt.Unix()), nullInt(b.CulledAt),
		time.Now().Unix(), b.ExtractMethod,
	)
	if err != nil {
		return fmt.Errorf("db: insert bookmark: %w", err)
	}
	return nil
}

func (s *Store) Get(id string) (Bookmark, error) {
	row := s.sql.QueryRow(bookmarkSelect+` WHERE id = ?`, id)
	b, err := scanBookmark(row)
	if errors.Is(err, sql.ErrNoRows) {
		return Bookmark{}, ErrNotFound
	}
	if err != nil {
		return Bookmark{}, err
	}
	s.score(&b, time.Now())
	return b, nil
}

const bookmarkSelect = `
	SELECT id, url, title, excerpt, domain, readable_text,
	       COALESCE(screenshot_path, ''), COALESCE(favicon_url, ''),
	       category, hoard_score, actionability, simhash, duplicate_count,
	       COALESCE(duplicate_of, ''), open_count, created_at,
	       COALESCE(last_opened_at, 0), COALESCE(culled_at, 0),
	       scored_at, extract_method
	FROM bookmarks`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanBookmark(row rowScanner) (Bookmark, error) {
	var b Bookmark
	var createdAt int64
	var lastOpen, culled int64
	var simhash sql.NullInt64
	var cat string

	err := row.Scan(
		&b.ID, &b.URL, &b.Title, &b.Excerpt, &b.Domain, &b.ReadableText,
		&b.ScreenshotPath, &b.FaviconURL,
		&cat, &b.HoardScore, &b.Actionability, &simhash, &b.DuplicateCount,
		&b.DuplicateOf, &b.OpenCount, &createdAt, &lastOpen, &culled,
		&b.ScoredAt, &b.ExtractMethod,
	)
	if err != nil {
		return Bookmark{}, err
	}

	b.Category = core.Category(cat)
	if !b.Category.Valid() {
		b.Category = core.CategoryReference
	}
	b.CreatedAt = time.Unix(createdAt, 0).UTC()
	if lastOpen != 0 {
		b.LastOpenedAt = time.Unix(lastOpen, 0).UTC()
	}
	b.CulledAt = culled
	b.HasSimHash = simhash.Valid
	b.SimHash = uint64(simhash.Int64)
	return b, nil
}

func (s *Store) score(b *Bookmark, now time.Time) {
	v := core.Judge(b.Scorable, now)
	b.Verdict = v
	b.HoardScore = v.Hoard.Total
	b.Actionability = v.Action.Total
	b.Category = v.Category
	b.ScoredAt = time.Now().Unix()
}

func (s *Store) SaveVerdict(b *Bookmark) error {
	_, err := s.sql.Exec(`
		UPDATE bookmarks SET category = ?, hoard_score = ?, actionability = ?,
		       simhash = ?, scored_at = ?
		WHERE id = ?`,
		b.Category.String(), b.HoardScore, b.Actionability, int64(b.SimHash), b.ScoredAt, b.ID)
	return err
}

func (s *Store) All() ([]Bookmark, error) {
	rows, err := s.sql.Query(bookmarkSelect + ` WHERE culled_at IS NULL ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Bookmark
	now := time.Now()
	for rows.Next() {
		b, err := scanBookmark(rows)
		if err != nil {
			return nil, err
		}
		s.score(&b, now)
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s *Store) Count() (int, error) {
	var n int
	err := s.sql.QueryRow(`SELECT count(*) FROM bookmarks WHERE culled_at IS NULL`).Scan(&n)
	return n, err
}

func (s *Store) TouchOpen(id string, now time.Time) error {
	res, err := s.sql.Exec(`
		UPDATE bookmarks
		SET open_count = open_count + 1, last_opened_at = ?
		WHERE id = ? AND culled_at IS NULL`, now.Unix(), id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) IncrementDuplicate(originalID string) error {
	res, err := s.sql.Exec(`
		UPDATE bookmarks SET duplicate_count = duplicate_count + 1 WHERE id = ?`, originalID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) Cull(id string, now time.Time) error {
	res, err := s.sql.Exec(
		`UPDATE bookmarks SET culled_at = ? WHERE id = ? AND culled_at IS NULL`, now.Unix(), id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) Restore(id string) error {
	res, err := s.sql.Exec(`UPDATE bookmarks SET culled_at = NULL WHERE id = ?`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) Graveyard(now time.Time) ([]Bookmark, error) {
	cutoff := now.Add(-GraveyardDays * 24 * time.Hour).Unix()
	rows, err := s.sql.Query(bookmarkSelect+
		` WHERE culled_at IS NOT NULL AND culled_at > ? ORDER BY culled_at DESC`, cutoff)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Bookmark
	for rows.Next() {
		b, err := scanBookmark(rows)
		if err != nil {
			return nil, err
		}
		s.score(&b, now)
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s *Store) PurgeExpired(now time.Time) (int64, error) {
	cutoff := now.Add(-GraveyardDays * 24 * time.Hour).Unix()
	res, err := s.sql.Exec(`DELETE FROM bookmarks WHERE culled_at IS NOT NULL AND culled_at <= ?`, cutoff)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}

type SearchResult struct {
	Bookmark
	Rank  float64
	Score string
}

func (s *Store) Search(q string, limit int) ([]SearchResult, error) {
	q = strings.TrimSpace(q)
	if q == "" || limit <= 0 {
		return nil, nil
	}

	rows, err := s.sql.Query(`
		SELECT b.id, b.url, b.title, b.excerpt, b.domain, b.readable_text,
		       COALESCE(b.screenshot_path, ''), COALESCE(b.favicon_url, ''),
		       b.category, b.hoard_score, b.actionability, b.simhash,
		       b.duplicate_count, COALESCE(b.duplicate_of, ''), b.open_count,
		       b.created_at, COALESCE(b.last_opened_at, 0),
		       COALESCE(b.culled_at, 0), b.scored_at, b.extract_method,
		       bm25(bookmarks_fts) AS rank,
		       -- Prefer whichever column actually holds text. excerpt() returns
		       -- an empty string for an empty column, so a link whose excerpt was
		       -- never filled would otherwise have no preview at all.
		       COALESCE(
		         NULLIF(snippet(bookmarks_fts, 1, '<mark>', '</mark>', '…', 20), ''),
		         NULLIF(snippet(bookmarks_fts, 2, '<mark>', '</mark>', '…', 20), ''),
		         snippet(bookmarks_fts, 0, '<mark>', '</mark>', '…', 20)
		       ) AS preview
		FROM bookmarks_fts
		JOIN bookmarks b ON b.rowid = bookmarks_fts.rowid
		WHERE bookmarks_fts MATCH ? AND b.culled_at IS NULL
		ORDER BY rank
		LIMIT ?`, ftsQuery(q), limit)
	if err != nil {
		return nil, fmt.Errorf("db: search %q: %w", q, err)
	}
	defer rows.Close()

	var out []SearchResult
	now := time.Now()
	for rows.Next() {
		var r SearchResult
		var title, readable, domain string
		var simhash sql.NullInt64
		var createdAt, lastOpen, culled int64
		var cat string

		if err := rows.Scan(
			&r.ID, &r.URL, &title, &r.Excerpt, &domain, &readable,
			&r.ScreenshotPath, &r.FaviconURL,
			&cat, &r.HoardScore, &r.Actionability, &simhash, &r.DuplicateCount,
			&r.DuplicateOf, &r.OpenCount, &createdAt, &lastOpen, &culled,
			&r.ScoredAt, &r.ExtractMethod, &r.Rank, &r.Score,
		); err != nil {
			return nil, err
		}

		r.Title = title
		r.ReadableText = readable
		r.Domain = domain
		r.Category = core.Category(cat)
		if !r.Category.Valid() {
			r.Category = core.CategoryReference
		}
		r.CreatedAt = time.Unix(createdAt, 0).UTC()
		if lastOpen != 0 {
			r.LastOpenedAt = time.Unix(lastOpen, 0).UTC()
		}
		r.CulledAt = culled
		r.HasSimHash = simhash.Valid
		r.SimHash = uint64(simhash.Int64)
		s.score(&r.Bookmark, now)
		out = append(out, r)
	}
	return out, rows.Err()
}

func ftsQuery(q string) string {
	fields := strings.Fields(q)
	if len(fields) == 0 {
		return `""`
	}
	quoted := make([]string, 0, len(fields))
	for i, f := range fields {
		f = strings.ReplaceAll(f, `"`, "")
		if f == "" {
			continue
		}
		if i == len(fields)-1 {
			quoted = append(quoted, `"`+f+`"*`)
		} else {
			quoted = append(quoted, `"`+f+`"`)
		}
	}
	if len(quoted) == 0 {
		return `""`
	}
	return strings.Join(quoted, " ")
}

const (
	EventSaved      = "bookmark.saved"
	EventOpened     = "bookmark.opened"
	EventCulled     = "bookmark.culled"
	EventRestored   = "bookmark.restored"
	EventForged     = "project.forged"
	EventTaskDone   = "task.done"
	EventRoastShown = "roast.shown"
	EventRoastShare = "roast.shared"
)

func (s *Store) Record(name string, at time.Time, bookmarkID string, props map[string]any) error {
	var bid any
	if bookmarkID != "" {
		bid = bookmarkID
	}
	var p any
	if len(props) > 0 {
		b, err := json.Marshal(props)
		if err != nil {
			return err
		}
		p = string(b)
	}
	_, err := s.sql.Exec(
		`INSERT INTO events(name, at, bookmark_id, props) VALUES (?,?,?,?)`,
		name, at.Unix(), bid, p)
	return err
}

func (s *Store) CountEvents(name string, from, to time.Time) (int, error) {
	var n int
	err := s.sql.QueryRow(
		`SELECT count(*) FROM events WHERE name = ? AND at >= ? AND at < ?`,
		name, from.Unix(), to.Unix()).Scan(&n)
	return n, err
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func nullInt(i int64) any {
	if i == 0 {
		return nil
	}
	return i
}
