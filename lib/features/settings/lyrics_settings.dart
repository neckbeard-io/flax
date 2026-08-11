import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where lyric lines sit in their column.
enum LyricsAlignment {
  left('Left', TextAlign.left, CrossAxisAlignment.start),
  center('Center', TextAlign.center, CrossAxisAlignment.center);

  const LyricsAlignment(this.label, this.textAlign, this.crossAxisAlignment);

  final String label;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
}

/// How the lyrics panel is drawn.
///
/// One size setting, not two. The sung line is always larger than the rest —
/// that difference is what makes the sheet readable at a glance, so it is a
/// ratio applied to the chosen size rather than something to configure and get
/// wrong.
class LyricsSettings {
  /// Point size of the lines that are not currently being sung.
  final double fontSize;
  final LyricsAlignment alignment;

  const LyricsSettings({
    this.fontSize = defaultFontSize,
    this.alignment = LyricsAlignment.left,
  });

  static const double minFontSize = 11;
  static const double maxFontSize = 28;
  static const double defaultFontSize = 15;

  /// How much larger the sung line is than the rest.
  static const double activeScale = 1.25;

  double get activeFontSize => fontSize * activeScale;

  LyricsSettings copyWith({double? fontSize, LyricsAlignment? alignment}) =>
      LyricsSettings(
        fontSize: fontSize ?? this.fontSize,
        alignment: alignment ?? this.alignment,
      );

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'alignment': alignment.name,
  };

  factory LyricsSettings.fromJson(Map<String, dynamic> json) => LyricsSettings(
    fontSize:
        (json['fontSize'] as num?)?.toDouble().clamp(
          minFontSize,
          maxFontSize,
        ) ??
        defaultFontSize,
    alignment: LyricsAlignment.values.firstWhere(
      (a) => a.name == json['alignment'],
      orElse: () => LyricsAlignment.left,
    ),
  );
}

final lyricsSettingsProvider =
    StateNotifierProvider<LyricsSettingsNotifier, LyricsSettings>((ref) {
      return LyricsSettingsNotifier();
    });

class LyricsSettingsNotifier extends StateNotifier<LyricsSettings> {
  static const _storageKey = 'flax_lyrics_settings';

  LyricsSettingsNotifier() : super(const LyricsSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      state = LyricsSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt prefs — keep defaults.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore write failures.
    }
  }

  void setFontSize(double size) {
    state = state.copyWith(
      fontSize: size.clamp(
        LyricsSettings.minFontSize,
        LyricsSettings.maxFontSize,
      ),
    );
    _save();
  }

  void setAlignment(LyricsAlignment alignment) {
    state = state.copyWith(alignment: alignment);
    _save();
  }
}
