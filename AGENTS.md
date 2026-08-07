# flax — contributor and agent guide

A Flutter desktop (macOS, Windows) and Android client for a Subsonic-compatible
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
`lib/shared/widgets/`. [README.md](README.md) covers installing a test build,
the roadmap, and licensing.

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
*favorite*. Internationalization is a roadmap item, not a current concern — but
do not seed it with mixed spellings in the meantime.

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

```bash
flutter analyze                     # before finishing any change
flutter test
dart run tool/verify_presets.dart   # equalizer preset table consistency
```

The repo is **not** `dart format` clean. Running it over a file you touched will
reformat unrelated lines and bury your diff — match the surrounding style by
hand instead.

Prefer a widget test to a manual check whenever the behavior can be expressed as
one. The pattern used throughout is to split a **dumb presentational widget**
(no providers) from a **provider-wired wrapper**, so geometry and interaction
can be tested without a server, mpv, or a router — see `NowPlayingPanels`,
`SeekBarView`, `QuickSearchPanel`. Trackpad gestures in particular are much
easier to cover with synthetic `PointerPanZoom` events than by hand (see
`test/back_navigation_test.dart`).

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
push or tag trigger: this is a private repo, so runner minutes are billed at a
multiplier (macOS 10x, Windows 2x, Linux 1x) and nothing expensive should ever
fire by accident. Every platform defaults to off.

```bash
gh workflow run release.yml -f version=0.1.1 -f windows=true -f android=true
gh run watch $(gh run list --workflow=release.yml -L1 --json databaseId --jq '.[0].databaseId')
```

The `version` input is the whole version story — it becomes the build-name, the
tag (`v<version>`), and the release title, and the workflow creates the tag
itself. The run number becomes the build-number. **Never bump `version:` in
`pubspec.yaml`**; it is overridden by `--build-name`/`--build-number` on every
build path. Re-running the same version uploads assets to the existing release
(`--clobber`) rather than failing.

Prefer building macOS **locally** and attaching it — same ad-hoc-signed
universal .dmg, ~90s, and it avoids the 10x runner:

```bash
tool/release.sh              # macOS .dmg + Android .apk, into dist/
tool/release.sh --mac        # just the .dmg
gh release upload v0.1.1 dist/flax-0.1.1-macos-universal.dmg
```

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
- **Windows** — unsigned; SmartScreen warns, *More info* → *Run anyway*. The zip
  must be extracted whole: `flax.exe` will not start without the sibling DLLs
  and `data/` directory.
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
