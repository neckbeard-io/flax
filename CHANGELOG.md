# Changelog

What changed in each release, written for someone using flax rather than
reading the diff. Conventions live in [AGENTS.md](AGENTS.md#every-user-visible-change-gets-a-changelog-line);
the short version is that entries are added as part of the change, not
reconstructed at release time.

Releases before v0.1.8 predate this file. Their notes are on the
[releases page](https://github.com/neckbeard-io/flax/releases).

## Unreleased

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
