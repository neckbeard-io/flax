# Verifying on a real platform

Recipes for looking at the running app rather than taking a change on trust.
The rules for when to use them — rebuild before claiming a UI change works,
prefer a widget test — are in [AGENTS.md](../AGENTS.md#verifying-a-change).

## macOS: screenshots and synthetic input

Everything in this section depends on macOS APIs (`screencapture`, System
Events, `CGEvent`). On Windows and Linux, fall back to widget tests and a manual
look.

After relaunching with `tool/run_flax.sh`, capture the actual window and look at
it before reporting:

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

When screenshots are unavailable, the startup log still is: launch the binary
directly (`build/macos/Build/Products/Debug/flax.app/Contents/MacOS/flax`) and
debug builds print every `[Startup]` stage to stdout.

### One-time permission setup

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

## Android: starts without an Activity

Android Auto, a media button, background sync and the download service all
start the process with no Activity, and `main()` runs anyway (see
[the convention](../AGENTS.md#nothing-before-runapp-may-wait-on-an-activity)).
Reproduce that on a phone emulator instead of needing a car:

```bash
flutter build apk --debug --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-debug.apk

adb shell am force-stop com.flaxplayer.flax
# Start the process headlessly. With no key event attached, the receiver
# ignores the broadcast instead of crashing.
adb shell am broadcast -f 0x20 -a android.intent.action.MEDIA_BUTTON \
  -n com.flaxplayer.flax/androidx.media.session.MediaButtonReceiver
sleep 5
# Then open the app on the engine that start created.
adb shell am start -W -n com.flaxplayer.flax/.MainActivity
```

`Status: timeout` from `am start -W` means the app is stuck on its splash
screen. Readiness signals in `adb logcat`:

- **Debug builds** log each stage — `[Startup] … ready`, `[Startup] UI mounted`,
  `[AudioService] AudioService ready`. The last one is what Android Auto waits
  for.
- **Release builds** print only warnings and errors. For readiness, look for
  the native `FlaxMediaSession: MediaSessionCompat explicitly set active` line,
  which only appears once Dart has initialized the media service.

Errors are also saved to a file that survives a force stop, with the log lines
that led up to each one, and adb can read it from a release build:

```bash
adb pull /sdcard/Android/data/com.flaxplayer.flax/files/logs/flax-errors.log
```

The same errors appear under "Saved Errors" in Settings' diagnostics export.

A debug build can be given a server without going through setup, which also
makes an unreachable one easy to simulate. Write the preferences while the app
is stopped:

```bash
adb shell "run-as com.flaxplayer.flax sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'" < prefs.xml
```

with `prefs.xml` holding a `flutter.flax_servers` string (the JSON list
`ServerListNotifier` saves, XML-escaped). A black-hole URL such as
`http://10.255.255.1:4533` gives a server whose connections hang rather than
fail — the case offline handling has to survive. Airplane mode is
`adb shell cmd connectivity airplane-mode enable`.

Check car screens on an Android Automotive emulator too: phones lock to
portrait (`dumpsys activity activities` shows
`requestedOrientation=SCREEN_ORIENTATION_USER_PORTRAIT`), car screens must stay
`UNSPECIFIED`.

## Android Auto: a phone and the Desktop Head Unit

Android Auto runs on the phone and draws onto the car's screen. The Desktop
Head Unit (DHU) is that screen in a window on the Mac, so a real phone over USB
stands in for the car. Use it for anything that only shows on the car screen —
the [large view (left) and the small card (right)](../AGENTS.md#android-auto-the-large-view-and-the-small-card)
— rather than a phone emulator.

One-time setup:

- **Mac:** Android Studio → SDK Manager → SDK Tools → *Android Auto Desktop
  Head Unit Emulator*. It installs to `~/Library/Android/sdk/extras/google/auto/`.
- **Phone:** open Android Auto's settings, tap *Version* about ten times to
  unlock developer settings, then in the ⋮ menu → *Developer settings* turn on
  *Unknown sources*, so a flax that did not come from Play is listed.

Each session:

1. Connect the phone over USB and check `adb devices` lists it.
2. On the phone, Android Auto's ⋮ menu → *Start head unit server*.
3. Run `tool/run_dhu.sh`. It force-stops and restarts flax, waits for its media
   session, forwards port 5277 and opens the DHU in an ultrawide layout
   (`ev6_ultrawide.ini`) that fits the large view and the small card side by
   side. It addresses one phone by serial (`SERIAL=` at the top); change that
   for another phone.
4. For the small card, open navigation in the large view; flax's Now Playing
   moves to the card on the right.

The phone has to be running the build under test. A debug APK cannot install
over a release one — the signing keys differ — without uninstalling flax, which
wipes its cached library and downloads. To update in place, build release with
the same key (`android/key.properties`) and a build number no lower than the
installed one:

```bash
adb shell dumpsys package com.flaxplayer.flax | grep -E 'versionName|versionCode'
flutter build apk --release --target-platform android-arm64 \
  --build-name=<installed versionName> --build-number=<installed versionCode + 1>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Some art problems show without a car: the system media controls in the phone's
notification shade load Now Playing art the same way, from another process, and
log what they refuse — `adb logcat | grep MediaDataLoader`.

Android Automotive — the car's own OS, no phone involved — runs on an emulator
instead: create one from the *Automotive* category in Android Studio's Device
Manager and install flax on it like any other device.
