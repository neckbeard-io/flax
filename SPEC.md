# Flax — Music Player Specification

> A high-fidelity, cross-platform music player built with Flutter.
> Inspired by Symfonium and foobar2000.

**Version:** 0.1.0-draft
**Target Platforms:** Android, macOS, Windows

---

## 1. Project Overview

Flax is a premium music player that connects to self-hosted music servers (starting with Navidrome) and provides audiophile-grade playback with a full parametric equalizer, AutoEQ headphone correction, synchronized lyrics, offline caching, and deep platform integration including Android Auto.

The name is a play on FLAC — the lossless audio format — reflecting the app's commitment to high-fidelity audio.

---

## 2. Architecture

### 2.1 High-Level Stack

| Layer | Technology | Notes |
|---|---|---|
| **UI Framework** | Flutter 3.x | Single codebase for Android, macOS, Windows |
| **State Management** | Riverpod | Compile-safe, testable, supports async |
| **Audio Engine** | `mpv_audio_kit` (mpv v0.41.0) | Full DSP pipeline, bit-perfect output, 87+ audio effects |
| **Local Database** | Drift (SQLite) | Offline metadata cache, EQ presets, sync state |
| **Networking** | Dio | HTTP client for Subsonic/OpenSubsonic API |
| **DI / Routing** | go_router | Declarative routing with deep link support |
| **Theming** | Material 3 + dynamic color | Dark/light modes, custom accent colors |

### 2.2 Why `mpv_audio_kit`

After evaluating the Flutter audio ecosystem, `mpv_audio_kit` is the recommended engine:

- **Full parametric EQ** via `equalizer` (two-pole peaking), `firequalizer` (FIR arbitrary response), `anequalizer` (high-order parametric multiband), plus `lowshelf`, `highshelf`, `biquad` filters
- **18-band ISO graphic EQ** via `superequalizer`
- **Bit-perfect playback** with exclusive mode on WASAPI (Windows), CoreAudio (macOS), and ALSA (Android via USB DAC)
- **Hi-res sample rates** up to 384 kHz DXD, bit depths up to 64-bit float
- **Gapless playback** with prefetch pipeline
- **ReplayGain** support (track/album modes)
- **87 typed audio effects** including compressor, loudness normalization, crossfeed, bass/treble shelves
- **SPDIF passthrough** for AC3, DTS, TrueHD
- **OS media session** integration (media controls, metadata, interruptions)
- **Network streaming** with cache, timeout, and HLS/DASH support
- Targets **macOS, Windows, Linux, iOS, Android**

**Alternatives considered:**
- `just_audio` — EQ only on Android (via Android AudioEffect), no parametric EQ, no bit-perfect
- `sautiflow` — Promising (miniaudio-based, mixed multiband FX), but newer/less proven; no iOS target listed; 3-band + multiband EQ is less flexible than mpv's full filter graph
- `flutter_soloud` — Game-oriented, no bit-perfect, limited EQ

### 2.3 Project Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart                    # MaterialApp, theme, router
│   ├── router.dart                 # go_router configuration
│   └── theme/
│       ├── flax_theme.dart         # Theme data, color schemes
│       └── theme_provider.dart     # Dark/light/system mode provider
├── core/
│   ├── constants.dart
│   ├── errors/                     # Typed exceptions
│   ├── extensions/                 # Dart extensions
│   └── utils/                      # Formatters, helpers
├── data/
│   ├── database/
│   │   ├── database.dart           # Drift database definition
│   │   ├── daos/                   # Data access objects
│   │   └── tables/                 # Table definitions
│   ├── providers/                  # Subsonic API client providers
│   └── repositories/              # Repository implementations
├── domain/
│   ├── models/                     # Domain entities (Album, Artist, Song, etc.)
│   ├── repositories/              # Repository interfaces
│   └── enums/
├── features/
│   ├── auth/                       # Server login/connection
│   ├── library/                    # Artists, Albums, Songs, Genres browsing
│   ├── player/
│   │   ├── player_provider.dart    # Audio engine wrapper
│   │   ├── now_playing_screen.dart
│   │   ├── mini_player.dart
│   │   └── queue_screen.dart
│   ├── equalizer/
│   │   ├── peq_screen.dart         # Parametric EQ UI
│   │   ├── peq_provider.dart       # EQ state management
│   │   ├── autoeq_screen.dart      # AutoEQ headphone profile selector
│   │   └── presets/                # Built-in presets (Rock, etc.)
│   ├── lyrics/
│   │   ├── lyrics_provider.dart    # LRC parser + sync
│   │   ├── lyrics_view.dart        # Synced lyrics display
│   │   └── lrc_parser.dart         # LRC format parser
│   ├── search/
│   ├── playlists/
│   │   ├── playlist_screen.dart
│   │   └── smart_playlist.dart     # Rule-based playlist engine
│   ├── offline/
│   │   ├── sync_service.dart       # Background download manager
│   │   ├── cache_manager.dart      # Rotating cache with eviction
│   │   └── offline_provider.dart
│   ├── favorites/
│   │   └── favorites_provider.dart # Bi-directional star/rating sync
│   ├── artist_info/
│   │   ├── lastfm_service.dart     # Last.fm API integration
│   │   └── artist_info_view.dart   # Rich artist data in now playing
│   └── settings/
│       ├── settings_screen.dart
│       ├── audio_settings.dart     # DAC, sample rate, exclusive mode
│       └── theme_settings.dart
├── services/
│   ├── subsonic/
│   │   ├── subsonic_client.dart    # OpenSubsonic API implementation
│   │   ├── subsonic_models.dart    # API response models
│   │   └── endpoints/             # Per-category endpoint files
│   ├── android_auto/
│   │   └── android_auto_service.dart
│   └── background/
│       └── background_service.dart # Background playback + sync
└── shared/
    └── widgets/                    # Reusable UI components
```

---

## 3. Audio Engine & Playback

### 3.1 Playback Requirements

| Requirement | Implementation |
|---|---|
| **Hi-res playback** | `player.setAudioSampleRate()` — support 44.1/48/88.2/96/192/384 kHz |
| **Bit-perfect output** | `player.setAudioExclusive(true)` + `player.setAudioFormat(Format.auto)` |
| **Gapless playback** | `player.setGapless(Gapless.yes)` + `player.setPrefetchPlaylist(true)` |
| **ReplayGain** | `player.setReplayGain(ReplayGainSettings(mode: .track/.album))` |
| **Format support** | FLAC, ALAC, WAV, AIFF, MP3, AAC, OGG Vorbis, Opus, WMA, WavPack, APE (via mpv/ffmpeg) |
| **DAC selection** | `player.setAudioDevice()` — enumerate and select output devices |
| **SPDIF passthrough** | `player.setAudioSpdif({...})` for AV receiver setups |

### 3.2 Audio Output Configuration

The settings screen should expose:

- **Output device** selector (dropdown of available audio devices)
- **Exclusive mode** toggle (with warning about locking the device)
- **Sample rate** override (Auto / 44.1k / 48k / 88.2k / 96k / 192k)
- **Bit depth** override (Auto / 16-bit / 24-bit / 32-bit float)
- **ReplayGain** mode (Off / Track / Album) with preamp and fallback gain
- **Gapless** toggle
- **Crossfade** — Off (default) / 1–12 seconds. When enabled, overlaps the tail of the current track with the head of the next. Disabled automatically for gapless album transitions when track pairs are from the same album (configurable).

---

## 4. Parametric Equalizer

### 4.1 Architecture

The EQ system is a two-layer stack applied in the `mpv_audio_kit` DSP pipeline:

```
┌─────────────────────────────────────────┐
│  Layer 1: AutoEQ Headphone Correction   │  ← Compensates headphone FR
│  (applied first, optional)              │
├─────────────────────────────────────────┤
│  Layer 2: User Parametric EQ            │  ← User taste adjustments
│  (applied on top)                       │
└─────────────────────────────────────────┘
         ↓
    Audio Output
```

Both layers are implemented as chained `--af` filters in mpv. The AutoEQ layer runs first (correcting the headphone response to a target curve), and the user PEQ runs second (applying personal taste on top of the corrected signal).

### 4.2 User Parametric EQ

**Filter count:** 10 bands (user-configurable, expandable to 20)

Each band exposes:
- **Filter type:** Peaking, Low Shelf, High Shelf, Low Pass, High Pass, Band Pass, Notch
- **Frequency (Fc):** 20 Hz – 20,000 Hz (continuous)
- **Gain:** -20 dB to +20 dB (0.1 dB steps)
- **Q factor:** 0.1 – 30.0 (for peaking/notch); Slope for shelves

**Implementation via mpv_audio_kit:**

For each PEQ band, use the `equalizer` effect (two-pole peaking EQ) or `biquad` for arbitrary filter types. The `firequalizer` filter can also be used for FIR-based arbitrary frequency response curves.

```dart
// Example: Apply a peaking filter at 1 kHz, +3 dB, Q=1.4
await player.updateAudioEffects((e) => e.copyWith(
  equalizer: EqualizerSettings(
    enabled: true,
    frequency: 1000,
    width_type: 'q',
    width: 1.4,
    gain: 3.0,
  ),
));
```

For multiple simultaneous bands, chain via `AudioEffects.custom` with raw lavfi filter strings:

```dart
await player.updateAudioEffects((e) => e.copyWith(
  custom: [
    'lavfi=[equalizer=f=80:t=q:w=0.7:g=5.5]',
    'lavfi=[equalizer=f=250:t=q:w=1.2:g=-3.0]',
    'lavfi=[equalizer=f=1000:t=q:w=1.4:g=2.0]',
    'lavfi=[lowshelf=f=100:t=q:w=0.7:g=4.0]',
    'lavfi=[highshelf=f=8000:t=q:w=0.7:g=3.0]',
  ],
));
```

### 4.3 Built-In Presets

Ship the classic Winamp/foobar2000 presets as parametric EQ configurations. The **Rock** preset (a priority for this project) maps from the original 10-band Winamp values:

**Winamp Rock Preset (original 10-band graphic EQ):**

| Frequency | Gain (dB) |
|---|---|
| 60 Hz | +8.0 |
| 170 Hz | +4.8 |
| 310 Hz | -5.6 |
| 600 Hz | -8.0 |
| 1 kHz | -3.2 |
| 3 kHz | +4.0 |
| 6 kHz | +8.8 |
| 12 kHz | +11.2 |
| 14 kHz | +11.2 |
| 16 kHz | +11.2 |
| **Preamp** | **0 dB** |

This will be translated into a set of parametric EQ bands (peaking + shelves) that reproduce the same frequency response curve. The conversion should be validated by comparing the resulting magnitude response against the original graphic EQ curve.

**Additional presets to ship:**
- Flat
- Rock (priority)
- Soft Rock
- Pop
- Classical
- Jazz
- Full Bass
- Full Treble
- Full Bass & Treble
- Vocal
- Headphones
- Loudness

Users can save/load/rename custom presets. Presets are stored in the local Drift database.

### 4.4 PEQ User Interface

The EQ screen should feature:

- **Frequency response graph** — Interactive canvas showing the combined magnitude response of all active bands. Drag handles to adjust Fc/gain; pinch/scroll to adjust Q.
- **Band list** — Below the graph, a scrollable list of individual band controls with numeric inputs for Fc, Gain, Q, and filter type dropdown.
- **Preset selector** — Dropdown at top with built-in and user presets.
- **Enable/disable toggle** — Global bypass for the entire EQ chain.
- **Pre-amp slider** — -20 dB to +20 dB to prevent clipping.
- **A/B toggle** — Quickly compare EQ on vs. off or between two presets.
- **Visual indicators** — Real-time spectrum analyzer overlay (optional, using `mpv_audio_kit` FFT stream).

---

## 5. AutoEQ Headphone Correction

### 5.1 Concept

AutoEQ provides headphone-specific frequency response correction profiles that flatten a headphone's response to a target curve (typically Harman). These are applied as a separate EQ layer *below* the user's PEQ, so taste adjustments stack on top of a corrected baseline.

### 5.2 Profile Format

AutoEQ profiles are stored as JSON containing parametric EQ filter parameters:

```json
{
  "headphone": "Sennheiser HD 650",
  "source": "oratory1990",
  "target": "harman_over-ear_2018",
  "preamp": -6.2,
  "filters": [
    { "type": "peaking", "fc": 28, "q": 0.46, "gain": 6.3 },
    { "type": "peaking", "fc": 162, "q": 0.91, "gain": -2.3 },
    { "type": "peaking", "fc": 2237, "q": 1.94, "gain": -4.6 },
    { "type": "low_shelf", "fc": 105, "q": 0.7, "gain": 6.0 },
    { "type": "high_shelf", "fc": 10000, "q": 0.7, "gain": -3.5 }
  ]
}
```

### 5.3 Profile Sources

- **Bundled profiles:** Ship a curated set of ~50 popular headphones (from AutoEQ's pre-computed results, oratory1990/crinacle measurements)
- **Import from autoeq.app:** Allow users to paste or import a ParametricEQ.txt file from the AutoEQ web app
- **Custom profiles:** Users can create manual headphone correction profiles using the same filter types

### 5.4 UI

- **Headphone selector** — Searchable list of bundled headphone profiles grouped by brand
- **Active profile indicator** — Shows current headphone correction in the now playing bar
- **Target curve selector** — Harman over-ear 2018, Harman in-ear 2019, Diffuse Field, etc.
- **Fine-tune** — Allow per-filter gain adjustment on top of the AutoEQ base

---

## 6. Backend: Navidrome (Subsonic/OpenSubsonic API)

### 6.1 API Protocol

Navidrome implements **Subsonic API v1.16.1** with **OpenSubsonic extensions**. Flax will use the OpenSubsonic REST API with JSON responses.

**Authentication:**
- Token-based auth: `t = md5(password + salt)`, `s = random salt`
- Future: API key auth when Navidrome adds support

**Base URL format:** `{server}/rest/{endpoint}?u={user}&t={token}&s={salt}&v=1.16.1&c=flax&f=json`

### 6.2 Required Endpoints

| Category | Endpoints | Usage |
|---|---|---|
| **System** | `ping`, `getLicense`, `getOpenSubsonicExtensions` | Connection test, capability discovery |
| **Browsing** | `getArtists`, `getArtist`, `getAlbum`, `getSong`, `getGenres`, `getMusicDirectory`, `getIndexes` | Library browsing |
| **Search** | `search3` | Global search across artists, albums, songs |
| **Album Lists** | `getAlbumList2`, `getStarred2`, `getRandomSongs`, `getSongsByGenre`, `getNowPlaying` | Home screen, discovery |
| **Metadata** | `getArtistInfo2`, `getAlbumInfo2`, `getTopSongs`, `getSimilarSongs2` | Artist/album detail pages (requires Last.fm in Navidrome) |
| **Media** | `stream`, `download`, `getCoverArt`, `getLyrics` | Playback, offline sync, artwork, lyrics |
| **Annotations** | `star`, `unstar`, `setRating`, `scrobble` | Favorites, ratings, play tracking |
| **Playlists** | `getPlaylists`, `getPlaylist`, `createPlaylist`, `updatePlaylist`, `deletePlaylist` | Playlist management |
| **Bookmarks** | `getPlayQueue`, `savePlayQueue` | Resume playback state across devices |
| **Scanning** | `getScanStatus`, `startScan` | Library refresh |

### 6.3 Backend Abstraction

Design the data layer with a `MusicBackend` interface so additional backends (Jellyfin, Plex, local files) can be added later:

```dart
abstract class MusicBackend {
  Future<List<Artist>> getArtists();
  Future<Artist> getArtist(String id);
  Future<Album> getAlbum(String id);
  Future<Song> getSong(String id);
  Future<List<Album>> getAlbumList(AlbumListType type, {int offset, int count});
  Future<SearchResult> search(String query);
  Future<Uri> getStreamUri(String songId, {int? maxBitRate, String? format});
  Future<Uri> getCoverArtUri(String id, {int? size});
  Future<String?> getLyrics(String songId);
  Future<void> star(String id);
  Future<void> unstar(String id);
  Future<void> setRating(String id, int rating);
  Future<void> scrobble(String id, {bool submission = true});
  Future<List<Playlist>> getPlaylists();
  Future<void> savePlayQueue(List<String> songIds, String current, int positionMs);
  // ... etc
}
```

---

## 7. Lyrics (LRC Support)

### 7.1 Sources (Priority Order)

1. **OpenSubsonic `songLyrics` extension** — Structured synced + unsynced lyrics from Navidrome (v2 extension)
2. **Embedded LRC** — Parsed from song metadata tags (LYRICS / UNSYNCEDLYRICS / SYLT)
3. **Sidecar `.lrc` files** — `{filename}.lrc` adjacent to the audio file (fetched via Subsonic API if accessible)
4. **Subsonic `getLyrics` endpoint** — Fallback for unsynced lyrics by artist/title

### 7.2 LRC Parser

Support the full LRC specification:

```
[ti:Song Title]
[ar:Artist Name]
[al:Album Name]
[offset:+/- ms]

[00:12.34] First line of lyrics
[00:15.67] Second line
[00:15.67] <00:15.67> Word <00:16.00> by <00:16.50> word  ← enhanced/word-level sync
```

- **Simple LRC:** Line-level timestamps `[mm:ss.xx]`
- **Enhanced LRC:** Word-level timestamps `<mm:ss.xx>` within lines
- **Multi-line:** Multiple timestamps for repeated lines
- **Offset tag:** Global timing offset
- **Metadata tags:** `[ti:]`, `[ar:]`, `[al:]`, `[by:]`, `[offset:]`

### 7.3 Lyrics Display

The now playing screen shows synced lyrics with:

- **Auto-scroll** — Current line highlighted and centered, smooth scroll animation
- **Word-level highlight** — If enhanced LRC, highlight words as they're sung (karaoke style)
- **Tap to seek** — Tap any lyric line to seek playback to that timestamp
- **Manual offset** — User-adjustable +/- ms offset for poorly synced lyrics
- **Font size** — Adjustable via pinch or settings
- **Blur/fade** — Non-current lines slightly faded for focus
- **Translation toggle** — If dual-language lyrics are available, show/hide translation

---

## 8. Offline Sync & Caching

### 8.1 Sync Methods

| Method | Description |
|---|---|
| **Smart Playlists** | Rule-based playlists (e.g., "genre = rock AND rating >= 4 AND added in last 30 days") are pinned for offline. Songs matching the rules are automatically downloaded. |
| **Favorites** | All starred/favorited songs are synced offline. |
| **Manual Pin** | User can pin individual albums, artists, or playlists for offline. |
| **Play History** | Optionally auto-cache recently played tracks. |

### 8.2 Rotating Offline Cache

The offline cache uses a **time-and-usage-based eviction** policy within a user-configured size limit.

- **Cache size limit** — User-configurable (e.g., 1 GB / 5 GB / 10 GB / 50 GB / Unlimited)
- **Eviction policy** — Composite score based on:
  - **Time since last play** — Tracks not played in a long time are evicted first
  - **Play frequency** — Rarely played tracks score lower than frequently played ones
  - **Age in cache** — Older cached items are weighted for eviction over newer ones
  - Eviction only triggers when cache exceeds the size limit
- **Protected items** — Pinned/favorited/smart-playlist tracks are **never** evicted regardless of age or usage
- **Cache location** — Configurable storage path (important for SD card on Android)
- **Background sync** — Downloads happen on Wi-Fi by default (configurable to include cellular)
- **Partial sync** — Resume interrupted downloads; track per-song download state

### 8.3 Transcoding (Symfonium-style)

Flax supports **per-network transcoding** via Navidrome's `stream` endpoint transcoding parameters (`maxBitRate`, `format`). This allows high-quality playback on Wi-Fi while conserving data on cellular.

| Setting | Options | Default |
|---|---|---|
| **Wi-Fi streaming quality** | Original / FLAC / 320 kbps / 256 kbps / 192 kbps / 128 kbps / 64 kbps | Original |
| **Cellular streaming quality** | Original / FLAC / 320 kbps / 256 kbps / 192 kbps / 128 kbps / 64 kbps / Disabled | 256 kbps |
| **Transcode format** | Opus / AAC / MP3 | Opus |
| **Offline download quality** | Original / FLAC / 320 kbps / 256 kbps / 192 kbps / 128 kbps | Original |

- When set to **Original**, the `stream` URL omits `maxBitRate` and `format` — Navidrome serves the file as-is.
- When a bitrate cap is set, `maxBitRate={value}` and `format={format}` are appended. Navidrome transcodes server-side.
- **Cellular = Disabled** blocks all streaming on cellular; only cached tracks are playable (useful for data-conscious users).
- **Offline download quality** controls what bitrate is used when downloading for offline cache. Setting this lower than Original saves significant storage (e.g., FLAC → 256 kbps Opus).

### 8.4 Offline-Only Mode

Flax has an explicit **Offline-Only Mode** toggle in settings (and quick-settings). When enabled:

- **Library view filters** to only show cached/downloaded content
- **Search** scopes to local metadata only
- **Queue** rejects non-cached tracks (with a toast explaining why)
- **Streaming is disabled** — no network requests for audio
- **Favorites/ratings/scrobbles** are queued locally and synced when the mode is turned off and connectivity is restored
- **Smart playlists** evaluate against local metadata cache only
- **Visual indicator** — A persistent badge/icon in the app bar indicates offline-only mode is active

This mode is distinct from *being offline* (no connectivity). The user may be on Wi-Fi but choose offline-only mode to avoid any network audio traffic (e.g., metered connections, airplane mode preference).

---

## 9. Favorites & Ratings (Bi-Directional Sync)

### 9.1 Star/Favorite

- **Star** a song, album, or artist → immediately calls Subsonic `star` endpoint
- **Unstar** → calls `unstar`
- Stars from other clients (or Navidrome web UI) are synced back to Flax on library refresh
- Conflict resolution: server is source of truth; Flax merges on sync

### 9.2 Ratings

- **1–5 star rating** on songs → calls `setRating` endpoint
- Ratings set in Navidrome or other clients sync back to Flax
- Rating displayed in song list, now playing, and album detail views

### 9.3 Scrobbling

- **Play tracking** via `scrobble` endpoint — submitted when a track has been played for >50% of its duration or >4 minutes (whichever comes first)
- **Now Playing** submission — sent when playback starts (with `submission=false`)
- **Offline scrobbles** — Queued locally and submitted when connectivity is restored

---

## 10. Android Auto

### 10.1 Requirements

- **Media browsing** — Browse library by Artist, Album, Playlist, Genre, Favorites
- **Search** — Voice and text search
- **Playback controls** — Play, pause, skip, seek, shuffle, repeat
- **Queue management** — View and modify the play queue
- **Album art** — Cover art displayed in the Auto UI
- **Favorites** — Star/unstar from Auto interface (if supported)

### 10.2 Implementation

Use `audio_service` package for the `MediaBrowserService` / `MediaSessionService` integration. `mpv_audio_kit` already provides OS media session support (`player.setMediaSession(...)`) which handles:

- Media notification on Android
- Lock screen controls
- Bluetooth AVRCP metadata
- Android Auto media browser tree

The media browser tree structure:

```
Root
├── Recent
├── Artists
│   └── {Artist Name}
│       └── {Album Name}
│           └── {Song}
├── Albums
│   └── {Album Name}
│       └── {Song}
├── Playlists
│   └── {Playlist Name}
│       └── {Song}
├── Favorites
│   └── {Song}
└── Offline
    └── {Song}
```

---

## 11. Last.fm Integration (Artist Info)

### 11.1 Data Fetched

| Data | Source | Display Location |
|---|---|---|
| **Artist biography** | `artist.getInfo` | Now Playing → artist info panel |
| **Artist image** (high-res) | `artist.getInfo` | Now Playing background, artist page |
| **Similar artists** | `artist.getSimilar` | Artist detail page |
| **Top tracks** | `artist.getTopTracks` | Artist detail page |
| **Tags/genres** | `artist.getTopTags` | Artist detail page |
| **Album info** | `album.getInfo` | Album detail page |

### 11.2 Now Playing Screen — Artist Info Panel

The now playing screen has a swipeable panel or tab that shows:

1. **Album art** (large, blurred background)
2. **Synced lyrics** (primary view)
3. **Artist info** (swipe to reveal):
   - Artist photo
   - Short bio (expandable)
   - Similar artists (tappable)
   - Top tracks by this artist
   - Genre tags

### 11.3 API Key

Requires a Last.fm API key. Options:
- Ship a bundled key (rate-limited, acceptable for metadata reads)
- Allow users to provide their own key in settings
- Cache aggressively — artist info rarely changes

### 11.4 Navidrome Integration

Navidrome itself can fetch artist info via Last.fm if configured (`getArtistInfo2`, `getTopSongs`, `getSimilarSongs2`). Prefer using these Subsonic endpoints when available to avoid redundant API calls, falling back to direct Last.fm API when Navidrome doesn't have the data.

---

## 12. Theming

### 12.1 Modes

- **Dark mode** (default)
- **Light mode**
- **System** (follow OS setting)

### 12.2 Color Schemes

- **Dynamic color** — Extract dominant colors from current album art (Material You / dynamic_color package)
- **Fixed accent colors** — User-selectable accent color palette
- **AMOLED black** — Pure black background option for OLED screens

### 12.3 Typography

- Clean, readable font stack
- Adjustable text size for lyrics and lists

### 12.4 Layout

- **Now Playing** — Full-screen immersive with large album art, transport controls, lyrics
- **Mini Player** — Persistent bottom bar with art, title, play/pause, progress
- **Library** — Grid (albums) and list (songs/artists) views with sort/filter
- **Navigation** — Bottom nav bar (Home, Library, Search, Settings) + side rail on desktop/tablet

---

## 13. Data Models

### 13.1 Core Entities

```dart
class Server {
  String id;
  String name;
  String url;
  String username;
  String tokenHash;
  String salt;
  String backendType; // 'navidrome' (future: 'jellyfin', 'plex', etc.)
  bool isActive; // currently selected server
  DateTime lastSync;
  // Per-server transcoding preferences
  TranscodingConfig transcodingConfig;
}

class Artist {
  String id;
  String serverId;
  String name;
  String? sortName;
  String? coverArtId;
  int albumCount;
  bool starred;
  DateTime? starredAt;
  String? musicBrainzId;
  // Last.fm enrichment
  String? biography;
  String? imageUrl;
  List<String>? genres;
}

class Album {
  String id;
  String serverId;
  String artistId;
  String name;
  String artistName;
  String? coverArtId;
  int songCount;
  int duration; // seconds
  int? year;
  String? genre;
  bool starred;
  DateTime? starredAt;
  int? userRating; // 1-5
  DateTime? created;
  String? musicBrainzId;
}

class Song {
  String id;
  String serverId;
  String albumId;
  String artistId;
  String title;
  String artistName;
  String albumName;
  String? coverArtId;
  int duration; // seconds
  int? track;
  int? discNumber;
  int? year;
  String? genre;
  int? bitRate;
  int? sampleRate;
  int? channelCount;
  String? suffix; // file extension
  String? contentType;
  int? size; // bytes
  bool starred;
  DateTime? starredAt;
  int? userRating; // 1-5
  int playCount;
  // ReplayGain
  double? replayGainTrackGain;
  double? replayGainTrackPeak;
  double? replayGainAlbumGain;
  double? replayGainAlbumPeak;
  // Offline
  String? localPath;
  DownloadState downloadState;
}

class Playlist {
  String id;
  String serverId;
  String name;
  String? comment;
  int songCount;
  int duration;
  bool public;
  String ownerId;
  DateTime created;
  DateTime changed;
  String? coverArtId;
}

class SmartPlaylistRule {
  String field; // genre, rating, year, playCount, dateAdded, etc.
  String operator; // equals, contains, greaterThan, lessThan, inLast, etc.
  dynamic value;
  String conjunction; // AND, OR
}

class SmartPlaylist {
  String id;
  String name;
  List<SmartPlaylistRule> rules;
  int? limit;
  String? sortBy;
  bool sortAscending;
  bool syncOffline;
}

class EqPreset {
  String id;
  String name;
  bool isBuiltIn;
  double preamp;
  List<EqBand> bands;
}

class EqBand {
  FilterType type; // peaking, lowShelf, highShelf, lowPass, highPass, bandPass, notch
  double frequency; // Hz
  double gain; // dB
  double q; // Q factor or slope
  bool enabled;
}

class HeadphoneProfile {
  String id;
  String headphoneName;
  String brand;
  String source; // oratory1990, crinacle, custom
  String targetCurve;
  double preamp;
  List<EqBand> filters;
}

enum DownloadState { none, queued, downloading, complete, error }
enum FilterType { peaking, lowShelf, highShelf, lowPass, highPass, bandPass, notch }

class TranscodingConfig {
  StreamQuality wifiQuality;      // original, or max bitrate
  StreamQuality cellularQuality;  // original, max bitrate, or disabled
  String transcodeFormat;         // opus, aac, mp3
  StreamQuality offlineQuality;   // quality for offline downloads
}

enum StreamQuality { original, flac, kbps320, kbps256, kbps192, kbps128, kbps64, disabled }
```

---

## 14. Key User Flows

### 14.1 First Launch

1. Welcome screen → Add Server
2. Enter Navidrome URL, username, password
3. Test connection (`ping`)
4. Discover OpenSubsonic extensions
5. Initial library sync (artists, albums → local DB)
6. Land on Home screen with recent albums, random picks

### 14.2 Playback

1. User taps a song → Queue is set to album/playlist context
2. `stream` URL constructed with auth params → passed to `mpv_audio_kit` `player.open()`
3. EQ chain applied (AutoEQ layer + User PEQ layer)
4. Scrobble "now playing" sent
5. Position/queue saved periodically via `savePlayQueue`
6. At 50% or 4 min → scrobble submission
7. On track end → gapless transition to next via prefetch

### 14.3 Offline Sync

1. User stars a song / pins an album / smart playlist matches
2. Item added to sync queue
3. Background service downloads via `download` endpoint
4. File stored locally; `localPath` updated in DB
5. On playback, if `localPath` exists → play from file; else → stream
6. Cache monitor evicts LRP tracks when limit exceeded (protected items exempt)

---

## 15. Platform-Specific Notes

### 15.1 Android

- **Min SDK:** 24 (Android 7.0) — for USB audio and modern media APIs
- **Android Auto:** `MediaBrowserServiceCompat` / Media3 session via `audio_service`
- **USB DAC:** Exclusive mode via ALSA/AAudio if supported by device
- **Foreground service** for background playback
- **Battery optimization** exemption prompt for background sync

### 15.2 macOS

- **Min target:** macOS 12 (Monterey)
- **CoreAudio** exclusive mode for bit-perfect DAC output
- **Menu bar** integration (optional mini player in menu bar)
- **Keyboard media keys** handled via mpv_audio_kit OS media session

### 15.3 Windows

- **Min target:** Windows 10
- **WASAPI** exclusive mode for bit-perfect output
- **System tray** integration
- **Media transport controls** (Windows SMTC) via mpv_audio_kit

---

## 16. Non-Functional Requirements

| Area | Requirement |
|---|---|
| **Performance** | Library of 100k+ songs should browse smoothly; lazy-load and paginate |
| **Startup time** | < 2 seconds to playing state from cold start |
| **Memory** | < 200 MB baseline; streaming should not leak |
| **Battery** | Background playback should not significantly drain battery |
| **Storage** | Offline cache with configurable limits; clean eviction |
| **Accessibility** | Semantic labels, screen reader support, sufficient contrast |
| **Localization** | English first; structure for i18n |

---

## 17. Dependencies (Initial)

```yaml
dependencies:
  flutter:
    sdk: flutter
  mpv_audio_kit: ^0.4.2          # Audio engine (mpv-based)
  flutter_riverpod: ^2.x          # State management
  riverpod_annotation: ^2.x       # Code generation for providers
  go_router: ^14.x                # Routing
  dio: ^5.x                       # HTTP client
  drift: ^2.x                     # SQLite ORM
  sqlite3_flutter_libs: ^0.5.x    # SQLite native libs
  path_provider: ^2.x             # App directories
  path: ^1.x                      # Path manipulation
  dynamic_color: ^1.x             # Material You color extraction
  cached_network_image: ^3.x      # Image caching
  audio_service: ^0.18.x          # Background audio + Android Auto
  connectivity_plus: ^6.x         # Network state
  crypto: ^3.x                    # MD5 for Subsonic auth
  freezed_annotation: ^2.x        # Immutable models
  json_annotation: ^4.x           # JSON serialization
  collection: ^1.x                # Enhanced collections
  intl: ^0.19.x                   # Date/number formatting
  palette_generator: ^0.3.x       # Album art color extraction
  url_launcher: ^6.x              # External links

dev_dependencies:
  build_runner: ^2.x
  drift_dev: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  riverpod_generator: ^2.x
  flutter_test:
    sdk: flutter
  mockito: ^5.x
  integration_test:
    sdk: flutter
```

---

## 18. Sleep Timer

- **Duration options:** 5 / 10 / 15 / 30 / 45 / 60 / 90 minutes, or custom
- **End of track:** Option to finish the current track before stopping (rather than hard-cutting mid-song)
- **Fade out:** Optional volume fade-out over the last 30 seconds before the timer expires
- **Quick access:** Available from the now playing screen and notification controls
- **Persistent:** Survives app backgrounding; shows countdown in notification

---

## 19. Multi-Server Support

Flax supports connecting to **multiple Navidrome instances** (and eventually different backend types).

- **Server list** — Settings screen shows all configured servers with add/edit/remove
- **Active server** — One server is active at a time; switching servers reloads the library view
- **Per-server state** — Each server has its own sync state, offline cache, and transcoding config
- **Server switching** — Quick-switch from a dropdown in the library header or settings
- **Unified favorites** — Future consideration: optionally merge favorites across servers (complex, deferred)
- **Backend type field** — `Server.backendType` accommodates future Jellyfin/Plex/local-files backends behind the `MusicBackend` interface

---

## 20. Open Questions

1. **Visualizer:** Should the real-time spectrum/waveform visualizer be a first-class feature in the now playing screen, or just in the EQ screen?

2. **`mpv_audio_kit` on Android:** Verify exclusive mode / USB DAC support on Android specifically. May need to assess if mpv's Android audio output (OpenSL ES / AAudio / Oboe) supports true bit-perfect output or if a custom Rust/C bridge (like Flick's approach) is needed for USB DAC scenarios.

3. **Unified library across servers:** When multiple servers are configured, should there be a merged "all servers" view, or strictly one server at a time?

---

## 21. Milestones (Suggested)

| Phase | Scope | Target |
|---|---|---|
| **M1 — Foundation** | Flutter project scaffold, multi-server Navidrome auth, library browsing, basic playback via mpv_audio_kit | — |
| **M2 — Core Playback** | Queue, gapless, crossfade, ReplayGain, DAC settings, mini player, now playing screen, sleep timer | — |
| **M3 — EQ** | Parametric EQ UI + engine integration, built-in presets (Rock priority), AutoEQ import | — |
| **M4 — Lyrics** | LRC parser, synced lyrics display, word-level highlight | — |
| **M5 — Offline & Transcoding** | Per-network transcoding, download manager, smart playlists, rotating cache (time/use eviction), offline-only mode | — |
| **M6 — Social** | Bi-directional favorites/ratings, scrobbling, Last.fm artist info | — |
| **M7 — Platform** | Android Auto, theming (dark/light/dynamic), desktop refinements | — |
| **M8 — Polish** | Performance optimization, accessibility, error handling, beta testing | — |
