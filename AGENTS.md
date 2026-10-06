# flax — contributor and agent guide

A Flutter desktop (macOS, Windows, Linux) and Android client for a Subsonic-compatible
music server. State is managed with Riverpod; routing with go_router; audio via
`mpv_audio_kit` (libmpv).

```
lib/
  app/          theme, router
  core/         cross-cutting providers
  domain/       models, enums, repository interfaces
  features/     auth, home, library, player, search, settings
  services/     subsonic client, autoeq, musicbrainz, platform integration
  shared/       reusable widgets
```

Feature code lives in `lib/features/<area>/`, reusable widgets in
`lib/shared/widgets/`. [README.md](README.md) covers installing a test build and
licensing; [SPEC.md](SPEC.md) is the design intent and describes considerably
more than is built.

### API & Reference Documentation

When implementing, modifying, or debugging server communication, data models, or endpoints:
- **Navidrome Subsonic API Reference**: [https://www.navidrome.org/docs/developers/subsonic-api/](https://www.navidrome.org/docs/developers/subsonic-api/) — authoritative reference for all Subsonic & OpenSubsonic endpoints, parameter support, and extensions implemented in Navidrome.
- **OpenSubsonic API Specification**: [http://opensubsonic.netlify.app/](http://opensubsonic.netlify.app/) — extensions including structured lyrics (`getLyricsBySongId`), scrobbling, and user management.

**Work is tracked on the
[flax factory board](https://github.com/orgs/neckbeard-io/projects/2), not in
this repo.** Issues carry a native type (Feature / Task / Bug), an `area:*` label
for routing, and an `agent:*` label saying whether they are ready to pick up:

- `agent:ready` — the body is a complete spec; start without asking.
- `agent:needs-spec` — a design decision is owed first; do not guess it.
- `agent:blocked-human` — needs credentials, hardware or a physical device.

Issues labeled `needs-triage` came from outside and have not been validated or
scoped yet. Do not start one.

> **This file is `AGENTS.md`, and `CLAUDE.md` is a symlink to it.** Claude Code
> does not load `AGENTS.md` on its own — verified — so the symlink is what makes
> the conventions below reach it. Edit `AGENTS.md`; never replace the symlink
> with a copy. On Windows, Git checks symlinks out as plain text files unless
> `core.symlinks` is enabled, so a `CLAUDE.md` that contains only the words
> `AGENTS.md` is a broken checkout, not a real file — read this one instead.

---

## Conventions

These are the portable rules. They apply on every platform and are the part of
this document most likely to matter to a change you are making.

### Conventional commits

All commits and pull request titles must adhere to the [Conventional Commits](https://www.conventionalcommits.org/) specification:

`<type>[optional scope]: <description>`

Common types:
- `feat`: A new user-facing feature or capability.
- `fix`: A bug fix.
- `docs`: Documentation changes only (`AGENTS.md`, `README.md`, docstrings).
- `style`: Formatting, missing semicolons, whitespace (no code behavior change).
- `refactor`: Code refactoring without behavior change.
- `perf`: Performance improvements.
- `test`: Adding or updating tests.
- `chore`: Tooling, build scripts, dependencies, CI configuration.

Rules:
- Subject line must be imperative and lowercase (e.g. `feat(player): add crossfade support`).
- Commit with the git identity configured in the clone. Never override it
  (`-c user.name=…`, `-c user.email=…`, `--author`), and add no
  `Co-authored-by:` or AI attribution trailers. GitHub credits a
  `<name>@users.noreply.github.com` address to whichever account owns `<name>`,
  so an invented identity attributes commits to a stranger.

### Stars are ratings, hearts are favorites

These are **two independent fields** on the same entity, not two views of one.
Subsonic confusingly calls the favorite flag "starred", which is why the glyphs
have to keep them apart:

- **Stars** (`StarRating`) — the 0–5 `userRating`. Written with `setRating`.
- **Hearts** (`FavoriteButton`) — the boolean `starred` flag. Written with
  `star` / `unstar`.

Never draw a star for a favorite or a heart for a rating, and never let one
control write the other's field. Tracks, albums and artists each carry their own
pair, so also be clear *which* entity a control acts on — the mini player's pair
is the track's, the queue header's pair is the album's.

### US English

User-facing strings and identifiers are US English: *color*, *center*,
*favorite*. Internationalization is planned but not current — it is tracked as
its own issue, so do not seed the codebase with mixed spellings in the meantime.

### Downloaded means fully available offline

Downloading a track, album or artist caches its whole metadata chain — album
and artist records, biography, lyrics and cover art — so nothing about a
downloaded item needs the server. Two rules keep that true:

- **Covers are stored and found by name, never by request URL.** Use
  `coverCacheKey(id, size)` from `lib/shared/widgets/cover_art_cache.dart`.
  A request URL carries a fresh auth salt, so art filed under one can never be
  looked up again — which is how downloaded covers once went missing offline.
- **Every reader resolves art through `CoverArtCache.findCached`** — screens,
  Android Auto, the notification. It falls back to any stored size of the cover
  before the server, and nothing asks the server for art while offline.
- **A thumbnail is not a stored cover.** The mini player stores a 128px copy
  the moment a track plays, so `storeForOffline` skips only when a copy at
  least the requested size exists. When any size counted, cached tracks were
  left with just the thumbnail, drawn full-screen in the car.

### Hover / mouseover conventions

Interactive elements use the primitives in
`lib/shared/widgets/hover_effects.dart`. Reuse these rather than hand-rolling
`MouseRegion`s so hover feel stays consistent:

- `HoverArtwork` — album/artist cover art. Lifts, shadows, tints, and can fade
  in a play badge (`showPlayBadge: true`). Wrap the `CoverArtImage`.
- `HoverLink` — inline clickable text (album/artist names). Underlines + bolds.
- `HoverSurface` — rows, bars, and panels. Wraps an `InkWell` and adds the
  pointer cursor.
- `HoverIcon` — icon buttons. Scales on hover, with an optional circular
  backdrop; this is what makes hearts and stars read as buttons.

When adding a new tappable element, give it the matching hover affordance in the
same change.

Beware nesting a `HoverSurface` around something that handles its own gestures:
an ancestor `InkWell` beats a `Slider` to the tap, which is how seeking on the
mini player was silently dead once already. Scope the hover surface to the part
that is actually a button.

### Global input lives in AppChrome

Shortcuts and navigation gestures are handled once, in
`lib/shared/widgets/app_chrome.dart`, which wraps every route:

| Input | Action |
| --- | --- |
| `/` | Focus the sidebar search field |
| Space | Play / pause |
| Mouse button 4 | Back |
| Two-finger swipe right | Back |

Two rules these all obey, and any new one must too:

- **Never fire while a text field has focus.** Both shortcuts are printable
  characters; `globalKeyAction(..., isEditing:)` in
  `lib/shared/input/global_keys.dart` is the single place that decides.
- **A horizontal swipe that scrolls something is not a navigation.** The home
  screen's album shelves scroll horizontally with the same gesture, so
  `BackSwipeTracker` stands down for the rest of a swipe once any horizontal
  scrollable moves.

AppChrome is `MaterialApp.router`'s *builder*, which sits above the
`InheritedGoRouter` — `GoRouter.of(context)` finds nothing there. Read the
router from `routerProvider` instead.

### Nothing before runApp may wait on an Activity

On Android, `FlaxApplication` starts the Flutter engine on every process start,
so `main()` often runs with no Activity: Android Auto connecting, a media
button, background sync and the download service all start the process that
way. With no Activity attached, Android silently drops `flutter/platform`
calls (`SystemChrome`, `SystemNavigator`, haptics, clipboard) — the Future never
completes, and a try/catch does nothing because nothing is thrown. Awaiting one
before `runApp` left flax on its splash screen until it was killed, and Android
Auto spinning.

- Everything awaited before `runApp` goes through `bootstrap()` /
  `startupStep()` in `lib/app/bootstrap.dart`, which bounds every step.
- Activity-level concerns such as orientation belong in `MainActivity`, where
  they also apply when an Activity attaches to an engine already running.
- `test/startup_bootstrap_test.dart` fails if `SystemChrome` appears in
  `main.dart` or `bootstrap.dart`. To reproduce a headless start, see
  [docs/VERIFYING.md](docs/VERIFYING.md#android-starts-without-an-activity).

### Android Auto: the large view and the small card

On a widescreen head unit Android Auto splits the screen, and flax can be in
either part. They are built from different things, so say which one you mean:

- **The large view — left, about two-thirds of the screen.** Flax's full app:
  the browse tree, or the full-screen Now Playing with the cover as its
  background. Built from the media browser tree and the media session's
  metadata and art.
- **The small card — right, about a third.** The compact Now Playing card shown
  while another app, usually navigation, has the large view: cover, title,
  controls, and flax's logo, which comes from the
  `androidx.car.app.TintableAttributionIcon` meta-data.

Use "large view (left)" and "small card (right)" in code comments, changelog
lines and conversation. "Panel" or a bare "Now Playing" does not say which,
and the two are fixed in different places.

Both show the cover, but not the same way. The small card opens the media
session's art URI itself, in Android Auto's own process, so the art has to be a
`content://` URI served by `FlaxArtProvider` (`mediaSessionArtUri`). A
`file://` path into flax's storage cannot be opened there: the card stays empty
while the large view still shows the cover. Never put a server URL in the
session either — every media controller can read it, login token included.

### The window title strip is reserved

`AppChrome` draws over the top of every route on desktop (see
`lib/shared/widgets/window_buttons.dart`):

- **Top right:** the window controls. Screens that put controls there must
  reserve `windowButtonsReservedWidth`, or they end up underneath.
- **Top left, Windows and Linux only:** a `windowDragStripHeight`-tall drag
  strip across the rest of the top edge, which swallows taps. Keep tappable
  controls out of it — including in widget tests that wrap `AppChrome`, which
  otherwise pass on macOS and fail on the Linux CI runner.

### Every user-visible change gets a changelog line

[CHANGELOG.md](CHANGELOG.md) is written **as part of the change**, not
reconstructed from `git log` at release time. Reconstructing it is how you end
up shipping notes that describe commits rather than what a tester will notice.

Add the entry under `## Unreleased`, creating that heading if the last release
closed it off:

```markdown
## Unreleased

### Added
- Albums now has Navidrome-style tabs: All, Random, Recently Added, …

### Fixed
- Album art in the grid was drawn taller than wide and cropped every sleeve.
```

Four rules, in order of how often they are got wrong:

- **Keep it tight and punchy.** A single abbreviated sentence per item (aim for
  under 15 words). Skip filler and paragraphs.
  - *Good:* Navidrome-style album tabs (All, Random, Recently Added).
  - *Bad:* Albums screen now has a collection of new Navidrome-style tabs that
    allow the user to easily browse and view all their music in various ways.
- **Write for someone using the app, not reading the diff.** "Report plays back
  to the server so Recently Played stays current" — not "call scrobble() from
  PlayerNotifier". If a change is invisible to a user, it does not need a line;
  a refactor with no behavior change is exactly that.
- **Group under `Added` / `Changed` / `Fixed` / `Removed`**, in that order. Skip
  the headings you have nothing for.
- **Note anything that changes behavior someone relied on**, however small,
  under `Changed`. That is the section people actually read.

Cutting a release renames `## Unreleased` to `## v<version> — <YYYY-MM-DD>` and
starts a fresh `## Unreleased` above it. **That section becomes the GitHub
release body verbatim** — the workflow extracts it and fails the run if it is
missing — followed by the standing install instructions. So a line written badly
here is the line testers read; there is no second pass where someone tidies it
up. Release mechanics are in [docs/RELEASING.md](docs/RELEASING.md).

### Settings & menu organization

Settings are organized by functional domain to prevent the root settings screen from becoming an unorganized list of mixed controls. When adding new settings or options, place them according to these rules:

#### Domain Breakdown
1. **Servers & Connection**: Server profiles, connection state, switching active server.
2. **Appearance & Interface**: Global UI theme (Light/Dark/System), AMOLED black, lyrics presentation and typography.
3. **Audio & Playback**: Audio rendering pipeline and listening behavior:
   - *Inline*: Scrobbling, auto-switch to Now Playing.
   - *Subpages*: Audio Output (DAC hardware, exclusive mode, sample rate), Equalizer (Parametric EQ, AutoEQ headphone database, presets).
4. **Network & Streaming**: On-the-wire data and server transcoding (`/settings/transcoding`):
   - Wi-Fi and Cellular bitrates, server-side transcoding codec (OPUS / AAC / MP3).
5. **Storage & Caching**: Local disk management, offline downloads, and library precaching (`/settings/metadata-cache`):
   - Status overview breakdown (Audio tracks, covers, bios).
   - Audio caching: Auto-cache streamed music, rolling cache quota, audio download workers.
   - Metadata sync: Cover and artist photo quality tiers, bio sync, metadata sync workers, incremental library sync.
   - Maintenance: Clear audio cache, clear metadata & artwork cache.
6. **About & System**: Build numbers, updates, changelog, and license info.

#### Placement Rules
- **Inline vs. Subpage**: Keep simple global toggles on the root screen. Move multi-option configurations, hardware selectors, or heavy visual panels into dedicated subpages.
- **High-Signal Subtitles**: Top-level list tiles navigating to subpages must have dynamic summary subtitles (e.g. displaying current bitrate, DAC name, or cache size) so users can check status without tapping into the subpage.
- **Worker & Thread Separation**: Always differentiate between "Metadata & Art Sync Workers" (lightweight HTTP requests for images/text) and "Audio Download Workers" (heavy multi-MB audio downloads and potential server transcoding). Never combine them into a single generic "threads" setting.

---

## Verifying a change

### Golden rule: after any UI change, rebuild + relaunch before claiming it works

Flutter builds a native app bundle. A running flax instance does **not** pick up
source edits, so the window on screen can silently lag the code — e.g. hover
effects added to a file will simply not appear until a rebuild. Never tell the
user "it's done, look at it" against a stale binary.

Always use the helper (it kills the old process, rebuilds, and relaunches):

```bash
tool/run_flax.sh              # kill -> flutter build macos --debug -> open the .app
tool/run_flax.sh --release    # release build instead
tool/run_flax.sh --no-build   # just kill + relaunch the existing bundle
tool/run_flax.sh --route /albums/<id>   # open straight onto a screen
```

`--route` opens a screen directly instead of navigating to it, which is both
faster and deterministic — no hunting for coordinates, no dependence on what the
previous screen happened to show. It compiles `FLAX_ROUTE` into a debug build and
is ignored entirely in release. Real ids can be read from the app's saved queue
in its preferences.

Do **not** rely on `flutter run` hot reload for verification — a full rebuild is
the only guarantee that the window matches `main`. A debug build from cold takes
a couple of minutes; expect it.

### Checks

- **Local:** Run any new unit/widget test you added (e.g. `flutter test test/my_feature_test.dart`) and format touched files with the **pinned** SDK (below).
- **CI:** `.github/workflows/ci.yml` validates full repo formatting (`dart format --output=none --set-exit-if-changed .`), static analysis (`flutter analyze --fatal-infos`), and the entire test suite on every pull request and push to `main` — not on pushes to `dev`, so the PR is the only place they run. There is no need to run the full test suite twice locally.

The sweep itself is listed in `.git-blame-ignore-revs`, so blame points at
whoever wrote a line rather than at the reformat. GitHub's blame view honors
that file already; locally it takes one command per clone:

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

Two things about that baseline:

- **The formatter's output depends on the SDK version.** CI pins Dart 3.12.2
  (Flutter 3.44.2, as in `ci.yml` and `release.yml`), and a newer local SDK
  restyles code CI considers clean — which is how an untouched file once failed
  CI. Format with the pinned SDK, not your local one:

  ```bash
  curl -sfLO https://storage.googleapis.com/dart-archive/channels/stable/release/3.12.2/sdk/dartsdk-macos-arm64-release.zip
  unzip -qo dartsdk-macos-arm64-release.zip -d /tmp/dart-3.12.2
  /tmp/dart-3.12.2/dart-sdk/bin/dart format --output=none --set-exit-if-changed .
  ```

  (`linux-x64` / `windows-x64` zips for other hosts.)
- **A few numeric tables are deliberately exempt.** The band frequencies, band
  labels and foobar2000 preset table in the equalizer are grids — 18 values per
  row, in band order — and the formatter would give each number its own line.
  They sit inside `// dart format off` / `// dart format on`. That marker must
  read *exactly* `// dart format off` with nothing after it; append an
  explanation to the line and the formatter silently ignores it and reformats
  anyway, so the reasoning goes on the lines above.

Prefer a widget test to a manual check whenever the behavior can be expressed as
one. The pattern used throughout is to split a **dumb presentational widget**
(no providers) from a **provider-wired wrapper**, so geometry and interaction
can be tested without a server, mpv, or a router — see `NowPlayingPanels`,
`SeekBarView`, `QuickSearchPanel`. Trackpad gestures in particular are much
easier to cover with synthetic `PointerPanZoom` events than by hand (see
`test/back_navigation_test.dart`).

### Mobile & responsive UI/UX verification

Flax runs across desktop and mobile screens. Desktop windows (1200+ px) easily fit wide rows that silently overflow and clip on mobile viewports (360–412 px).

Whenever modifying or adding user interfaces, enforce the following:

1. **Defensive Layout**:
   - Never use fixed unconstrained `Row`s for action button groups. Use `Wrap(spacing: 8, runSpacing: 8)` or `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
   - Adapt button designs responsively (e.g. icon-only with tooltip on narrow widths vs text+icon on desktop).
2. **Headless Viewport Tests (Required on UI changes)**:
   - Cover UI changes with a widget test simulating standard mobile phone dimensions (`Size(390, 844)`):
     ```dart
     testWidgets('Screen renders on phone dimensions without overflow', (tester) async {
       tester.view.physicalSize = const Size(390, 844);
       tester.view.devicePixelRatio = 1.0;
       addTearDown(tester.view.reset);

       await tester.pumpWidget(createTestApp(const MyScreen()));
       await tester.pump();

       // Flutter automatically fails the test on any RenderFlex overflow.
       // Assert that interactive controls are within visible screen bounds:
       final rect = tester.getRect(find.byKey(actionKey));
       expect(rect.right, lessThanOrEqualTo(390));
     });
     ```

### Looking at the real app

Recipes live in [docs/VERIFYING.md](docs/VERIFYING.md):

- **macOS** — screenshots (`tool/screenshot.sh`), real pointer and keyboard
  input (`tool/pointer.sh`), and the one-time Accessibility + Screen Recording
  grants they need.
- **Android** — reproducing a start without an Activity (the Android Auto
  case), readiness signals in debug and release logs, seeding a server, and the
  Automotive orientation check.
- **Android Auto** — a real phone over USB driving the Desktop Head Unit
  (`tool/run_dhu.sh`), which shows the large view and the small card;
  updating the phone's flax without wiping it; Android Automotive on an
  emulator. Anything only visible on the car screen is checked this way, not
  on a phone emulator.

---

## Branching and releases

- **Branch from `dev` and open the PR against `dev`.** Never merge feature
  branches into `main`; `dev` reaches `main` through a promotion PR.
- **Never push to `dev` directly.** A push to `dev` skips CI and immediately
  publishes a pre-release to every Dev-channel tester; the PR is the only place
  the checks run. PRs are squash-merged with `(#N)` in the subject.
- **A merge into `dev` publishes `vX.Y.Z-dev.N`** to the Dev update channel,
  with the changelog lines added since the previous tag as its notes. A merge
  into `main` publishes the stable `vX.Y.Z`. Docs-only changes publish nothing.
- **Never bump `version:` in `pubspec.yaml`**; every build path overrides it.
- **Release APKs differ from debug ones.** `INTERNET` must stay declared in the
  Android manifest (debug builds inject it), and an APK built without
  `android/key.properties` cannot install over a test build.

Channels, promotion, manual dispatch, local builds and signing are in
[docs/RELEASING.md](docs/RELEASING.md).
