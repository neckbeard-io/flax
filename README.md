# flax

A high-fidelity music player for self-hosted music servers, built with Flutter.
Connects to [Navidrome](https://www.navidrome.org/) or any Subsonic /
OpenSubsonic-compatible server and plays through [mpv](https://mpv.io/), with an
18-band equalizer and AutoEQ headphone correction.

The name is a play on FLAC.

**Platforms:** macOS (universal), Windows 10/11 (x64), Android 7.0+

> **Status: early, and under active development.** The library browser, player,
> equalizer, and AutoEQ all work against a real server. Plenty is still
> [planned](#planned-work) — check the board before filing a missing feature as
> a bug.
> There are no signed builds yet, so every platform shows a first-launch warning.

---

## Install a test build

Grab the latest artifacts from
[Releases](https://github.com/neckbeard-io/flax/releases). Each release is a
prerelease and carries all three platforms.

None of the builds are signed with a real certificate, so each OS pushes back the
first time. This is expected — it is not a corrupted download.

### macOS

One `.dmg` serves both Apple Silicon and Intel (the binary is universal). Open
it, drag **flax** to Applications, then clear the download quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/flax.app
```

Without that, macOS 15+ reports the app as *damaged*.

### Windows

Extract **the whole folder** somewhere permanent and run `flax.exe` from inside
it — the executable needs the sibling DLLs and the `data/` directory, so
copying out just the `.exe` will not start. SmartScreen will warn: *More info* →
*Run anyway*.

### Android

Sideload the `.apk` and allow "install unknown apps" for your browser or file
manager when prompted. All test builds share one signing key, so later versions
install over earlier ones without an uninstall.

---

## First run

flax needs a server before it can do anything: enter your Navidrome (or other
Subsonic-compatible) URL, username, and password. Credentials are sent using
Subsonic's salted token scheme rather than as a plaintext password.

---

## What works today

- Browse and search a remote library — home (recently added, random, most
  played), albums, artists, artist and album detail, songs
- Playback with a queue: shuffle, repeat off/all/one, previous/next, seek
- Queue restored across restarts, including playback position
- Volume fader with a perceptual (square-law) taper, mute, scroll-wheel
  adjustment, and a dB readout — persisted across launches
- 18-band graphic equalizer (65 Hz – 20 kHz) with preamp and 22 presets ported
  from foobar2000's stock `.feq` table
- AutoEQ headphone correction from the full ~8850-profile AutoEQ database,
  summed on top of the manual EQ curve, with the correction curve plotted
- Star ratings and favorites
- Time-synced lyrics, with a scrolling panel that follows playback, tap-to-seek
  on any line, and configurable size and justification
- Multi-panel Now Playing on desktop — artist, lyrics and queue, adapting to the
  window width; window size and position persist across launches
- Quick search from anywhere with `/`, plus space to play/pause and
  mouse-button-4 or a two-finger swipe to go back
- OS media session — now-playing metadata and hardware/media-key controls
- Hi-res format badge (bit depth / sample rate) on the current track

## Planned work

Everything not yet built is tracked as issues on the
**[flax factory board](https://github.com/orgs/neckbeard-io/projects/2)** rather
than in this file, so there is one queue instead of a list that quietly goes
stale. Issues are typed (Feature / Task / Bug), routed by `area:*`, and gated by
`agent:*` on whether they are ready to be picked up.

[SPEC.md](SPEC.md) remains the design document behind those issues — treat it as
intent rather than as a changelog; it describes considerably more than is built.

## Relicensing

Relicensing permissively (MIT or Apache-2.0) is possible but blocked on libmpv,
not on preference — a permissive `LICENSE` file changes nothing while the bundled
library is copyleft, because the combined work is what gets distributed. This
only matters if flax should ever ship somewhere GPL cannot go; the Mac App Store
is the specific case, since GPLv3's anti-tivoization terms conflict with App
Store licensing.

In order:

1. Obtain a `libmpv` built `--enable-lgpl`, with FFmpeg also built LGPL (no
   `--enable-gpl`). Today's binaries come from `mpv_audio_kit`'s GitHub releases
   with no licence statement anywhere, and their FFmpeg configuration string is
   stripped, so this means asking upstream or building libmpv here.
2. Audit for GPL-only components. The one that matters today is already clear:
   `af_superequalizer.c`, which the 18-band EQ runs on, is LGPL-2.1-or-later and
   is not gated behind FFmpeg's `CONFIG_GPL`. Re-check when adopting further
   effects — some FFmpeg filters *are* GPL-gated.
3. Link it dynamically and be able to supply source and objects, so a user can
   relink a modified library (LGPL-2.1 §6).
4. Then relicense. Target **LGPL-2.1**, never LGPL-3: v3 carries the same
   anti-tivoization problem as GPLv3 and lands back at the start. VLC took
   exactly this route after being pulled from the App Store for being GPL, so it
   is a travelled path rather than a theory.

Timing is the one real constraint. flax has a single copyright holder today, so
relicensing is unilateral; once outside contributions are accepted under GPL that
stops being true and every contributor has to agree.

---

## Build from source

Requires the **Flutter 3.44.x** stable SDK. `libmpv` is downloaded
automatically during the build for every platform (verified by SHA-256), so
there is no manual audio-library setup.

```bash
flutter pub get
flutter run -d macos          # or: -d windows, or an Android device
```

Platform toolchains, in addition to Flutter:

| Platform | Also needs |
|---|---|
| macOS | Xcode |
| Windows | Visual Studio with the *Desktop development with C++* workload |
| Android | Android SDK 36, NDK `28.2.13676358`, JDK 21 |

### Verifying a UI change

Flutter builds a native app bundle, and a running instance does **not** pick up
source edits — the window on screen can silently lag the code. Rebuild and
relaunch rather than trusting hot reload:

```bash
tool/run_flax.sh              # kill -> build (debug) -> launch
tool/run_flax.sh --release    # release build instead
tool/run_flax.sh --no-build   # just kill + relaunch the existing bundle
tool/screenshot.sh            # capture the window to /tmp/flax-shots/
```

### Checks

```bash
flutter analyze
flutter test
dart run tool/verify_presets.dart   # equalizer preset table consistency
```

---

## Releasing

Release builds are **manual and opt-in per platform**, because the repo is
private and runner minutes bill at a multiplier (macOS 10×, Windows 2×). Nothing
fires on push or on a tag.

```bash
gh workflow run release.yml -f version=0.1.2 -f windows=true -f android=true
```

The `version` input drives everything: it becomes the build name, the
`v`-prefixed tag, and the release title. Never bump `version:` in
`pubspec.yaml` — it is overridden on every build path.

Prefer building macOS locally and attaching it, which avoids the 10× runner:

```bash
tool/release.sh --mac
gh release upload v0.1.2 dist/flax-0.1.2-macos-universal.dmg
```

Windows cannot be cross-compiled from macOS, so it only exists on CI.

Android release signing needs `android/key.properties` and a keystore, both
gitignored; CI restores them from repository secrets. Without them Gradle
silently falls back to a per-machine debug key, and the resulting APKs cannot be
installed over a real test build — `tool/release.sh` refuses to build rather
than ship one.

---

## Architecture

Riverpod for state, go_router for routing, `mpv_audio_kit` (libmpv) for audio.

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
`lib/shared/widgets/`. [AGENTS.md](AGENTS.md) documents the working
conventions — hover affordances, the rebuild-before-you-believe-it rule, and the
release process — and is worth reading before a first change.

One non-obvious detail, since it will bite anyone touching audio: mpv **cubes**
its `volume` property internally, so a fader position cannot be passed straight
through. See the volume section of `lib/features/player/player_provider.dart`.

---

## Credits

flax stands on other people's work — see [CONTRIBUTORS.md](CONTRIBUTORS.md) for
the full list, including the AutoEQ measurement data and the equalizer preset
table.

## License

[GNU General Public License v3.0 or later](LICENSE).

This is not a free choice: flax ships prebuilt `libmpv` binaries inside every
artifact, and mpv is copyleft. Upstream mpv is GPLv2-or-later unless it is
deliberately built `--enable-lgpl`, the binaries flax downloads carry no licence
statement either in the archive or in the plugin that publishes them, and the
FFmpeg configuration string is stripped from them — so there is no way to
confirm they are the LGPL variant. Assuming the GPL build is the safe reading,
and a GPL-licensed whole is valid whichever variant they turn out to be, since
LGPL is one-way compatible with GPL.

Practical consequences, since handing a build to someone else is distribution:

- Anyone you give a build to is entitled to the corresponding source, which the
  public repository satisfies.
- A closed-source fork is not an option, and neither is Mac App Store
  distribution — GPLv3's anti-tivoization terms conflict with App Store
  licensing. Neither is planned.

If the bundled libmpv is ever confirmed to be the LGPL build, or is replaced with
one, this could be relaxed to a permissive licence — see
[Relicensing](#relicensing) for what that actually takes, and why it has to
happen in that order. Until then, GPL is the defensible choice.
