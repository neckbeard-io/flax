import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to null when no preference is saved', () {
      final notifier = LocaleNotifier();
      expect(notifier.state, isNull);
    });

    test('saves and updates state when setting a locale', () async {
      final notifier = LocaleNotifier();
      await notifier.setLocale(const Locale('de'));
      expect(notifier.state, const Locale('de'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kSelectedLocaleKey), 'de');
    });

    test('clears preference when setting locale to null', () async {
      SharedPreferences.setMockInitialValues({kSelectedLocaleKey: 'fr'});
      final prefs = await SharedPreferences.getInstance();
      final loaded = LocaleNotifier.loadLocaleFromPrefs(prefs);
      expect(loaded, const Locale('fr'));

      final notifier = LocaleNotifier(loaded);
      await notifier.setLocale(null);
      expect(notifier.state, isNull);
      expect(prefs.getString(kSelectedLocaleKey), isNull);
    });
  });

  group('AppLocalizations Translations', () {
    test('provides accurate translations across supported locales', () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.appName, 'Flax');
        expect(l10n.connect.isNotEmpty, isTrue);
        expect(l10n.required.isNotEmpty, isTrue);
        expect(l10n.connectToMusicServer.isNotEmpty, isTrue);
      }
    });

    test(
      'formats plural track counts correctly in German and English',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        expect(en.trackCount(1), '1 track');
        expect(en.trackCount(12), '12 tracks');
        expect(en.albumCount(1), '1 album');
        expect(en.albumCount(3), '3 albums');

        final de = await AppLocalizations.delegate.load(const Locale('de'));
        expect(de.trackCount(1), '1 Titel');
        expect(de.trackCount(5), '5 Titel');
        expect(de.albumCount(1), '1 Album');
        expect(de.albumCount(2), '2 Alben');
      },
    );

    test('formats Japanese and Chinese translations correctly', () async {
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      expect(ja.connectToMusicServer, '音楽サーバーに接続');
      expect(ja.connect, '接続');
      expect(ja.trackCount(3), '3曲');

      final zh = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(zh.connectToMusicServer, '连接到您的音乐服务器');
      expect(zh.connect, '连接');
      expect(zh.trackCount(4), '4 首曲目');
    });

    // A key missing from a locale silently falls back to English there.
    test('every locale translates every message in the template', () {
      Set<String> messages(String locale) =>
          (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => !k.startsWith('@'))
              .toSet();

      final template = messages('en');
      for (final locale in AppLocalizations.supportedLocales) {
        final code = locale.languageCode;
        if (code == 'en') continue;
        expect(
          template.difference(messages(code)),
          isEmpty,
          reason: 'app_$code.arb is missing these',
        );
      }
    });
  });
}
