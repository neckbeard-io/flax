import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/router.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/app_chrome.dart';

class FlaxApp extends ConsumerStatefulWidget {
  const FlaxApp({super.key});

  @override
  ConsumerState<FlaxApp> createState() => _FlaxAppState();
}

class _FlaxAppState extends ConsumerState<FlaxApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.scheduleWarmUpFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeModeSetting = ref.watch(themeModeProvider);
    final amoled = ref.watch(amoledProvider);
    final customDynamic = ref.watch(dynamicColorSchemesProvider);
    final selectedLocale = ref.watch(localeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = customDynamic?.light ?? lightDynamic;
        final darkScheme = customDynamic?.dark ?? darkDynamic;

        return MaterialApp.router(
          title: 'Flax',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: selectedLocale,
          theme: FlaxTheme.light(dynamicScheme: lightScheme),
          darkTheme: FlaxTheme.dark(dynamicScheme: darkScheme, amoled: amoled),
          themeMode: resolveThemeMode(themeModeSetting),
          routerConfig: router,
          builder: (context, child) =>
              AppChrome(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
