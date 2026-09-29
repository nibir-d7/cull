-- 0001_init: the CULL schema.
--
-- Three deliberate deviations from Tech.md, each traced to a defect in the
-- original spec. See ROADMAP.md B3, B4, B7.
--
--   * duplicate_count and simhash exist because Brain.md L67-68 references
--     both but the original table had neither -- the dedupe engine had nowhere
--     to write.
--   * culled_at is a timestamp, not a boolean, because Brain.md L109 promises
--     a 30-day recoverable Graveyard. A boolean cannot express "expired".
--   * bookmarks_fts is an EXTERNAL CONTENT table with sync triggers. The
--     original was a standalone FTS5 table, which duplicates every word and
--     silently drifts from `bookmarks` on delete.

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- bookmarks
-- ---------------------------------------------------------------------------

CREATE TABLE bookmarks (
  id              TEXT    PRIMARY KEY,
  url             TEXT    NOT NULL,
  -- Pre-normalised URL: scheme, www, tracking params and trailing slash
  -- stripped. Exact-URL dedupe is a hot path, so it must not be recomputed in
  -- Go on every comparison.
  url_normalized  TEXT    NOT NULL,
  title           TEXT    NOT NULL DEFAULT '',
  excerpt         TEXT    NOT NULL DEFAULT '',
  domain          TEXT    NOT NULL DEFAULT '',
  readable_text   TEXT    NOT NULL DEFAULT '',
  screenshot_path TEXT,
  favicon_url     TEXT,
  category        TEXT    NOT NULL DEFAULT 'reference',
  -- Cached verdict. Recomputed on save, on open, and on the weekly run.
  hoard_score     REAL    NOT NULL DEFAULT 0,
  actionability   REAL    NOT NULL DEFAULT 0,
  -- 64-bit SimHash stored as a signed int64; Go reads and writes uint64
  -- bit patterns through it. NULL means "not yet fingerprinted", which is
  -- meaningfully different from a computed value of 0 (empty text).
  simhash         INTEGER,
  duplicate_count INTEGER NOT NULL DEFAULT 0,
  -- Set when this row was folded into an existing one by content similarity.
  duplicate_of    TEXT    REFERENCES bookmarks(id) ON DELETE SET NULL,
  open_count      INTEGER NOT NULL DEFAULT 0,
  created_at      INTEGER NOT NULL,
  last_opened_at  INTEGER,
  -- B3: was a BOOLEAN, which cannot express a 30-day recovery window.
  culled_at       INTEGER,
  scored_at       INTEGER NOT NULL DEFAULT 0,
  -- Provenance for the extraction, so a bad parse can be diagnosed and retried.
  extract_method  TEXT    NOT NULL DEFAULT 'readability'
);

-- Tier-1 dedupe: the same URL is one bookmark. Partial, so a re-save of a
-- culled link can legitimately create a fresh row.
CREATE UNIQUE INDEX idx_bookmarks_url ON bookmarks(url_normalized) WHERE culled_at IS NULL;

CREATE INDEX idx_bookmarks_hoard    ON bookmarks(hoard_score DESC) WHERE culled_at IS NULL;
CREATE INDEX idx_bookmarks_category ON bookmarks(category)        WHERE culled_at IS NULL;
CREATE INDEX idx_bookmarks_created  ON bookmarks(created_at DESC) WHERE culled_at IS NULL;
CREATE INDEX idx_bookmarks_culled   ON bookmarks(culled_at)      WHERE culled_at IS NOT NULL;
CREATE INDEX idx_bookmarks_opened   ON bookmarks(last_opened_at) WHERE culled_at IS NULL;
-- The weekly cull engine scans this for near-duplicate content.
CREATE INDEX idx_bookmarks_simhash  ON bookmarks(simhash)        WHERE culled_at IS NULL;
CREATE INDEX idx_bookmarks_dupes    ON bookmarks(duplicate_count) WHERE duplicate_count > 0;

-- ---------------------------------------------------------------------------
-- Full-text search  (B4)
-- ---------------------------------------------------------------------------
-- content='bookmarks' makes this an index over the table rather than a second
-- copy of the text. content_rowid links it to bookmarks.rowid. The triggers
-- below are what stop it drifting -- without them a deleted bookmark stays
-- searchable forever, which is the exact failure mode the original schema had.

CREATE VIRTUAL TABLE bookmarks_fts USING fts5(
  title,
  excerpt,
  readable_text,
  content='bookmarks',
  content_rowid='rowid',
  tokenize='porter unicode61'
);

CREATE TRIGGER bookmarks_fts_ai AFTER INSERT ON bookmarks BEGIN
  INSERT INTO bookmarks_fts(rowid, title, excerpt, readable_text)
  VALUES (new.rowid, new.title, new.excerpt, new.readable_text);
END;

CREATE TRIGGER bookmarks_fts_ad AFTER DELETE ON bookmarks BEGIN
  INSERT INTO bookmarks_fts(bookmarks_fts, rowid, title, excerpt, readable_text)
  VALUES ('delete', old.rowid, old.title, old.excerpt, old.readable_text);
END;

-- "UPDATE OF" matters: without it this fires on every open_count bump, and
-- CULL rewrites the FTS entry every single time a user opens a link. Restricting
-- to the indexed columns means the index is only rebuilt when its content
-- actually changes.
CREATE TRIGGER bookmarks_fts_au AFTER UPDATE OF title, excerpt, readable_text ON bookmarks BEGIN
  INSERT INTO bookmarks_fts(bookmarks_fts, rowid, title, excerpt, readable_text)
  VALUES ('delete', old.rowid, old.title, old.excerpt, old.readable_text);
  INSERT INTO bookmarks_fts(rowid, title, excerpt, readable_text)
  VALUES (new.rowid, new.title, new.excerpt, new.readable_text);
END;

-- ---------------------------------------------------------------------------
-- projects & tasks  (B3: Forge had no home)
-- ---------------------------------------------------------------------------
-- Brain.md L111-127 turns a link into a checklist. Without these tables the
-- first Project would have had nowhere to live.

CREATE TABLE projects (
  id                TEXT    PRIMARY KEY,
  title             TEXT    NOT NULL,
  source_bookmark_id TEXT   REFERENCES bookmarks(id) ON DELETE SET NULL,
  -- active | done | abandoned
  status            TEXT    NOT NULL DEFAULT 'active',
  created_at        INTEGER NOT NULL,
  completed_at      INTEGER
);

CREATE INDEX idx_projects_status ON projects(status);

CREATE TABLE tasks (
  id         TEXT    PRIMARY KEY,
  project_id TEXT    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title      TEXT    NOT NULL,
  position   INTEGER NOT NULL DEFAULT 0,
  done_at    INTEGER,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_tasks_project ON tasks(project_id, position);

-- ---------------------------------------------------------------------------
-- roast_history  (B3: streaks and share tracking)
-- ---------------------------------------------------------------------------
-- UNIQUE(week) makes the Sunday job idempotent: re-running it for a week
-- updates the existing row instead of sending the user a second push.

CREATE TABLE roast_history (
  id           TEXT    PRIMARY KEY,
  week         INTEGER NOT NULL UNIQUE,
  generated_at INTEGER NOT NULL,
  headline     TEXT    NOT NULL DEFAULT '',
  png_path     TEXT,
  cullable     INTEGER NOT NULL DEFAULT 0,
  shared_at    INTEGER
);

CREATE INDEX idx_roast_generated ON roast_history(generated_at DESC);

-- ---------------------------------------------------------------------------
-- settings
-- ---------------------------------------------------------------------------
-- Key/value rather than a columns table so Pro flags and tone can ship without
-- a migration. Seeded by the Go layer, not here, so defaults live in one place.

CREATE TABLE settings (
  key        TEXT    PRIMARY KEY,
  value      TEXT    NOT NULL,
  updated_at INTEGER NOT NULL
);

-- ---------------------------------------------------------------------------
-- events  (B3: the four north-star metrics)
-- ---------------------------------------------------------------------------
-- Product.md L63-66 names Implementation Rate, Cull Rate, Roast Share Rate and
-- Save-to-Open Lag. All four are computed from this table offline.

CREATE TABLE events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  at          INTEGER NOT NULL,
  bookmark_id TEXT    REFERENCES bookmarks(id) ON DELETE SET NULL,
  props       TEXT
);

CREATE INDEX idx_events_name_at ON events(name, at DESC);
CREATE INDEX idx_events_bookmark ON events(bookmark_id, at DESC) WHERE bookmark_id IS NOT NULL;
