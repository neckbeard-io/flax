import 'package:flutter_test/flutter_test.dart';
import 'package:flax/shared/country.dart';

void main() {
  group('countryName', () {
    test('resolves codes seen on real artists', () {
      expect(countryName('NO'), 'Norway');
      expect(countryName('NL'), 'Netherlands');
      expect(countryName('GB'), 'United Kingdom');
      expect(countryName('US'), 'United States');
    });

    test('is case-insensitive', () {
      expect(countryName('no'), 'Norway');
      expect(countryName('nO'), 'Norway');
    });

    test('returns null rather than guessing', () {
      expect(countryName(null), isNull);
      expect(countryName('ZZ'), isNull);
      // MusicBrainz occasionally holds an area name where a code is expected;
      // it must not be mistaken for one.
      expect(countryName('Bergen'), isNull);
      expect(countryName('N'), isNull);
    });
  });

  group('countryFlag', () {
    test('builds the flag from regional indicator symbols', () {
      // U+1F1F3 U+1F1F4 — what the platform draws as the Norwegian flag.
      expect(countryFlag('NO'), '\u{1F1F3}\u{1F1F4}');
      expect(countryFlag('NL'), '\u{1F1F3}\u{1F1F1}');
      expect(countryFlag('JP'), '\u{1F1EF}\u{1F1F5}');
    });

    test('every known country yields a two-symbol flag', () {
      for (final code in ['NO', 'NL', 'GB', 'US', 'DE', 'SE', 'FI', 'BR']) {
        final flag = countryFlag(code);
        expect(flag, isNotNull, reason: '$code should have a flag');
        expect(flag!.runes.length, 2, reason: '$code flag should be two runes');
        for (final r in flag.runes) {
          expect(r, greaterThanOrEqualTo(0x1F1E6));
          expect(r, lessThanOrEqualTo(0x1F1FF));
        }
      }
    });

    test('unknown or malformed codes give no flag', () {
      expect(countryFlag('ZZ'), isNull);
      expect(countryFlag(null), isNull);
      expect(countryFlag('Bergen'), isNull);
    });
  });
}
