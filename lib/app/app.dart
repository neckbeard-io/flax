import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/router.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_provider.dart';

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
          debugShowCheckedModeBanner: false,
          theme: FlaxTheme.light(dynamicScheme: lightDynamic),
          darkTheme:
              FlaxTheme.dark(dynamicScheme: darkDynamic, amoled: amoled),
          themeMode: resolveThemeMode(themeModeSetting),
          routerConfig: router,
        );
      },
    );
  }
}
