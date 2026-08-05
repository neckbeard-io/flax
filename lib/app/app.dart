import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/router.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/shared/widgets/app_chrome.dart';

class FlaxApp extends ConsumerWidget {
  const FlaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeSetting = ref.watch(themeModeProvider);
    final amoled = ref.watch(amoledProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: 'Flax',
          // Flutter pins its DEBUG ribbon to the top-right corner, which is
          // exactly where ShellScaffold puts the custom window buttons — the
          // ribbon covered the close button, making it unclickable in debug
          // builds. WindowButtons carries a DEBUG badge instead, and Settings ->
          // About names the build mode; both mark a debug build without
          // occupying the corner.
          debugShowCheckedModeBanner: false,
          theme: FlaxTheme.light(dynamicScheme: lightDynamic),
          darkTheme:
              FlaxTheme.dark(dynamicScheme: darkDynamic, amoled: amoled),
          themeMode: resolveThemeMode(themeModeSetting),
          routerConfig: router,
          // Wraps every route, so screens outside the shell — server setup,
          // now playing — get window controls and the global shortcut too.
          builder: (context, child) =>
              AppChrome(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
