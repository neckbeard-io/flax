import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'autoeq_profile.dart';

/// Manages the local AutoEQ database: download, extract, index, search.
///
/// Data flow:
/// 1. Fetch version.json from AutoEqPackages to get archive URL
/// 2. Download archive.tar.gz (~5-10 MB)
/// 3. Extract and parse index.json (name/source/rank/id per profile)
/// 4. Store GraphicEQ .txt files on disk, keyed by id
/// 5. Search and load on demand
class AutoEqDatabase {
  static const _versionUrl =
      'https://raw.githubusercontent.com/ThePBone/AutoEqPackages/main/version.json';

  final Dio _dio;
  Directory? _cacheDir;
  List<AutoEqProfile>? _index;
  bool _downloading = false;

  AutoEqDatabase({Dio? dio}) : _dio = dio ?? Dio();

  /// The local cache directory for the AutoEQ database.
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory(p.join(appDir.path, 'autoeq'));
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
    return _cacheDir!;
  }

  /// Whether the database has been downloaded and indexed.
  Future<bool> get isAvailable async {
    final dir = await cacheDir;
    final indexFile = File(p.join(dir.path, 'index.json'));
    return indexFile.existsSync();
  }

  /// Number of profiles in the database, or 0 if not loaded.
  int get profileCount => _index?.length ?? 0;

  /// Whether a download is currently in progress.
  bool get isDownloading => _downloading;

  /// Download and extract the AutoEQ database.
  /// Returns a stream of progress strings for UI updates.
  Stream<String> downloadDatabase() async* {
    if (_downloading) return;
    _downloading = true;

    try {
      yield 'Fetching version info...';
      final versionResp = await _dio.get<String>(_versionUrl);
      final versionData = jsonDecode(versionResp.data!) as List;
      final packageUrl = versionData[0]['package_url'] as String;
      final commitTime = versionData[0]['commit_time'] as String;

      final dir = await cacheDir;
      final archivePath = p.join(dir.path, 'archive.tar.gz');

      yield 'Downloading database...';
      await _dio.download(
        packageUrl,
        archivePath,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      yield 'Extracting profiles...';
      final archiveBytes = File(archivePath).readAsBytesSync();
      final gzDecoded = GZipDecoder().decodeBytes(archiveBytes);
      final tarArchive = TarDecoder().decodeBytes(gzDecoded);

      // Parse and store
      final profiles = <AutoEqProfile>[];
      final dataDir = Directory(p.join(dir.path, 'data'));
      if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);
      dataDir.createSync(recursive: true);

      int fileCount = 0;
      String? indexContent;

      for (final file in tarArchive) {
        if (file.isFile) {
          final name = file.name;
          if (name.endsWith('index.json')) {
            indexContent = utf8.decode(file.content as List<int>);
          } else if (name.endsWith('.txt')) {
            // Store GraphicEQ txt files
            final outPath = p.join(dataDir.path, p.basename(name));
            File(outPath).writeAsBytesSync(file.content as List<int>);
            fileCount++;
          }
        }
      }

      yield 'Indexing $fileCount profiles...';

      if (indexContent != null) {
        // Parse the index.json from the archive
        final indexData = jsonDecode(indexContent) as List;
        for (final entry in indexData) {
          profiles.add(AutoEqProfile(
            id: entry['i'] as int,
            name: entry['n'] as String,
            source: entry['s'] as String,
            rank: (entry['r'] as int?) ?? 0,
          ));
        }
      } else {
        // Fallback: build index from extracted files
        yield 'Building index from files...';
        int id = 0;
        for (final entity in dataDir.listSync()) {
          if (entity is File && entity.path.endsWith('.txt')) {
            final fileName = p.basenameWithoutExtension(entity.path);
            profiles.add(AutoEqProfile(
              id: id++,
              name: fileName,
              source: 'AutoEQ',
            ));
          }
        }
      }

      // Sort by name
      profiles.sort((a, b) => a.name.compareTo(b.name));

      // Save our own index
      final indexJson = jsonEncode(profiles.map((p) => p.toJson()).toList());
      File(p.join(dir.path, 'index.json')).writeAsStringSync(indexJson);

      // Save metadata
      final meta = {'commitTime': commitTime, 'profileCount': profiles.length};
      File(p.join(dir.path, 'meta.json')).writeAsStringSync(jsonEncode(meta));

      // Clean up archive
      File(archivePath).deleteSync();

      _index = profiles;
      yield 'Done! ${profiles.length} profiles available.';
    } catch (e) {
      yield 'Error: $e';
      rethrow;
    } finally {
      _downloading = false;
    }
  }

  /// Load the index from cache (fast — no network).
  Future<List<AutoEqProfile>> loadIndex() async {
    if (_index != null) return _index!;

    final dir = await cacheDir;
    final indexFile = File(p.join(dir.path, 'index.json'));
    if (!indexFile.existsSync()) return [];

    final data = jsonDecode(indexFile.readAsStringSync()) as List;
    _index = data.map((e) => AutoEqProfile.fromJson(e as Map<String, dynamic>)).toList();
    return _index!;
  }

  /// Search profiles by query string (case-insensitive substring match).
  Future<List<AutoEqProfile>> search(String query) async {
    final index = await loadIndex();
    if (query.isEmpty) return index;

    final lower = query.toLowerCase();
    return index.where((p) => p.name.toLowerCase().contains(lower)).toList();
  }

  /// Load the GraphicEQ data for a specific profile.
  Future<AutoEqProfile?> loadProfile(AutoEqProfile profile) async {
    final dir = await cacheDir;
    final dataDir = Directory(p.join(dir.path, 'data'));

    // Try to find the file by id
    final idFile = File(p.join(dataDir.path, '${profile.id}.txt'));
    if (idFile.existsSync()) {
      profile.rawGraphicEq = idFile.readAsStringSync().trim();
      return profile;
    }

    // Try by name
    final nameFile = File(p.join(dataDir.path, '${profile.name}.txt'));
    if (nameFile.existsSync()) {
      profile.rawGraphicEq = nameFile.readAsStringSync().trim();
      return profile;
    }

    // Search data directory for a matching file
    if (dataDir.existsSync()) {
      for (final entity in dataDir.listSync()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final basename = p.basenameWithoutExtension(entity.path);
          if (basename == profile.id.toString() ||
              basename.toLowerCase() == profile.name.toLowerCase()) {
            profile.rawGraphicEq = entity.readAsStringSync().trim();
            return profile;
          }
        }
      }
    }

    return null;
  }

  /// Get database metadata (commit time, profile count).
  Future<Map<String, dynamic>?> getMeta() async {
    final dir = await cacheDir;
    final metaFile = File(p.join(dir.path, 'meta.json'));
    if (!metaFile.existsSync()) return null;
    return jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Check if a newer database is available upstream.
  /// Returns (updateAvailable, remoteTime, localTime).
  Future<({bool available, String remoteTime, String localTime})>
      checkForUpdate() async {
    final meta = await getMeta();
    final localTime = (meta?['commitTime'] as String?) ?? '';

    final versionResp = await _dio.get<String>(_versionUrl);
    final versionData = jsonDecode(versionResp.data!) as List;
    final remoteTime = versionData[0]['commit_time'] as String;

    return (
      available: remoteTime != localTime,
      remoteTime: remoteTime,
      localTime: localTime,
    );
  }

  /// Delete the local database cache.
  Future<void> deleteDatabase() async {
    final dir = await cacheDir;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
    }
    _index = null;
  }
}
