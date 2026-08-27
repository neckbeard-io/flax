/// One word (or syllable span) within a time-synced lyric line.
///
/// In Enhanced LRC format, word timestamps are specified using angle brackets,
/// e.g. `<00:12.50>word`. [start] is the moment this word is sung.
class LyricWord {
  final String text;
  final Duration? start;

  const LyricWord({required this.text, this.start});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricWord &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          start == other.start;

  @override
  int get hashCode => Object.hash(text, start);

  @override
  String toString() => 'LyricWord("$text", start: $start)';
}

/// One line of a song's lyrics.
///
/// [start] is the moment the line is sung, already corrected for the offset
/// the server reported. It is null for unsynced lyrics, which are just text.
/// [words] contains word-level timings if the line had Enhanced LRC (<mm:ss.xx>) tags.
class LyricLine {
  final Duration? start;
  final String text;
  final List<LyricWord> words;

  const LyricLine({required this.text, this.start, this.words = const []});

  bool get hasWordTimings =>
      words.isNotEmpty && words.any((w) => w.start != null);

  /// Helper factory to parse a line that may contain Enhanced LRC `<mm:ss.xx>` tags,
  /// HTML/XML tags, or standard text.
  factory LyricLine.fromRawText(
    String rawText, {
    Duration? lineStart,
    Duration offset = Duration.zero,
  }) {
    final wordTagRegex = RegExp(r'<(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?>');
    final matches = wordTagRegex.allMatches(rawText).toList();

    if (matches.isEmpty) {
      // Strip any stray HTML/XML markup if present
      final cleanText = rawText.replaceAll(RegExp(r'<[^>]+>'), '').trimRight();
      return LyricLine(text: cleanText, start: lineStart);
    }

    final words = <LyricWord>[];

    // If there is text before the first tag
    if (matches.first.start > 0) {
      final prefix = rawText.substring(0, matches.first.start);
      final cleanPrefix = prefix.replaceAll(RegExp(r'<[^>]+>'), '');
      if (cleanPrefix.isNotEmpty) {
        words.add(LyricWord(text: cleanPrefix, start: lineStart));
      }
    }

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final tagTime = _parseTimestamp(
        match.group(1)!,
        match.group(2)!,
        match.group(3),
        offset,
      );

      final wordStart = match.end;
      final wordEnd = (i + 1 < matches.length)
          ? matches[i + 1].start
          : rawText.length;
      final wordContent = rawText.substring(wordStart, wordEnd);
      final cleanWord = wordContent.replaceAll(RegExp(r'<[^>]+>'), '');

      if (cleanWord.isNotEmpty) {
        words.add(LyricWord(text: cleanWord, start: tagTime));
      }
    }

    final cleanFullText = rawText
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trimRight();
    final effectiveStart =
        lineStart ?? (words.isNotEmpty ? words.first.start : null);

    return LyricLine(text: cleanFullText, start: effectiveStart, words: words);
  }

  static Duration? _parseTimestamp(
    String minStr,
    String secStr,
    String? fracStr,
    Duration offset,
  ) {
    final min = int.tryParse(minStr);
    final sec = int.tryParse(secStr);
    if (min == null || sec == null) return null;
    var ms = 0;
    if (fracStr != null && fracStr.isNotEmpty) {
      if (fracStr.length == 2) {
        ms = (int.tryParse(fracStr) ?? 0) * 10;
      } else if (fracStr.length == 3) {
        ms = int.tryParse(fracStr) ?? 0;
      } else if (fracStr.length == 1) {
        ms = (int.tryParse(fracStr) ?? 0) * 100;
      }
    }
    return Duration(minutes: min, seconds: sec, milliseconds: ms) + offset;
  }
}

/// A song's lyrics as served by the OpenSubsonic `songLyrics` extension.
///
/// Navidrome already returns time-synced lyrics through `getLyricsBySongId`,
/// with support for standard line timestamps and Enhanced LRC word timings.
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
      final rawValue = raw['value'] as String? ?? '';
      final lineStart = synced && start != null
          ? Duration(milliseconds: start) + offset
          : null;
      lines.add(
        LyricLine.fromRawText(rawValue, lineStart: lineStart, offset: offset),
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
        .map((l) => LyricLine.fromRawText(l.trimRight()))
        .toList();
    if (lines.every((l) => l.text.trim().isEmpty)) return null;
    return Lyrics(lines: lines);
  }

  /// Parses standard and Enhanced LRC format lyrics (e.g. `[01:23.45] lyric text`).
  static Lyrics? fromLrcText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lrcRegex = RegExp(r'^\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\](.*)$');
    final rawLines = text.split('\n');
    final lines = <LyricLine>[];
    var isSynced = false;

    for (final raw in rawLines) {
      final trimmed = raw.trimRight();
      final match = lrcRegex.firstMatch(trimmed);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final fracStr = match.group(3) ?? '0';
        final ms = fracStr.length == 2
            ? int.parse(fracStr) * 10
            : int.parse(fracStr);
        final duration = Duration(minutes: min, seconds: sec, milliseconds: ms);
        final lineRemainder = match.group(4) ?? '';
        lines.add(LyricLine.fromRawText(lineRemainder, lineStart: duration));
        isSynced = true;
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('[')) {
        lines.add(LyricLine.fromRawText(trimmed));
      }
    }

    if (lines.isEmpty) return fromPlainText(text);
    return Lyrics(lines: lines, synced: isSynced);
  }
}
