import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/lyrics.dart';

/// One entry of a `structuredLyrics` array, as Navidrome sends it.
Map<String, dynamic> _sheet({
  bool synced = true,
  int? offset,
  String? lang,
  List<Map<String, dynamic>>? lines,
}) => {
  'synced': synced,
  'offset': ?offset,
  'lang': ?lang,
  'displayArtist': 'Agalloch',
  'displayTitle': 'Limbs',
  'line':
      lines ??
      [
        {'start': 0, 'value': 'first'},
        {'start': 5000, 'value': 'second'},
        {'start': 12500, 'value': 'third'},
      ],
};

void main() {
  group('lineIndexAt', () {
    final lyrics = Lyrics.fromJson(_sheet());

    test('nothing is current before the first line starts', () {
      final early = Lyrics.fromJson(
        _sheet(
          lines: [
            {'start': 3000, 'value': 'first'},
          ],
        ),
      );
      expect(early.lineIndexAt(const Duration(milliseconds: 2999)), -1);
    });

    test('a line becomes current exactly at its start', () {
      expect(lyrics.lineIndexAt(const Duration(milliseconds: 5000)), 1);
      expect(lyrics.lineIndexAt(const Duration(milliseconds: 4999)), 0);
    });

    test('holds the line until the next one starts', () {
      expect(lyrics.lineIndexAt(const Duration(milliseconds: 5001)), 1);
      expect(lyrics.lineIndexAt(const Duration(milliseconds: 12499)), 1);
      expect(lyrics.lineIndexAt(const Duration(milliseconds: 12500)), 2);
    });

    test('the last line stays current to the end of the song', () {
      expect(lyrics.lineIndexAt(const Duration(minutes: 9)), 2);
    });

    test('unsynced lyrics have no current line', () {
      final plain = Lyrics.fromPlainText('one\ntwo')!;
      expect(plain.synced, isFalse);
      expect(plain.lineIndexAt(const Duration(seconds: 30)), -1);
    });

    test('a line with no timestamp does not become current', () {
      final gappy = Lyrics.fromJson(
        _sheet(
          lines: [
            {'start': 0, 'value': 'first'},
            {'value': 'no timestamp'},
            {'start': 9000, 'value': 'third'},
          ],
        ),
      );
      expect(gappy.lineIndexAt(const Duration(seconds: 3)), 0);
      expect(gappy.lineIndexAt(const Duration(seconds: 9)), 2);
    });
  });

  group('parsing', () {
    test('offset is folded into every start time', () {
      final shifted = Lyrics.fromJson(_sheet(offset: -500));
      expect(shifted.lines[1].start, const Duration(milliseconds: 4500));
      // The shift moves the boundary with it.
      expect(shifted.lineIndexAt(const Duration(milliseconds: 4500)), 1);
    });

    test('synced lyrics keep their start times', () {
      final parsed = Lyrics.fromJson(_sheet());
      expect(parsed.synced, isTrue);
      expect(parsed.lines.map((l) => l.text), ['first', 'second', 'third']);
      expect(parsed.lines.first.start, Duration.zero);
      expect(parsed.displayTitle, 'Limbs');
    });

    test('an unsynced sheet drops timestamps it should not have', () {
      final parsed = Lyrics.fromJson(_sheet(synced: false));
      expect(parsed.synced, isFalse);
      expect(parsed.lines.every((l) => l.start == null), isTrue);
    });

    test('a sheet claiming to be synced but carrying no times is not', () {
      final parsed = Lyrics.fromJson(
        _sheet(
          lines: [
            {'value': 'first'},
            {'value': 'second'},
          ],
        ),
      );
      expect(parsed.synced, isFalse);
    });

    test('the synced sheet wins when a song has several', () {
      final picked = Lyrics.fromLyricsList({
        'structuredLyrics': [
          _sheet(synced: false, lang: 'eng'),
          _sheet(lang: 'deu'),
        ],
      });
      expect(picked!.synced, isTrue);
      expect(picked.lang, 'deu');
    });

    test('the first sheet is used when none is synced', () {
      final picked = Lyrics.fromLyricsList({
        'structuredLyrics': [
          _sheet(synced: false, lang: 'eng'),
          _sheet(synced: false, lang: 'deu'),
        ],
      });
      expect(picked!.lang, 'eng');
    });

    test('an absent or empty list is no lyrics at all', () {
      expect(Lyrics.fromLyricsList(null), isNull);
      expect(Lyrics.fromLyricsList({}), isNull);
      expect(Lyrics.fromLyricsList({'structuredLyrics': []}), isNull);
      expect(
        Lyrics.fromLyricsList({
          'structuredLyrics': [_sheet(lines: [])],
        }),
        isNull,
      );
    });

    test(
      'plain text becomes an unsynced sheet, blank text becomes nothing',
      () {
        expect(Lyrics.fromPlainText('one\ntwo')!.lines.length, 2);
        expect(Lyrics.fromPlainText(null), isNull);
        expect(Lyrics.fromPlainText('   \n  '), isNull);
      },
    );

    test('Enhanced LRC parses word-by-word timing tags and clean text', () {
      final parsed = Lyrics.fromJson(
        _sheet(
          lines: [
            {
              'start': 51690,
              'value':
                  '<00:51.69>Again <00:52.03>I <00:52.36>see <00:52.88>you <00:53.15>standing <00:53.79>there <00:54.83>watching <00:55.43>me<00:56.44>',
            },
          ],
        ),
      );

      expect(parsed.synced, isTrue);
      expect(parsed.lines.length, 1);
      final line = parsed.lines.first;
      expect(line.text, 'Again I see you standing there watching me');
      expect(line.start, const Duration(milliseconds: 51690));
      expect(line.hasWordTimings, isTrue);
      expect(line.words.length, 8);
      expect(line.words[0].text, 'Again ');
      expect(line.words[0].start, const Duration(milliseconds: 51690));
      expect(line.words[1].text, 'I ');
      expect(line.words[1].start, const Duration(milliseconds: 52030));
      expect(line.words[7].text, 'me');
      expect(line.words[7].start, const Duration(milliseconds: 55430));
    });

    test(
      'Enhanced LRC from raw LRC string parses line and word timestamps',
      () {
        const lrc = '''
[00:12.50]<00:12.50>I <00:12.80>see <00:13.10>trees <00:13.40>of <00:13.70>green, <00:14.20>red <00:14.50>roses <00:14.90>too.
[00:16.00]I see them bloom for me and you
''';
        final lyrics = Lyrics.fromLrcText(lrc);
        expect(lyrics, isNotNull);
        expect(lyrics!.synced, isTrue);
        expect(lyrics.lines.length, 2);

        // Line 1 has word timings
        expect(lyrics.lines[0].text, 'I see trees of green, red roses too.');
        expect(lyrics.lines[0].start, const Duration(milliseconds: 12500));
        expect(lyrics.lines[0].hasWordTimings, isTrue);
        expect(lyrics.lines[0].words.length, 8);
        expect(lyrics.lines[0].words[0].text, 'I ');
        expect(
          lyrics.lines[0].words[0].start,
          const Duration(milliseconds: 12500),
        );
        expect(lyrics.lines[0].words[1].text, 'see ');
        expect(
          lyrics.lines[0].words[1].start,
          const Duration(milliseconds: 12800),
        );

        // Line 2 has line timing only
        expect(lyrics.lines[1].text, 'I see them bloom for me and you');
        expect(lyrics.lines[1].start, const Duration(milliseconds: 16000));
        expect(lyrics.lines[1].hasWordTimings, isFalse);
      },
    );

    test('Stray XML and HTML tags are cleanly stripped from display text', () {
      final parsed = Lyrics.fromJson(
        _sheet(
          lines: [
            {
              'start': 1000,
              'value': '<b>Lead:</b> <00:01.00>Never <i>give</i> up',
            },
          ],
        ),
      );
      expect(parsed.lines.first.text, 'Lead: Never give up');
    });
  });
}
