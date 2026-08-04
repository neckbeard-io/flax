# flax

A Flutter desktop (macOS) client for a Subsonic-compatible music server. State
is managed with Riverpod; routing with go_router. UI code lives under
`lib/features/<area>/` and reusable widgets under `lib/shared/widgets/`.

## Golden rule: after any UI change, rebuild + relaunch before claiming it works

Flutter builds a native `.app`. A running flax instance does **not** pick up
source edits, so the window on screen can silently lag the code — e.g. hover
effects added to a file will simply not appear until a rebuild. Never tell the
user "it's done, look at it" against a stale binary.

Always use the helper (it kills the old process, rebuilds, and relaunches):

```bash
tool/run_flax.sh              # kill -> flutter build macos --debug -> open the .app
tool/run_flax.sh --release    # release build instead
tool/run_flax.sh --no-build   # just kill + relaunch the existing bundle
```

Do **not** rely on `flutter run` hot reload for verification — a full rebuild is
the only guarantee that the window matches `main`. A debug build from cold takes
a couple of minutes; expect it.

## Verify GUI changes with a screenshot

After relaunching, capture the actual window and look at it before reporting:

```bash
tool/screenshot.sh                    # -> /tmp/flax-shots/flax-<timestamp>.png
tool/screenshot.sh /tmp/albums.png    # explicit path
```

Then Read the PNG to confirm the change rendered. For hover/mouseover effects,
a static screenshot can't move the pointer — verify those by reading the code
path and, where possible, screenshotting the pressed/active state.

### One-time macOS permission setup (required for screenshots)

`tool/screenshot.sh` reads the window rectangle via System Events and captures
it with `screencapture`. The terminal/app running Claude Code needs **both**
grants in System Settings → Privacy & Security:

- **Accessibility** — to read the flax window position/size.
- **Screen Recording** — for `screencapture` to produce real pixels. Without it,
  capture fails with "could not create image from display". After toggling this
  on, **fully quit and reopen the terminal app** — the grant only takes effect
  for newly launched processes.

Test the grant at any time with: `screencapture -x /tmp/t.png && echo ok`.

## Hover / mouseover conventions

Interactive elements use the primitives in
`lib/shared/widgets/hover_effects.dart`. Reuse these rather than hand-rolling
`MouseRegion`s so hover feel stays consistent:

- `HoverArtwork` — album/artist cover art. Lifts, shadows, tints, and can fade
  in a play badge (`showPlayBadge: true`). Wrap the `CoverArtImage`.
- `HoverLink` — inline clickable text (album/artist names). Underlines + bolds.
- `HoverSurface` — rows, bars, and panels. Wraps an `InkWell` and adds the
  pointer cursor.

When adding a new tappable element, give it the matching hover affordance in the
same change.

## Distributing test builds

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

## Other

- `dart run tool/verify_presets.dart` — checks the equalizer preset table in
  `lib/features/settings/equalizer_screen.dart` stays consistent.
- `flutter analyze` before finishing a change.
