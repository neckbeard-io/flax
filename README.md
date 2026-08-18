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

1. Obtain a `libmpv` built `-Dgpl=false`, **with FFmpeg also built LGPL** (no
   `--enable-gpl`, no `--enable-version3`). Today's binaries are neither — see
   [License](#license) for the flags and how they are known. Three specific
   changes to upstream's build get there, and none is speculative:
   - **Drop `--enable-librubberband`.** It is the only thing pulling
     `--enable-gpl`, and flax uses neither time-stretch nor pitch-shift — there
     is no `speed` or `pitch` call anywhere in `lib/`. Free to lose.
   - **Replace OpenSSL.** Apache-2.0 is what forces `--enable-version3`, and
     mbedTLS is Apache-2.0 too, so it is not the swap. GnuTLS (LGPL-2.1+) or
     the platform TLS backends are.
   - **Flip `-Dgpl=false`.** Only meaningful once the two above are done.
2. Audit for GPL-only components. The one that matters today is already clear:
   `af_superequalizer.c`, which the 18-band EQ runs on, is LGPL-2.1-or-later and
   is not gated behind FFmpeg's `CONFIG_GPL`. Re-check when adopting further
   effects — some FFmpeg filters *are* GPL-gated.
3. Link it dynamically and be able to supply source and objects, so a user can
   relink a modified library (LGPL-2.1 §6). The shape of this is already in
   place: libmpv ships as a dynamic `.xcframework` / `.dll` / `.so` and is
   loaded through `DynamicLibrary.open`, never statically linked.
4. Then relicense. Target **LGPL-2.1**, never LGPL-3: v3 carries the same
   anti-tivoization problem as GPLv3 and lands back at the start. VLC took
   exactly this route after being pulled from the App Store for being GPL, so it
   is a travelled path rather than a theory.

Two things about step 1, both from [mpv's own `Copyright`
file](https://github.com/mpv-player/mpv/blob/master/Copyright), because the flag
is easy to over-read:

- **The switch is not a license grant.** Upstream is explicit that "the build
  system is provided 'as is' and using the `-Dgpl=false` configure switch does
  not in itself create a LGPLv2.1+ license grant." It excludes GPL-only files;
  it does not hand you permission. (`-Dgpl=false` is the meson option. Older
  material says `--enable-lgpl`, which was the retired waf build.)
- **FFmpeg can undo it.** "Linked libraries still can affect the final license
  (for example if FFmpeg was built as GPL)." An LGPL mpv linked against a GPL
  FFmpeg is still GPL, and prebuilt FFmpeg is usually GPL — so FFmpeg, not the
  mpv flag, is the hard half of step 1.

What LGPL mode gives up does not touch flax. The disabled set is X11 and Xv
video output, OSS and jack audio, VDPAU/VAAPI, CACA, direct3d, and DVD/DVB/CDDA
streaming — Linux and BSD video paths and legacy disc sources. flax is audio
only, on macOS, Windows and Android. Upstream also says LGPL mode is intended
for libmpv and discourages it for the mpv CLI; libmpv is exactly what flax uses.

Delivering a replacement library needs no patching of the plugin. Each platform
hook (`macos/mpv_audio_kit.podspec`, `windows/CMakeLists.txt`,
`android/build.gradle.kts`) checks for a local binary first and only downloads
when one is absent or fails its SHA-256 — the plugin calls this LOCAL mode, and
the macOS path skips the hash check outright when the `.xcframework` is already
vendored. A self-built libmpv dropped in place is used as-is.

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

flax stands on other people's work — including the AutoEQ measurement data and the equalizer preset
table.

## License

[GNU General Public License v3.0 or later](LICENSE).

This is not a free choice: flax ships prebuilt `libmpv` binaries inside every
artifact, and those binaries are GPL. This is confirmed, not assumed — the
binaries carry no license statement and their FFmpeg configuration string is
stripped, but `mpv_audio_kit`'s author publishes the build scripts at
[ales-drnz/libmpv-scripts](https://github.com/ales-drnz/libmpv-scripts), and
`scripts/shared/_audio_only.sh` settles it:

| Build | Flag | Effect |
| --- | --- | --- |
| FFmpeg | `--enable-gpl` | GPLv2+ |
| FFmpeg | `--enable-version3` | upgrades that to **GPLv3** |
| mpv | `-Dgpl=true` | GPL mode, not the LGPL build |

So the bundled library is **GPLv3**, and the combined work flax distributes has
to be GPLv3-or-later. That is what `LICENSE` already says, which is fortunate
rather than planned — the version was a cautious guess before the build scripts
existed.

Neither flag is incidental; each is pulled in by one dependency:

- `--enable-gpl` is required by **librubberband**, a GPLv2 library FFmpeg lists
  as GPL-only. It provides time-stretch and pitch-shift.
- `--enable-version3` is required by **OpenSSL 3**, which is Apache-2.0 —
  incompatible with GPLv2 but fine with v3. `_versions.sh` says as much.

Practical consequences, since handing a build to someone else is distribution:

- Anyone you give a build to is entitled to the corresponding source, which the
  public repository satisfies.
- A closed-source fork is not an option, and neither is Mac App Store
  distribution — GPLv3's anti-tivoization terms conflict with App Store
  licensing. Neither is planned.

If the bundled libmpv is ever replaced with an LGPL build, this could be relaxed
to a permissive license — see
[Relicensing](#relicensing) for what that actually takes, and why it has to
happen in that order. Until then, GPL is the defensible choice.
