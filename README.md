# flax

A high-fidelity music player for self-hosted music servers, built with Flutter.
Connects to [Navidrome](https://www.navidrome.org/) or any Subsonic /
OpenSubsonic-compatible server and plays through [mpv](https://mpv.io/), with an
18-band equalizer and AutoEQ headphone correction.

The name is a play on FLAC.

**Platforms:** macOS (universal), Windows 10/11 (x64), Android 7.0+

> **Status: early, and under active development.** The library browser, player,
> equalizer, and AutoEQ all work against a real server. Plenty is still on the
> [roadmap](#roadmap) — check there before filing a missing feature as a bug.
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
- OS media session — now-playing metadata and hardware/media-key controls
- Hi-res format badge (bit depth / sample rate) on the current track

## Roadmap

Roughly in the order it is likely to be tackled. [SPEC.md](SPEC.md) is the
design document and describes all of this in detail — treat it as intent rather
than as a changelog.

**Audio pipeline.** These screens exist and persist what you set, but the value
is not yet read by the player:

- Audio output — exclusive mode, sample rate, bit depth
- Gapless, crossfade, ReplayGain
- Transcoding

**Features not yet built**

- Synchronized lyrics (LRC) — the Subsonic client already fetches them
- Offline sync and a rotating download cache
- Scrobbling — client support exists, nothing drives it
- Local metadata database (`drift` is a declared dependency, currently unused)
- Android Auto
- Last.fm / richer artist info

**Known limitations**

- The AutoEQ database download decompresses a ~341 MB archive entirely in
  memory, so it is desktop-only in practice and needs a streaming rewrite before
  it can work on Android.
- No signed builds. macOS is ad-hoc signed and Windows is unsigned, so both warn
  on first launch; notarization and a Windows certificate are open items.
- No license file (see [below](#license)).

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
`lib/shared/widgets/`. [CLAUDE.md](CLAUDE.md) documents the working
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

Not yet licensed. Without a license file, default copyright applies and nobody
else has the right to use, modify, or redistribute this code — worth resolving
before sharing builds beyond personal testing.
