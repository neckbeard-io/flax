# Contributors

## Authors

- **Michael Contolini** ([@brutog](https://github.com/brutog)) — author and
  maintainer.

Portions of this codebase were written with **Claude** (Anthropic) via Claude
Code, working alongside the author. Commits produced that way carry a
`Co-Authored-By: Claude` trailer, so `git log` is the authoritative record of
which changes were AI-assisted. Design decisions, review, and everything that
shipped remain the author's responsibility.

## Contributing

flax is early and the internals move around. Two conventions matter more than
anything else, and both exist because they have already caused wasted time:

1. **Rebuild before you believe it.** Flutter produces a native app bundle, and a
   running instance does not pick up source edits — the window in front of you
   can silently lag your change. Use `tool/run_flax.sh`, and capture
   `tool/screenshot.sh` to confirm a UI change actually rendered. Do not rely on
   hot reload to decide something works.
2. **Give new interactive elements a hover affordance** using the primitives in
   `lib/shared/widgets/hover_effects.dart` (`HoverArtwork`, `HoverLink`,
   `HoverSurface`) rather than hand-rolling `MouseRegion`s.

Before opening a change: `flutter analyze`, `flutter test`, and
`dart run tool/verify_presets.dart` if you touched the equalizer table.
[CLAUDE.md](CLAUDE.md) has the longer version of the working conventions, and
[SPEC.md](SPEC.md) is the design intent — note that it describes considerably
more than is built.

## Acknowledgements

flax is mostly a thin, opinionated shell over other people's hard work.

### Audio engine

- **[mpv](https://mpv.io/)** — the entire playback and DSP pipeline. flax bundles
  prebuilt `libmpv` binaries, downloaded at build time and verified by SHA-256.
- **[mpv_audio_kit](https://pub.dev/packages/mpv_audio_kit)** by Alessandro Di
  Ronza — the Flutter/FFI bindings to libmpv, and the reason a single codebase
  can do parametric EQ and bit-perfect output on all three platforms.
  BSD 3-Clause.

### Equalizer and headphone correction

- **[AutoEQ](https://github.com/jaakkopasanen/AutoEq)** by Jaakko Pasanen — the
  project and methodology behind the headphone correction profiles, and the
  ~8850 GraphicEQ curves flax downloads.
- **[AutoEqPackages](https://github.com/timschneeb/AutoEqPackages)** by Tim
  Schneeberger — repackages the AutoEQ results into the indexed archive flax
  fetches, which is what makes on-demand profile lookup practical.
- **[oratory1990](https://www.reddit.com/user/oratory1990)**,
  **[crinacle](https://crinacle.com/)**, and the other measurement sources
  credited per profile — the measurements the corrections are derived from.
- **[foobar2000](https://www.foobar2000.org/)** — the 22 stock graphic-equalizer
  presets in `lib/features/settings/equalizer_screen.dart` are ports of its
  `.feq` preset table.

### Server

- **[Navidrome](https://www.navidrome.org/)** and the
  **[Subsonic](http://www.subsonic.org/pages/api.jsp) /
  [OpenSubsonic](https://opensubsonic.netlify.app/)** API authors — the server
  side flax talks to.

### Framework and packages

Flutter and Dart, plus [Riverpod](https://riverpod.dev),
[go_router](https://pub.dev/packages/go_router),
[Dio](https://pub.dev/packages/dio),
[drift](https://drift.simonbinder.eu/), and the other packages listed in
`pubspec.yaml`.

## A note on licensing

flax itself has no license file yet, which means default copyright applies. That
is a loose end worth closing, and it is not purely a formality here: the bundled
`libmpv` binaries carry mpv's own upstream license terms, which constrain how a
combined work may be redistributed. Anyone planning to distribute flax more
widely than personal test builds should confirm the license of the specific
libmpv binaries being shipped and pick a compatible license for this project.
