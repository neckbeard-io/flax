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

Download and run the installer `flax-<version>-windows-x64-setup.exe` (or extract the portable `.zip` archive whole). The installer automatically places Flax into `Program Files`, adds Start menu shortcuts, and bundles all runtime DLLs. SmartScreen will warn on first launch: *More info* → *Run anyway*.

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

## Distribution Strategy

flax is distributed directly to users and through open app ecosystems under
[GPL-3.0-or-later](LICENSE):

| Platform | Channel | Format | Notes |
| --- | --- | --- | --- |
| **macOS** | GitHub Releases & Homebrew | Universal `.dmg` | Direct double-click `.dmg` on GitHub Releases and `brew install --cask flax` |
| **Windows** | GitHub Releases | Standalone installer (`.exe`) | Packaged installer via Inno Setup bundling all required runtime libraries |
| **Android** | Google Play Store, F-Droid & GitHub Releases | `.aab` / `.apk` | Google Play release for seamless background updates, plus F-Droid and direct `.apk` downloads |

Because flax is committed to user-owned software and open distribution channels
(Google Play, F-Droid, Homebrew, GitHub Releases), GPL-3.0-or-later cleanly and
permanently satisfies all target platforms without downstream library forks.

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

Release builds are triggered via the manual GitHub Actions workflow:

```bash
gh workflow run release.yml -f version=0.4.1 -f macos=true -f windows=true -f android=true
```

The `version` input drives everything: it becomes the build name, the
`v`-prefixed tag, and the release title. Never bump `version:` in
`pubspec.yaml` — it is overridden on every build path.

Since the repository is public, GitHub Actions runners for all platforms (macOS,
Windows, and Linux/Android) run for free with unlimited standard runner minutes.
macOS and Android builds can also be built locally via `tool/release.sh`.

Android release signing uses `android/key.properties` and a keystore, both
gitignored; CI restores them from repository secrets so test APKs upgrade in
place seamlessly across releases.

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

flax stands on other people's work — including the AutoEQ measurement data and the equalizer preset
table.

## License

[GNU General Public License v3.0 or later](LICENSE).

flax is free and open-source software licensed under the **GNU General Public
License v3.0 or later (GPL-3.0-or-later)**. 

The audio pipeline bundles `libmpv` (GPLv3) via `mpv_audio_kit`, which pairs
natively with flax's GPL-3.0 license.

### Distribution & Compliance
- **Source Availability**: The complete source code is publicly maintained in
  this repository.
- **Store & Package Compatibility**: GPL-3.0-or-later is fully supported across
  Google Play, F-Droid, Homebrew, Windows standalone installers, and macOS
  disk images (`.dmg`).
- Anyone distributing binaries must ensure corresponding source code remains
  freely available under GPL-3.0. Closed-source distribution is not permitted.
