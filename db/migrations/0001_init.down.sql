-- Reverses 0001_init. Order matters: the FTS triggers must go before the
-- tables they reference.

DROP TRIGGER IF EXISTS bookmarks_fts_au;
DROP TRIGGER IF EXISTS bookmarks_fts_ad;
DROP TRIGGER IF EXISTS bookmarks_fts_ai;
DROP VIRTUAL TABLE IF EXISTS bookmarks_fts;

DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS roast_history;

DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS projects;

DROP INDEX IF EXISTS idx_bookmarks_dupes;
DROP INDEX IF EXISTS idx_bookmarks_simhash;
DROP INDEX IF EXISTS idx_bookmarks_opened;
DROP INDEX IF EXISTS idx_bookmarks_culled;
DROP INDEX IF EXISTS idx_bookmarks_created;
DROP INDEX IF EXISTS idx_bookmarks_category;
DROP INDEX IF EXISTS idx_bookmarks_hoard;
DROP INDEX IF EXISTS idx_bookmarks_url;

DROP TABLE IF EXISTS bookmarks;
