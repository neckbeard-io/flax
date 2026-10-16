import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/features/settings/android_auto_screen.dart';
import 'package:flax/features/settings/android_auto_settings.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Android Auto tabs setting', () {
    test('defaults to what the car showed before: four tabs', () async {
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      expect(await tabs.loaded, [
        AutoTab.recentlyAdded,
        AutoTab.artists,
        AutoTab.albums,
        AutoTab.playlists,
      ]);
    });

    test('loaded waits for the saved choice', () async {
      SharedPreferences.setMockInitialValues({
        AndroidAutoTabsNotifier.storageKey: ['favorites', 'albums'],
      });
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      // Before the read finishes, the default is all there is.
      List<AutoTab>? before;
      tabs.addListener((s) => before ??= s);
      expect(before, AndroidAutoTabsNotifier.defaultTabs);
      expect(await tabs.loaded, [AutoTab.albums, AutoTab.favorites]);
    });

    test('a choice is saved and read back in the fixed order', () async {
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      await tabs.loaded;
      await tabs.setSelected(AutoTab.recentlyAdded, false);
      await tabs.setSelected(AutoTab.favorites, true);

      final reread = AndroidAutoTabsNotifier();
      addTearDown(reread.dispose);
      expect(await reread.loaded, [
        AutoTab.artists,
        AutoTab.albums,
        AutoTab.playlists,
        AutoTab.favorites,
      ]);
    });

    test('a fifth tab cannot be added', () async {
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      await tabs.loaded;
      expect(tabs.canSet(AutoTab.favorites, true), isFalse);
      await tabs.setSelected(AutoTab.favorites, true);
      expect(await tabs.loaded, AndroidAutoTabsNotifier.defaultTabs);
    });

    test('the last tab cannot be removed', () async {
      SharedPreferences.setMockInitialValues({
        AndroidAutoTabsNotifier.storageKey: ['artists'],
      });
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      await tabs.loaded;
      expect(tabs.canSet(AutoTab.artists, false), isFalse);
      await tabs.setSelected(AutoTab.artists, false);
      expect(await tabs.loaded, [AutoTab.artists]);
    });

    test('a saved list of more than four is cut to four', () async {
      SharedPreferences.setMockInitialValues({
        AndroidAutoTabsNotifier.storageKey: [
          'favorites',
          'playlists',
          'albums',
          'artists',
          'recentlyAdded',
          'unknown',
        ],
      });
      final tabs = AndroidAutoTabsNotifier();
      addTearDown(tabs.dispose);
      expect(await tabs.loaded, AndroidAutoTabsNotifier.defaultTabs);
    });
  });

  group('Android Auto settings page on a phone', () {
    Future<ProviderContainer> pumpPage(
      WidgetTester tester, {
      Locale? locale,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AndroidAutoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    CheckboxListTile box(WidgetTester tester, AutoTab tab) =>
        tester.widget<CheckboxListTile>(
          find.byKey(ValueKey('androidAutoTab-${tab.name}')),
        );

    testWidgets('with four chosen, the fifth box is disabled', (tester) async {
      final container = await pumpPage(tester);

      expect(box(tester, AutoTab.favorites).value, isFalse);
      expect(box(tester, AutoTab.favorites).onChanged, isNull);

      await tester.tap(find.byKey(const ValueKey('androidAutoTab-favorites')));
      await tester.pumpAndSettle();
      expect(container.read(androidAutoTabsProvider), hasLength(4));

      // Freeing a slot enables it.
      await tester.tap(find.byKey(const ValueKey('androidAutoTab-albums')));
      await tester.pumpAndSettle();
      expect(box(tester, AutoTab.favorites).onChanged, isNotNull);
      await tester.tap(find.byKey(const ValueKey('androidAutoTab-favorites')));
      await tester.pumpAndSettle();
      expect(container.read(androidAutoTabsProvider), [
        AutoTab.recentlyAdded,
        AutoTab.artists,
        AutoTab.playlists,
        AutoTab.favorites,
      ]);
    });

    testWidgets('the last chosen box cannot be cleared', (tester) async {
      SharedPreferences.setMockInitialValues({
        AndroidAutoTabsNotifier.storageKey: ['albums'],
      });
      final container = await pumpPage(tester);

      expect(box(tester, AutoTab.albums).value, isTrue);
      expect(box(tester, AutoTab.albums).onChanged, isNull);
      await tester.tap(find.byKey(const ValueKey('androidAutoTab-albums')));
      await tester.pumpAndSettle();
      expect(container.read(androidAutoTabsProvider), [AutoTab.albums]);
    });

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('fits in ${locale.languageCode}', (tester) async {
        await pumpPage(tester, locale: locale);
        expect(tester.takeException(), isNull);
        for (final tab in AutoTab.values) {
          final rect = tester.getRect(
            find.byKey(ValueKey('androidAutoTab-${tab.name}')),
          );
          expect(rect.right, lessThanOrEqualTo(390));
        }
      });
    }
  });

  group('Android Auto tile in Settings', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      PlatformOfflinePolicy policy, {
      Locale? locale,
    }) async {
      PackageInfo.setMockInitialValues(
        appName: 'Flax',
        packageName: 'io.neckbeard.flax',
        version: '0.5.1',
        buildNumber: '140',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [platformOfflinePolicyProvider.overrideWithValue(policy)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on Android, listing the chosen tabs', (
      tester,
    ) async {
      await pumpSettings(tester, const AndroidOfflinePolicy());
      await tester.scrollUntilVisible(
        find.text('Android Auto'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Android Auto'), findsOneWidget);
      expect(
        find.text('Recently Added · Artists · Albums · Playlists'),
        findsOneWidget,
      );
    });

    testWidgets('fits a phone in German', (tester) async {
      await pumpSettings(
        tester,
        const AndroidOfflinePolicy(),
        locale: const Locale('de'),
      );
      await tester.scrollUntilVisible(
        find.text('Zuletzt hinzugefügt · Künstler · Alben · Wiedergabelisten'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('is not offered on desktop', (tester) async {
      await pumpSettings(tester, const MacOsOfflinePolicy());
      // Past where the tile would be, so a lazily built list can't hide it.
      await tester.scrollUntilVisible(
        find.text('Audio & Playback'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Android Auto'), findsNothing);
    });
  });
}
