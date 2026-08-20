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

### The top-right corner is reserved

Screens that put controls in the **top-right** must reserve
`windowButtonsReservedWidth` (see `lib/shared/widgets/window_buttons.dart`).
`AppChrome` draws the window controls over every route, and anything else in
that corner ends up underneath them.

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
up. See the maintainer section below.

### Settings & menu organization

Settings are organized by functional domain to prevent the root settings screen from becoming an unorganized list of mixed controls. When adding new settings or options, place them according to these rules:

#### Domain Breakdown
1. **Servers & Connection**: Server profiles, connection state, switching active server.
2. **Appearance & Interface**: Global UI theme (Light/Dark/System), AMOLED black, orientation lock, lyrics presentation and typography.
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

- **Local:** Run `dart format .` on touched files and run any new unit/widget test you added (e.g. `flutter test test/my_feature_test.dart`).
- **CI:** `.github/workflows/ci.yml` automatically validates full repo formatting (`dart format --output=none --set-exit-if-changed .`), static analysis (`flutter analyze --fatal-infos`), and the entire test suite on every pull request and push to `main`. There is no need to run the full test suite twice locally.

The sweep itself is listed in `.git-blame-ignore-revs`, so blame points at
whoever wrote a line rather than at the reformat. GitHub's blame view honors
that file already; locally it takes one command per clone:

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

Two things about that baseline:

- **The formatter's output depends on the SDK version.** The check pins Dart
  3.12.2, matching the Flutter version in `release.yml`. A newer local SDK can
  restyle code CI considers clean, which looks like your change breaking an
  untouched file.
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

### Screenshots and synthetic input — macOS only

Everything in this subsection depends on macOS APIs (`screencapture`, System
Events, `CGEvent`). On Windows and Linux, fall back to widget tests and a manual
look.

After relaunching, capture the actual window and look at it before reporting:

```bash
tool/screenshot.sh                    # -> /tmp/flax-shots/flax-<timestamp>.png
tool/screenshot.sh /tmp/albums.png    # explicit path
```

Then read the PNG to confirm the change rendered. Screenshots are large; crop or
downscale to the region you care about (`sips -Z 1100 shot.png --out small.png`)
rather than reading a full 2900×1880 capture.

The pointer and keyboard can be driven for real, so hover affordances do not
have to be taken on trust from the code:

```bash
tool/pointer.sh -w move 865 891   # hover, window-relative points
tool/pointer.sh -w click 606 23   # move, then left click
tool/pointer.sh park              # pointer out of the way before a clean shot
tool/screenshot.sh /tmp/hover.png
```

Events go to the HID event tap, where real hardware delivers them, so the
Flutter window treats them exactly like physical input. Verified for pointer
moves, left clicks, mouse button 4, and **keystrokes**. A keypress is five lines
of the same Swift the script uses:

```swift
let src = CGEventSource(stateID: .hidSystemState)
CGEvent(keyboardEventSource: src, virtualKey: 49, keyDown: true)?  // 49 = space
  .post(tap: .cghidEventTap)
```

Trackpad swipes are the exception — synthesising those is not worth it; cover
them with a widget test instead.

Screenshot pixels are not points: divide by the backing scale (2 on a Retina
Mac, i.e. image width ÷ window width in points) before passing coordinates.

Park the pointer before capturing a resting state — leave it over a control and
the "before" shot quietly contains a hover.

#### One-time macOS permission setup (required for screenshots)

`tool/screenshot.sh` reads the window rectangle via System Events and captures
it with `screencapture`. The terminal/app running the agent needs **both**
grants in System Settings → Privacy & Security:

- **Accessibility** — to read the flax window position/size.
- **Screen Recording** — for `screencapture` to produce real pixels. Without it,
  capture fails with "could not create image from display". After toggling this
  on, **fully quit and reopen the terminal app** — the grant only takes effect
  for newly launched processes.

Test the grant at any time with: `screencapture -x /tmp/t.png && echo ok`.

A **sleeping display** looks exactly like a crash and isn't one: System Events
reports zero windows, `screencapture` returns a black full-screen image, and
`open` fails with `_LSOpenURLsWithCompletionHandler() ... error -600`. A debug
build takes long enough that the screen can sleep mid-build. Hold it awake for
the whole verification pass rather than diagnosing it again:

```bash
nohup caffeinate -d -u -t 900 >/dev/null 2>&1 &
```

---

## Maintainer only: distributing test builds

Everything below needs repository secrets and workflow permissions. A
contributor cannot run it, and does not need to — open a PR and leave releases
to a maintainer.

`.github/workflows/release.yml` is **manual and opt-in per platform**. It has no
push or tag trigger so releases are triggered deliberately. Since the repo is
public, GitHub Actions runner minutes are free across macOS, Windows, and Linux.

```bash
gh workflow run release.yml -f version=0.4.1 -f macos=true -f windows=true -f linux=true -f android=true
gh run watch $(gh run list --workflow=release.yml -L1 --json databaseId --jq '.[0].databaseId')
```

The `version` input is the whole version story — it becomes the build-name, the
tag (`v<version>`), and the release title, and the workflow creates the tag
itself. The total commit count (`git rev-list --count HEAD`) becomes the build-number
across all platforms in both CI and local builds. **Never bump `version:` in
`pubspec.yaml`**; it is overridden by `--build-name`/`--build-number` on every
build path. Re-running the same version uploads assets to the existing release
(`--clobber`) rather than failing.

### The release body is the changelog. This is enforced, not a convention.

Close off the changelog **before** starting the run, in its own commit on
`main`: rename `## Unreleased` to `## v<version> — <YYYY-MM-DD>` and open a
fresh `## Unreleased`. The workflow tags whatever `main` points at, so a
changelog landed afterwards is not in the release it describes.

`release.yml` then reads `CHANGELOG.md`, extracts the `## v<version>` section,
and publishes it as the release body with a link to the README installation
instructions.

**If the section is missing or empty the run fails**, deliberately and before
anything is published. Do not work around it by editing the workflow — write the
changelog entry, which should have been written as part of the change anyway.

This is enforced because it silently failed for a long time. Every release up to
and including v0.2.3 shipped with the install instructions as its *entire* body:
the workflow built a `notes.md` containing only those, passed it to
`--notes-file`, and never read `CHANGELOG.md` at all. The entries existed; they
just never reached anyone. Re-runs are covered too — an existing release has its
body refreshed rather than keeping whatever it was created with.

macOS builds can also be built locally via `tool/release.sh --mac` (~90s on Apple Silicon):

```bash
tool/release.sh --mac --version 0.4.1   # just the .dmg
tool/release.sh --version 0.4.1         # macOS .dmg + Android .apk, into dist/
gh release upload v0.4.1 dist/flax-0.4.1-macos-universal.dmg
```

**Always pass `--version` when cutting a release.** Without it the script takes
the version from the latest **local** `v*` tag, and the workflow creates the tag
on the runner — so a local build during a release names itself after the
*previous* version and silently overwrites that .dmg in `dist/`. Nothing errors;
you just get an artifact with the wrong version baked in. Either pass
`--version`, or `git fetch --tags` after the workflow has created it.

Windows cannot be cross-compiled from macOS, so it exists only on the runner —
`tool/release.sh` deliberately has no Windows path.

### Signing state, and what testers have to do about it

None of the three are signed with a real certificate, so each OS pushes back on
first launch. This is expected; don't debug it as breakage.

- **macOS** — ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`); the binary is
  universal (x86_64 + arm64), so one .dmg serves Apple Silicon and Intel. On another Mac,
  macOS 15+ reports the app as *damaged*. Fix is one command after installing:
  `xattr -dr com.apple.quarantine /Applications/flax.app`. To upgrade to a
  clean double-click install later: Apple Developer Program, a Developer ID
  Application cert, enable Hardened Runtime, then `notarytool submit --wait`
  and `stapler staple` the .dmg. Only the packaging step changes.
- **Windows** — unsigned; SmartScreen warns, *More info* → *Run anyway*. The
  standalone installer (`flax-<version>-windows-x64-setup.exe`) registers Flax in
  the Start menu and handles all runtime dependencies automatically (or extract
  the portable `.zip` whole).
- **Android** — signed with a shared *test* keystore so builds upgrade in place.
  `android/key.properties` and `android/flax-test.jks` are gitignored; CI
  rebuilds them from the `FLAX_KEYSTORE_BASE64` and `FLAX_KEYSTORE_PASSWORD`
  secrets. If `key.properties` is absent, Gradle silently falls back to the
  per-machine debug keystore — those APKs cannot be installed over a real test
  build. `tool/release.sh` refuses to build rather than ship one.

Android needs `INTERNET` declared in
`android/app/src/main/AndroidManifest.xml`. Debug builds get it injected
automatically and release builds do not, so removing it breaks only release
APKs — every server request fails while everything looks fine in development.
