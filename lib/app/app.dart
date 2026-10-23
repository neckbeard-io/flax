import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/router.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/app_chrome.dart';

class FlaxApp extends ConsumerWidget {
  const FlaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeSetting = ref.watch(themeModeProvider);
    final palette = ref.watch(themePaletteProvider);
    final amoled = ref.watch(amoledProvider);
    // valueOrNull keeps the last colors while the next ones load, so the
    // Album theme never blinks back to violet between songs.
    final device = ref.watch(platformColorSchemesProvider).valueOrNull;
    final album = ref.watch(albumColorSchemesProvider).valueOrNull;
    final selectedLocale = ref.watch(localeProvider);

    ColorScheme scheme(Brightness brightness) =>
        resolvePaletteScheme(palette, brightness, device: device, album: album);

    return MaterialApp.router(
      title: 'Flax',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: selectedLocale,
      theme: FlaxTheme.light(dynamicScheme: scheme(Brightness.light)),
      darkTheme: FlaxTheme.dark(
        dynamicScheme: scheme(Brightness.dark),
        amoled: amoled,
      ),
      themeMode: resolveThemeMode(themeModeSetting),
      routerConfig: router,
      builder: (context, child) =>
          AppChrome(child: child ?? const SizedBox.shrink()),
    );
  }
}
