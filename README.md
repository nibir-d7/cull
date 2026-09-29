# CULL

**Saved is not the same as read.**

CULL is a bookmark manager for people who save a lot of things and act on very
few of them. It sits on your phone, it sorts what you send it, it ages what you
ignore, and it tells you the truth about the gap. That is the entire product.

No account. No cloud. No sync. No analytics. The list is a file in the app's own
directory, and the only network request CULL ever makes is fetching a page you
just shared so it can work out what it is.

## Download

**Android â€” [cull-0.0.3.apk](https://github.com/nibir-d7/cull/releases/latest)**

Download the APK, allow installation from your browser if Android asks, and open
it. That is the whole install.

Minimum Android 7.0 (API 24). The build is universal, so one APK covers every
device.

> The release is signed with a debug key. It installs and runs fine from a
> direct download, which is the point right now. A Play Store build would need
> a real upload key.

## Why

Most of what you keep is not lost. It is sitting there, perfectly preserved,
unopened, and it is never going to be opened.

The apps built around this problem offer you folders, tags, and a "read it
later" queue. All of those are storage solutions to a prioritisation problem.
A pile of unread bookmarks does not need better organisation; it needs someone
to point at the specific twelve that are not going to happen and ask whether
you meant that.

CULL does exactly that, and then it stops talking. It is not trying to make you
feel bad so that you open it more, and it is not trying to be funny at you. It
makes one argument â€” reading about doing the work has started to feel like
doing the work â€” and it makes it plainly, in a line of text, with the number
next to it.

Three things it does:

- **Sorts for you.** Every link you send is categorised on arrival, from its
  domain and its text. You can overrule it, one tap, on the link's own screen.
- **Ages honestly.** Every link has a hoard score built from its age, how often
  you opened it, how much duplication it carries, and whether anything in it
  tells you what to do next. Nothing is hidden behind a streak or a badge.
- **Offers it back.** The Cull inbox is everything past the point of being worth
  keeping. Cull it and it sits in the Graveyard for 30 days, fully reversible,
  then it is gone.

## How you use it

Open any article, video, product page or thread. Hit **Share**. Choose **CULL**.
It lands in your hoard, already sorted.

That is the whole interaction. There is no "add link" button shouting at you
when you open the app, because the app's job is to show you what you already
saved, not to ask for more. Sharing from another app is the gesture you already
have.

## How it is built

A Go engine â€” categorisation, scoring, SimHash deduplication, FTS5 search,
SQLite â€” behind a `c-shared` library, called from Flutter over `dart:ffi`. No
network round trip, no serialisation service, no web view. The database is a
single SQLite file.

The design is four colours on cream paper, one typeface (Geist), and no
Material. Every control is drawn.

The source is in this repository. Run the tests, not the app, if you want to see
how it holds up:

```
go test ./...
cd app_flutter && flutter test
```
