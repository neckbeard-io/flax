import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kSelectedLocaleKey = 'flax_selected_locale';

/// Metadata for a selectable language in the UI.
class LanguageOption {
  final String? code;
  final String name;
  final String nativeName;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  Locale? get locale => code != null ? Locale(code!) : null;
}

const List<LanguageOption> kSupportedLanguageOptions = [
  LanguageOption(
    code: null,
    name: 'System Default',
    nativeName: 'System Default',
  ),
  LanguageOption(code: 'en', name: 'English', nativeName: 'English'),
  LanguageOption(code: 'de', name: 'German', nativeName: 'Deutsch'),
  LanguageOption(code: 'fr', name: 'French', nativeName: 'Français'),
  LanguageOption(code: 'es', name: 'Spanish', nativeName: 'Español'),
  LanguageOption(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  LanguageOption(code: 'zh', name: 'Simplified Chinese', nativeName: '简体中文'),
];

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier([Locale? initialLocale]) : super(initialLocale) {
    if (initialLocale == null) {
      _loadFromPrefs();
    }
  }

  static Locale? loadLocaleFromPrefs(SharedPreferences prefs) {
    final code = prefs.getString(kSelectedLocaleKey);
    if (code != null && code.isNotEmpty) {
      return Locale(code);
    }
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = loadLocaleFromPrefs(prefs);
    } catch (_) {}
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(kSelectedLocaleKey);
      } else {
        await prefs.setString(kSelectedLocaleKey, locale.languageCode);
      }
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
