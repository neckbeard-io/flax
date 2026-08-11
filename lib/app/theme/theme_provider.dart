import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/domain/enums.dart';

final themeModeProvider = StateProvider<ThemeModeSetting>(
  (ref) => ThemeModeSetting.system,
);

final amoledProvider = StateProvider<bool>((ref) => false);

ThemeMode resolveThemeMode(ThemeModeSetting setting) {
  return switch (setting) {
    ThemeModeSetting.system => ThemeMode.system,
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
  };
}
