# CULL

A bookmark manager for people with a bookmark problem.

CULL sorts what you saved, scores how long it has been rotting, finds the
duplicates you saved four times, and tells you plainly which links were never
going to be opened. It can be set to be blunt or outright rude about it.

## Design

Local-first. No account, no cloud, no sync, no backup, no analytics.

The database is a SQLite file in the app's private directory. There is no
server, so there is no operator who could read it. Android cloud backup and
device-transfer backup are disabled for the database. The only network request
the app makes is fetching the page you just shared, so it can work out what the
link is.

## Stack

- **Engine** — Go. Deterministic rules, regex scoring and SimHash
  deduplication. No model inference, on device or otherwise.
- **Storage** — SQLite via `modernc.org/sqlite`. Pure Go, so it cross-compiles
  to Android without cgo.
- **Search** — SQLite FTS5 with BM25 ranking.
- **UI** — Flutter, Material 3, dark only.
- **Design system** — `design/tokens.json` compiles to Dart, CSS and SVG.

## Layout

| Path | What it holds |
| --- | --- |
| `core/` | Scoring, categorisation, SimHash dedupe, roast templates, cull engine |
| `db/` | Store, migrations, FTS5 search, graveyard |
| `ingest/` | Fetch, readability extraction, pipeline |
| `design/` | Token and component schemas, validators, generators |
| `cmd/cullctl/` | Command line interface |
| `cmd/designtool/` | Design token validator and compiler |
| `app_flutter/` | Flutter application |

## Build

Requires Go 1.26+ and Flutter 3.47+.

```sh
go build ./...
go run ./cmd/designtool compile
go run ./cmd/designtool assets
cd app_flutter && flutter run
```

## Command line

```sh
go run ./cmd/cullctl demo
go run ./cmd/cullctl report
go run ./cmd/cullctl save https://example.com
go run ./cmd/cullctl find "query"
go run ./cmd/cullctl stats
```

## Design tokens

`design/tokens.json` is the single source of truth. Colours, type, spacing,
radii, glass levels, motion, grain, blob geometry and accessibility constraints
are defined there and compiled into the app. No widget should contain a
literal design value.

```sh
go run ./cmd/designtool verify
go run ./cmd/designtool contrast
go run ./cmd/designtool inventory
go run ./cmd/designtool palette
```

Contrast is checked in Go, not in the UI: every text colour is validated
against every surface it can appear on, and the suite fails if any pair falls
below the configured minimum.

## Storage layout

`db/migrations/` holds numbered, checksummed migrations. A migration is
verified by hash on every open, so an edited-in-place file is detected rather
than silently corrupting a device.

## Licence

MIT
