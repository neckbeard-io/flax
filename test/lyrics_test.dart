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
  });
}
