# Changelog

What changed in each release, written for someone using flax rather than
reading the diff. Conventions live in [AGENTS.md](AGENTS.md#every-user-visible-change-gets-a-changelog-line);
the short version is that entries are added as part of the change, not
reconstructed at release time.

Releases before v0.1.8 predate this file. Their notes are on the
[releases page](https://github.com/neckbeard-io/flax/releases).

## Unreleased

### Added
- Dedicated Downloads screen (`/downloads`) to browse cached albums, individual tracks, and live background download tasks.
- Downloaded tab on Albums screen for 1-tap filtering of cached music while online.
- Mobile Offline Mode toggle in library screen headers with 1-tap reconnect banner.

### Fixed
- Playing a song from search results now only queues that individual song rather than every matching result.

## v0.5.4 — 2026-08-28

### Added
- Real-time word-by-word karaoke highlighting for Enhanced LRC lyrics.

### Fixed
- Stamped Linux release bundles with accurate version numbers to prevent false self-update offers.
- Stabilized top window update button during background checks to eliminate pill flickering.
- Prevented desktop platforms from triggering background update checks on every window focus change.
- Prevented fresh installations from falsely initializing into offline mode before server setup.
- Linux standalone installer script no longer fails with unbound variable error when creating desktop icon directory.
- Stripped raw timestamp and markup tags from Enhanced LRC lyrics display.
- macOS in-app self-updater now seamlessly swaps the application bundle and restarts in-place without opening Finder DMG windows.

## v0.5.3 — 2026-08-24

### Added
- Global desktop hotkeys for background playback control and keybinding configuration in Settings.
- Locked mobile screen orientation to portrait mode on mobile platforms.
- Linux audio output engine selection in settings (Auto, PipeWire, PulseAudio, ALSA).
- Audio output device selector dialog with dynamic sink enumeration.

### Fixed
- Linux application display name and window icon now correctly show Flax rather than a generic cogwheel.
- Playback stall and silent audio failures on modern Linux distributions like Ubuntu 24.04+.
- Added Ubuntu 24.04+ 64-bit time_t package dependencies to Debian build script.

## v0.5.2 — 2026-08-21

### Added
- Configurable audio cache size limit in gigabytes with quick presets and custom entry.
- Automatic LRU eviction across all cached tracks when quota or disk safety threshold is reached.
- Mobile storage volume selector for switching cache targets to removable SD cards with file migration.
- Low disk space safety guard preventing cache downloads from exhausting device storage.
- Interactive clickable link for GitHub source repository in About & System settings.

## v0.5.1 — 2026-08-20

### Added
- Standalone `curl | bash` installer (`tool/install.sh`) for macOS and Linux, enabling in-app self-updating via the update pill.
- Equalizer screen now shows manual bands, active AutoEQ correction, and their combined sum on one chart with a colour-coded legend.

### Fixed
- AutoEQ back button now returns to the Equalizer screen instead of skipping it.

## v0.5.0 — 2026-08-19

### Added
- Offline mode toggle slider in desktop window caption to view only offline cached music.
- Server reachability probe with 3-second hard timeout that automatically falls back to offline mode.
- In-window toast notification when automatically switching to offline mode.
- "Offline when not on Wi-Fi" option in Transcoding settings to avoid cellular data usage.
- Offline caching and sync for songs, albums, and artists with cascade downloads.
- Right-click and long-press "Cache Offline" context actions on songs, albums, and artists.
- Top header "Cache Offline" toggle buttons on artist and album pages.
- Offline badges on cached song rows, album cards, and artist listings.
- Clear Audio Cache and Clear Metadata & Artwork Cache options in Settings.
- Cached playback indicator in Mini Player and Now Playing screen.
- Determinate linear progress bar and live download speed indicator for background tasks.
- Reopening the app restores the last active screen instead of defaulting to Albums.

### Changed
- Reorganized Settings into structured domain sections with dynamic status subtitles.
- Separated metadata sync workers and audio download workers into independent settings.
- Equalizer header and controls adapt responsively across compact mobile screens.
- Update notification pill uses a download arrow icon instead of sparkles.
- Windows executable and installer icons updated with official Flax branding.
- Release notes condensed to changelog body with streamlined install instructions.

### Removed
- Redundant "Zero all" button in Equalizer (consolidated into Flat preset and Reset).

## v0.4.8 — 2026-08-19

### Added
- Automatic update modal prompt on launch and resume for mobile platforms.
- Update notification badge on Settings bottom navigation tab.

### Changed
- Removed floating update button from mobile status bar (desktop window caption only).

## v0.4.7 — 2026-08-19

### Added
- Settings tab in mobile bottom navigation bar.

### Changed
- AutoEQ database download and decompression now streams to disk, bounding memory to < 3 MB.

### Removed
- Unpaginated flat Songs browse menu and screen across all platforms.

## v0.4.6 — 2026-08-18

### Added
- Multi-platform self-updater with top-bar notification and one-click installer.
- Post-update "What's New" dialog with disable checkbox and settings toggle.
- Android in-app APK installer with system package manager integration.
- Windows Inno Setup silent background updater and auto-restart.
- Homebrew Cask tap and direct download update handlers.

## v0.4.5 — 2026-08-18

### Added

- **Linux desktop support:** Added official Linux desktop support with `.deb` (Debian, Ubuntu, Mint, Pop!_OS), `.rpm` (Fedora, RHEL, openSUSE), and portable `.tar.gz` releases. Includes custom titlebar and window controls, desktop sidebar layout, and native MPRIS media key / hardware playback integration.
- **CI build performance optimizations:** Enabled Gradle build caching and parallel compilation for Android, shared Flutter pub caches across all CI platforms (macOS, Windows, Linux), and streamlined Windows Inno Setup installer packaging.

## v0.4.0 — 2026-08-18

### Added

- **Windows standalone installer:** Windows releases now provide a full Inno Setup installer (`flax-<version>-windows-x64-setup.exe`) that installs Flax into Program Files, creates Start menu/desktop shortcuts, and registers a standard uninstaller in Windows Settings.
- **Similar artists in Now Playing:** The artist panel in Now Playing now shows a strip of similar artists below the biography, complete with cover artwork and click-through navigation to each artist's library page.
- **Streaming and offline transcoding support.** Transcoding settings (bitrate caps, format, and Wi-Fi vs. cellular preferences) are now actively passed to the server on stream requests. Now Playing, Queue, and Mini Player display original vs. active transcode formats (e.g. `FLAC 24/96 → OPUS 256kbps`), and settings include offline caching transcode thread limits.
- **Metadata and artwork caching tiers with cellular warnings.** A dedicated "Metadata Caching" menu allows choosing resolution tiers (Low 256px, Medium 512px, Original) for album covers and artist images, as well as offline artist info (biographies, genres, and metadata). Caching jobs run in the background with live progress in the sidebar, and mobile connections trigger a data-usage warning before syncing.

### Fixed

- **Media keys and macOS playback integration restored.** Hardware play/pause and media keys now reliably control Flax instead of defaulting to Apple Music, thanks to guaranteed bridge initialization on launch, proper Now Playing playback state reporting, and immediate session registration when restoring saved queues.
- **Album pages fetch the full track listing if only a partial set of songs was cached.** If single songs were previously cached into the local database from search, queues, or playback, opening the album now detects the missing tracks and fetches the complete track list instead of showing a truncated track list.
- **Window position restores to the correct monitor on multi-monitor setups.** Flax now detects all connected displays and restores the window onto the secondary monitor where it was last placed (or safely returns to the primary monitor if that display is unplugged).

### Removed

- **Removed redundant "Go to Album" option** from the right-click context menu on albums.
- **Removed misleading play icon** that appeared when hovering over album covers, as clicking an album opens its page rather than starting playback.

## v0.3.0 — 2026-08-17

### Added

- **Browsing loads instantly and works offline.** Artists, albums, artist and album pages, the shuffle on Songs, and search are all kept in a local database and refreshed in the background, so they paint immediately instead of waiting on the server — and they still open with no network at all. flax asks the server whether anything actually changed before refetching, so a library that has not been rescanned costs one tiny request rather than a full reload, and it re-checks whenever you come back to the window.
- **Search finds cached music with no connection**, and still widens to the whole library when the server is reachable.
- **Background work is visible:** Long-running jobs now appear above Settings in the sidebar, with progress, transfer speed and a rough time remaining. Click it for a panel listing everything running, where each job can be canceled.

### Changed

- **Favorites and ratings apply everywhere at once.** Hearting an album on its own page now updates the same album in the queue, and rating a track updates it wherever that track appears — including the mini player. The heart or star also fills the instant you click it rather than after the server answers, and if the server cannot be reached the change is kept and retried instead of silently snapping back.
- **Favorites you change elsewhere now show up.** Hearting something in Navidrome's web interface, or on your phone, is picked up when flax next comes to the foreground — in both directions, so a heart you removed is removed here too.
- **Artist pages list all of an artist's albums.** They previously searched the library for the artist's name and kept whatever matched, which both missed albums and could claim albums belonging to a different artist with a similar name.
- **Downloading the AutoEQ database shows real progress.** It reports megabytes transferred, how fast, and roughly how long is left, instead of a line of text — and it can now be canceled part-way. The download is around 100 MB, so this was worth knowing.

### Fixed

- **Clicking a result in the sidebar search now opens it.** It previously dismissed the dropdown and went nowhere, leaving what you had typed in the box.

## v0.2.3 — 2026-08-15

### Added

- **Auto-switch to Now Playing:** A new setting in Settings → Playback automatically opens the Now Playing screen when you start a track or album from the library.

### Fixed

- **Artist Information panel persists:** The Artist panel on the Now Playing screen now remembers whether it was open and how wide you set it, even after navigating to other screens or restarting the app.

## v0.2.2 — 2026-08-15

### Changed

- The hint text inside the sidebar search field now reads `/ to search` rather than just `Search`, to make the global hotkey discoverable.

## v0.2.1 — 2026-08-13

One fix, worth its own release: the equalizer was not being applied at startup,
which made v0.2.0 sound like it had no EQ at all until you touched the controls.

### Fixed

- **The equalizer was silently off after every launch.** The Equalizer screen
  said On, with your preset and filter, and nothing was being applied — until you
  toggled it off and on, or switched filter. Settings are read from disk a moment
  after the player starts, and the first attempt to apply the curve carried the
  "off" default it saw before that read finished; it reached the audio engine
  last, and so won. Nothing was wrong with your saved settings, and no filter
  choice was affected more than the other.

## v0.2.0 — 2026-08-11

Artwork loading, and the equalizer work from v0.1.9 reaching everybody.

If you are coming from v0.1.8, this also carries everything in v0.1.9 below —
that was a test build cut off a branch for comparing the two equalizer filters by
ear, so most people never saw it. The **Filter** choice on the Equalizer screen is
here to stay: Parametric is the default and is the one that survives a gapless
track change, Graphic is the filter every build before v0.1.9 used, and neither is
going away.

### Fixed

- **Artwork now loads for where you stopped scrolling, not for everywhere you
  passed.** Racing down a long list — the Artists list especially — used to leave
  the images filling in from wherever you started, working forward one at a time,
  because every row scrolled past had already claimed a place in the download
  queue and nothing could take it back. Rows are now only fetched once they have
  stayed on screen briefly, so a fling asks for nothing and the rows you land on
  come first. This now applies however you scroll — trackpad, mouse wheel, or a
  flick on a phone. Album art was less affected only because more of it was
  already cached from previous browsing.

- **Cover art is kept instead of being thrown away and downloaded again.** The
  art cache held only 200 images, which is a couple of screens for a library of
  any size, so artwork you had already seen was constantly re-fetched. It now
  holds 4000 and keeps them for a year. Expect the Artists list in particular to
  get quicker the second time you visit it rather than starting over.

- **Scrolling back over art you just looked at is instant again.** Artwork
  already in memory now appears immediately instead of waiting its turn, and
  without a fade. Flax also keeps far more art decoded and ready — a hundred album
  covers used to be enough to start evicting, so scrolling up a grid meant
  decoding the same covers over again.

- Dropdowns no longer keep a grey box behind the value after you pick something
  from them. It was a focus highlight, so only one per screen ever showed it —
  whichever you touched last — which read as a selection state that meant
  nothing. Hovering a dropdown still highlights it, since that one says the
  control is clickable.

## v0.1.9 — 2026-08-11

A test build for comparing the two equalizer filters by ear. Cut from the
`eq-engine-ab` branch rather than `main`, so it is ahead of v0.1.8 by exactly
the changes below and nothing else.

### Fixed

- **Gapless playback stuttered between tracks.** It was the equalizer, not the
  handover: the audio engine rebuilds its filter chain at every track boundary,
  and the FFT-based filter flax used dropped and audibly refilled its window
  each time. With the EQ switched off there was never a stutter, which is what
  gave it away.

### Added

- **A Filter choice on the Equalizer screen**, under the bands: *Parametric* or
  *Graphic*. Parametric is the new default and is the one that survives a
  gapless track change. Graphic is the filter every earlier build used, kept so
  the two can be compared on real material — the curve you set is identical
  either way, so only the sound of it differs. The choice is remembered and
  takes effect on the track already playing.

  Parametric costs roughly twice the processing of Graphic (measured at about
  5% more of one CPU core on an Apple Silicon Mac), and unlike Graphic its cost
  grows with the number of bands you have moved. Worth knowing on a phone.

## v0.1.8 — 2026-08-10

### Added

- **Albums now has tabs**, in the style Navidrome uses: All, Random, Recently
  Added, Recently Played, Most Played, Favorites and Top Rated. Each shows the
  same grid of cover art.
- **Plays are reported back to the server.** Recently Played and Most Played
  now reflect listening done in flax rather than sitting frozen at whatever
  another client last reported. There is a switch for it in *Settings →
  Playback*, on by default.
- **Gapless playback works.** The queue is handed to the audio engine whole, so
  it opens the next track while the current one is still playing instead of
  going back to the server at every boundary.
- **ReplayGain** levels tracks using the loudness values the server reports,
  per track or per album, in *Settings → Audio Output*. Set to Off by default.
- **Fade Between Tracks**, 1–12 seconds, replacing the Crossfade slider that
  never did anything. Tracks fade out and in; they do not overlap, and turning
  it on turns gapless off, since the two are contradictory.

### Changed

- **Home is gone from the sidebar.** Its Recently Added, Random Picks and Most
  Played shelves are three of the new Albums tabs, and the app opens on Albums.
- The mini player is one target end to end — artwork, title and the gap between
  them all open Now Playing, instead of two differently-sized targets with a
  dead strip between. The seek bar is deliberately still its own.
- Now Playing has its own sidebar entry, above the library, and is always there
  rather than appearing only when something is playing.
- The album sort order is remembered across launches instead of resetting to
  Year (oldest first) every time.
- Audio Output's Gapless, ReplayGain and Crossfade settings are saved. They
  were being forgotten at every launch, on top of being ignored by the player.

### Fixed

- Album art in the Albums grid was drawn taller than it was wide, cropping the
  top and bottom off every sleeve. It is square now, as it is everywhere else.
- Moving to Now Playing showed the previous screen through it for the length of
  the transition — an album grid was plainly visible behind the lyrics.
- Skipping to the next track no longer re-opens the audio output when it does
  not have to.
