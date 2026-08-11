/// One line of a song's lyrics.
///
/// [start] is the moment the line is sung, already corrected for the offset
/// the server reported. It is null for unsynced lyrics, which are just text.
class LyricLine {
  final Duration? start;
  final String text;

  const LyricLine({required this.text, this.start});
}

/// A song's lyrics as served by the OpenSubsonic `songLyrics` extension.
///
/// Navidrome already returns time-synced lyrics through `getLyricsBySongId`,
/// so there is no LRC parsing to do here — [lines] arrive with per-line start
/// times whenever [synced] is true.
class Lyrics {
  final bool synced;
  final String? lang;
  final String? displayArtist;
  final String? displayTitle;
  final List<LyricLine> lines;

  const Lyrics({
    required this.lines,
    this.synced = false,
    this.lang,
    this.displayArtist,
    this.displayTitle,
  });

  bool get isEmpty => lines.isEmpty;

  /// Index of the line being sung at [position], or -1 when none is — before
  /// the first line, or for unsynced lyrics, which have nothing to highlight.
  ///
  /// A line becomes current exactly *at* its start time, not a tick later.
  ///
  /// Scanned linearly rather than bisected: lyric sheets run to tens of lines,
  /// this is called a few times a second, and a linear scan tolerates the
  /// occasional line that carries no timestamp at all.
  int lineIndexAt(Duration position) {
    var found = -1;
    for (var i = 0; i < lines.length; i++) {
      final start = lines[i].start;
      if (start == null) continue;
      if (start > position) break;
      found = i;
    }
    return found;
  }

  /// Parses the `lyricsList` object of a `getLyricsBySongId` response.
  ///
  /// A song can carry several sheets — different languages, or a synced and an
  /// unsynced copy of the same words. Synced wins, because it is the one the
  /// panel can follow; otherwise the first sheet is used.
  static Lyrics? fromLyricsList(Map<String, dynamic>? lyricsList) {
    final list = lyricsList?['structuredLyrics'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;

    final parsed = list
        .whereType<Map<String, dynamic>>()
        .map(Lyrics.fromJson)
        .where((l) => !l.isEmpty)
        .toList();
    if (parsed.isEmpty) return null;

    return parsed.firstWhere((l) => l.synced, orElse: () => parsed.first);
  }

  /// Parses one entry of `structuredLyrics`.
  factory Lyrics.fromJson(Map<String, dynamic> json) {
    final synced = json['synced'] as bool? ?? false;
    // `offset` shifts every timestamp; the server sends it separately rather
    // than folding it into the starts, so fold it in here and let the rest of
    // the app treat starts as absolute.
    final offset = Duration(milliseconds: json['offset'] as int? ?? 0);
    final rawLines = json['line'] as List<dynamic>? ?? const [];

    final lines = <LyricLine>[];
    for (final raw in rawLines) {
      if (raw is! Map<String, dynamic>) continue;
      final start = raw['start'] as int?;
      lines.add(
        LyricLine(
          text: raw['value'] as String? ?? '',
          start: synced && start != null
              ? Duration(milliseconds: start) + offset
              : null,
        ),
      );
    }

    return Lyrics(
      lines: lines,
      synced: synced && lines.any((l) => l.start != null),
      lang: json['lang'] as String?,
      displayArtist: json['displayArtist'] as String?,
      displayTitle: json['displayTitle'] as String?,
    );
  }

  /// Wraps a plain lyrics blob — the old `getLyrics` endpoint, which has no
  /// timing — as an unsynced sheet.
  static Lyrics? fromPlainText(String? text) {
    if (text == null) return null;
    final lines = text
        .split('\n')
        .map((l) => LyricLine(text: l.trimRight()))
        .toList();
    if (lines.every((l) => l.text.trim().isEmpty)) return null;
    return Lyrics(lines: lines);
  }
}
