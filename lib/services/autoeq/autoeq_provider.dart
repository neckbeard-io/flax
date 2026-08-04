import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'autoeq_database.dart';
import 'autoeq_profile.dart';

/// Singleton database instance.
final autoEqDatabaseProvider = Provider<AutoEqDatabase>((ref) {
  return AutoEqDatabase();
});

/// State for the AutoEQ feature.
class AutoEqState {
  final bool dbAvailable;
  final bool downloading;
  final String? downloadStatus;
  final AutoEqProfile? activeProfile;
  final List<AutoEqProfile> searchResults;
  final String searchQuery;
  final bool loading;
  final String? error;
  final bool updateAvailable;
  final bool checking;
  final String? dbDate;

  const AutoEqState({
    this.dbAvailable = false,
    this.downloading = false,
    this.downloadStatus,
    this.activeProfile,
    this.searchResults = const [],
    this.searchQuery = '',
    this.loading = false,
    this.error,
    this.updateAvailable = false,
    this.checking = false,
    this.dbDate,
  });

  AutoEqState copyWith({
    bool? dbAvailable,
    bool? downloading,
    String? downloadStatus,
    AutoEqProfile? activeProfile,
    bool clearActiveProfile = false,
    List<AutoEqProfile>? searchResults,
    String? searchQuery,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? updateAvailable,
    bool? checking,
    String? dbDate,
  }) {
    return AutoEqState(
      dbAvailable: dbAvailable ?? this.dbAvailable,
      downloading: downloading ?? this.downloading,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      activeProfile: clearActiveProfile ? null : (activeProfile ?? this.activeProfile),
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      updateAvailable: updateAvailable ?? this.updateAvailable,
      checking: checking ?? this.checking,
      dbDate: dbDate ?? this.dbDate,
    );
  }
}

final autoEqProvider =
    StateNotifierProvider<AutoEqNotifier, AutoEqState>((ref) {
  return AutoEqNotifier(ref.read(autoEqDatabaseProvider));
});

class AutoEqNotifier extends StateNotifier<AutoEqState> {
  static const _storageKey = 'flax_autoeq_profile';

  final AutoEqDatabase _db;

  AutoEqNotifier(this._db) : super(const AutoEqState()) {
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await _db.isAvailable;
    if (!mounted) return;
    String? dbDate;
    if (available) {
      final meta = await _db.getMeta();
      dbDate = meta?['commitTime'] as String?;
    }
    if (mounted) {
      state = state.copyWith(dbAvailable: available, dbDate: dbDate);
    }
    if (available) {
      await _restoreProfile();
    }
  }

  /// Restore the previously selected profile (and its GraphicEQ data).
  Future<void> _restoreProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final saved = AutoEqProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final loaded = await _db.loadProfile(saved);
      if (mounted && loaded != null) {
        state = state.copyWith(activeProfile: loaded);
      }
    } catch (_) {
      // Corrupt prefs or missing profile file — leave unset
    }
  }

  Future<void> _saveProfile(AutoEqProfile? profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(profile.toJson()));
      }
    } catch (_) {
      // Ignore write failures
    }
  }

  /// Download the full AutoEQ database.
  Future<void> downloadDatabase() async {
    if (state.downloading) return;
    state = state.copyWith(downloading: true, clearError: true);

    try {
      await for (final status in _db.downloadDatabase()) {
        if (mounted) {
          state = state.copyWith(downloadStatus: status);
        }
      }
      if (mounted) {
        final meta = await _db.getMeta();
        state = state.copyWith(
          downloading: false,
          dbAvailable: true,
          updateAvailable: false,
          dbDate: meta?['commitTime'] as String?,
          downloadStatus: 'Database ready (${_db.profileCount} profiles)',
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          downloading: false,
          error: e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        );
      }
    }
  }

  /// Search for headphone profiles.
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, loading: true, clearError: true);
    try {
      final results = await _db.search(query);
      if (mounted) {
        state = state.copyWith(searchResults: results, loading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Select and activate a profile.
  Future<void> selectProfile(AutoEqProfile profile) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final loaded = await _db.loadProfile(profile);
      if (loaded == null) {
        // Do not activate a profile whose curve could not be loaded: it would
        // display as active while correcting nothing.
        if (mounted) {
          state = state.copyWith(
            loading: false,
            error: 'No correction curve for "${profile.name}". '
                'Re-download the AutoEQ database.',
          );
        }
        return;
      }
      if (mounted) {
        state = state.copyWith(activeProfile: loaded, loading: false);
      }
      await _saveProfile(loaded);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          error: 'Failed to load profile: $e',
        );
      }
    }
  }

  /// Clear the active profile.
  void clearProfile() {
    state = state.copyWith(clearActiveProfile: true);
    _saveProfile(null);
  }

  /// Check if a newer database version is available upstream.
  Future<void> checkForUpdate() async {
    state = state.copyWith(checking: true, clearError: true, updateAvailable: false);
    try {
      final result = await _db.checkForUpdate();
      if (mounted) {
        state = state.copyWith(
          checking: false,
          updateAvailable: result.available,
          downloadStatus: result.available
              ? 'Update available (${result.remoteTime})'
              : 'Database is up to date (${result.localTime})',
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          checking: false,
          error: 'Failed to check: ${e.toString().replaceFirst(RegExp(r"^Exception:\s*"), "")}',
        );
      }
    }
  }

  /// Delete the local database and reset state.
  Future<void> deleteDatabase() async {
    await _db.deleteDatabase();
    await _saveProfile(null);
    if (mounted) {
      state = const AutoEqState();
    }
  }
}
