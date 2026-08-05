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

  group('flag support', () {
    test('recognises the codes a flag can be drawn for', () {
      // CountryFlagIcon keys off the same map, so anything named has an asset.
      for (final code in ['NO', 'NL', 'GB', 'US', 'CA', 'DE', 'JP', 'BR']) {
        expect(countryName(code), isNotNull, reason: '$code should be known');
      }
    });

    test('does not claim support for non-countries', () {
      // Emoji flags were dropped because Windows renders a regional indicator
      // pair as the two letters rather than a flag; flags are now bundled SVGs
      // keyed off these codes, so an unknown code must fall back to an icon
      // rather than request a missing asset.
      expect(countryName('ZZ'), isNull);
      expect(countryName('Bergen'), isNull);
      expect(countryName(''), isNull);
    });
  });
}
