import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

final serverListProvider =
    StateNotifierProvider<ServerListNotifier, List<Server>>((ref) {
      return ServerListNotifier();
    });

final activeServerProvider = Provider<Server?>((ref) {
  final servers = ref.watch(serverListProvider);
  try {
    return servers.firstWhere((s) => s.isActive);
  } catch (_) {
    return servers.isNotEmpty ? servers.first : null;
  }
});

final subsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null) return null;
  return SubsonicClient(server: server);
});

class ServerListNotifier extends StateNotifier<List<Server>> {
  static const storageKey = 'flax_servers';
  static const _uuid = Uuid();

  ServerListNotifier({List<Server>? initialServers})
    : super(initialServers ?? []) {
    if (initialServers == null) {
      _load();
    }
  }

  static List<Server> loadServersFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Server.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = loadServersFromPrefs(prefs);
    if (list.isNotEmpty) {
      state = list;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(state.map((s) => s.toJson()).toList()),
    );
  }

  Future<Server> addServer({
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    final server = Server(
      id: _uuid.v4(),
      name: name,
      url: url,
      username: username,
      tokenHash: password,
      salt: '',
      isActive: state.isEmpty,
    );

    // Test connection with descriptive error
    final client = SubsonicClient(server: server);
    final error = await client.tryPing();
    if (error != null) {
      throw Exception(error);
    }

    state = [...state, server];
    await _save();
    return server;
  }

  Future<void> removeServer(String id) async {
    final wasActive = state.any((s) => s.id == id && s.isActive);
    state = state.where((s) => s.id != id).toList();
    if (wasActive && state.isNotEmpty) {
      state = [state.first.copyWith(isActive: true), ...state.skip(1)];
    }
    await _save();
  }

  Future<void> setActiveServer(String id) async {
    state = state.map((s) => s.copyWith(isActive: s.id == id)).toList();
    await _save();
  }

  Future<void> updateServer(Server updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    await _save();
  }
}
