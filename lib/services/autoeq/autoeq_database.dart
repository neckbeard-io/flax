import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'autoeq_profile.dart';

/// Manages the local AutoEQ database: download, extract, index, search.
///
/// Data flow:
/// 1. Fetch version.json from AutoEqPackages to get archive URL
/// 2. Download archive.tar.gz (~100 MB)
/// 3. Extract and parse index.json (name/source/rank/id per profile)
/// 4. Store each profile's GraphicEQ curve on disk as `data/<id>.txt`
/// 5. Search and load on demand
///
/// The archive lays profiles out as `<headphone>/<source>/graphic.txt`, so the
/// filename alone does not identify a profile — every one of the ~8850 curves is
/// called `graphic.txt`. They are rekeyed to the index's id on extraction.
class AutoEqDatabase {
  static const _versionUrl =
      'https://raw.githubusercontent.com/ThePBone/AutoEqPackages/main/version.json';

  /// Bumped when the on-disk layout changes, so a stale cache is treated as
  /// absent and re-downloaded rather than silently misread.
  ///
  /// v1 extracted every profile with `p.basename()`, which collapsed all 8850
  /// `graphic.txt` files onto a single filename — the cache ended up holding
  /// one arbitrary curve, no profile could be loaded, and AutoEQ silently did
  /// nothing. Any v1 cache must be discarded.
  static const _cacheVersion = 2;

  /// Key for the (headphone, source) pair that identifies a profile. Separated
  /// by NUL, which cannot occur in a path segment - a space or slash would
  /// collide with the many headphone names that already contain one.
  static String _profileKey(String name, String source) => '$name\u0000$source';

  final Dio _dio;
  Directory? _cacheDir;
  List<AutoEqProfile>? _index;
  bool _downloading = false;

  /// [cacheDirOverride] bypasses path_provider so the download-and-extract path
  /// can be exercised in a test, which is otherwise only reachable by hand.
  AutoEqDatabase({Dio? dio, Directory? cacheDirOverride})
    : _dio = dio ?? Dio(),
      _cacheDir = cacheDirOverride;

  /// The local cache directory for the AutoEQ database.
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) {
      if (!_cacheDir!.existsSync()) _cacheDir!.createSync(recursive: true);
      return _cacheDir!;
    }
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory(p.join(appDir.path, 'autoeq'));
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
    return _cacheDir!;
  }

  /// Whether a usable database has been downloaded and indexed.
  ///
  /// Requires the cache to have been written by the current extraction layout.
  /// A v1 cache has an index but no loadable curves, and reporting it as
  /// available is what let AutoEQ look installed while doing nothing.
  Future<bool> get isAvailable async {
    final dir = await cacheDir;
    if (!File(p.join(dir.path, 'index.json')).existsSync()) return false;
    final meta = await getMeta();
    return (meta?['cacheVersion'] as int?) == _cacheVersion;
  }

  /// Number of profiles in the database, or 0 if not loaded.
  int get profileCount => _index?.length ?? 0;

  /// Whether a download is currently in progress.
  bool get isDownloading => _downloading;

  /// Download and extract the AutoEQ database.
  ///
  /// Yields human-readable phase strings, which the settings screen shows
  /// directly. [onProgress] carries the byte counts the phase strings cannot —
  /// this is a ~100 MB transfer, and reporting it as prose was issue #43's
  /// motivating example. [cancelToken] lets the task framework tear the
  /// transfer down; a cancelled download surfaces as a `DioException` the
  /// caller is expected to recognise.
  Stream<String> downloadDatabase({
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async* {
    if (_downloading) return;
    _downloading = true;

    try {
      yield 'Fetching version info...';
      final versionResp = await _dio.get<String>(
        _versionUrl,
        cancelToken: cancelToken,
      );
      final versionData = jsonDecode(versionResp.data!) as List;
      final packageUrl = versionData[0]['package_url'] as String;
      final commitTime = versionData[0]['commit_time'] as String;

      final dir = await cacheDir;
      final archivePath = p.join(dir.path, 'archive.tar.gz');
      final tarPath = p.join(dir.path, 'archive.tar');

      yield 'Downloading database...';
      await _dio.download(
        packageUrl,
        archivePath,
        cancelToken: cancelToken,
        // total is -1 when the server sends no Content-Length. Passing that
        // through unchanged would make the bar determinate against a negative
        // total; the task layer treats a non-positive total as "unknown".
        onReceiveProgress: onProgress,
        options: Options(followRedirects: true, maxRedirects: 5),
      );

      // Stream decompress .tar.gz to .tar on disk to keep memory bounded to < 1 MB.
      yield 'Decompressing archive...';
      final inGzStream = File(archivePath).openRead();
      final outTarSink = File(tarPath).openWrite();
      try {
        await inGzStream.transform(gzip.decoder).pipe(outTarSink);
      } finally {
        await outTarSink.close();
      }

      // Remove the .tar.gz immediately to free disk space
      try {
        File(archivePath).deleteSync();
      } catch (_) {}

      final dataDir = Directory(p.join(dir.path, 'data'));
      if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);
      dataDir.createSync(recursive: true);

      // Pass 1: Stream archive.tar to locate and parse index.json without keeping
      // all files in memory.
      // Archive member names are always POSIX paths, so they must be parsed
      // with p.posix rather than the platform context — p.split on Windows
      // would not treat "/" the same way.
      yield 'Parsing index...';
      String? indexContent;
      final pass1Stream = InputFileStream(tarPath);
      try {
        final decoder = TarDecoder();
        decoder.decodeStream(
          pass1Stream,
          callback: (file) {
            if (p.posix.basename(file.name) == 'index.json') {
              indexContent = utf8.decode(file.content as List<int>);
            }
            file.clear();
          },
        );
      } finally {
        pass1Stream.closeSync();
      }

      if (indexContent == null) {
        throw Exception(
          'AutoEQ archive contains no index.json — cannot identify profiles',
        );
      }

      final profiles = <AutoEqProfile>[];
      // A list per key, not a single id: the upstream index contains at least
      // one (headphone, source) pair listed twice under different ids, and both
      // must end up with the curve or selecting one of them silently corrects
      // nothing.
      final idsFor = <String, List<int>>{};
      for (final entry in jsonDecode(indexContent!) as List) {
        final name = entry['n'] as String;
        final source = entry['s'] as String;
        final id = entry['i'] as int;
        profiles.add(
          AutoEqProfile(
            id: id,
            name: name,
            source: source,
            rank: (entry['r'] as int?) ?? 0,
          ),
        );
        idsFor.putIfAbsent(_profileKey(name, source), () => <int>[]).add(id);
      }

      // Pass 2: Stream archive.tar to extract graphic.txt curves directly to disk,
      // discarding file buffers immediately after writing each curve.
      yield 'Extracting ${profiles.length} profiles...';
      var written = 0;
      var unmatched = 0;
      final pass2Stream = InputFileStream(tarPath);
      try {
        final decoder = TarDecoder();
        decoder.decodeStream(
          pass2Stream,
          callback: (file) {
            if (!file.isFile) {
              file.clear();
              return;
            }
            // raw.csv is the unsmoothed measurement; only the GraphicEQ curve is
            // used, and skipping the rest roughly halves what is written to disk.
            if (p.posix.basename(file.name) != 'graphic.txt') {
              file.clear();
              return;
            }

            final segments = p.posix.split(file.name);
            if (segments.length < 3) {
              unmatched++;
              file.clear();
              return;
            }
            final source = segments[segments.length - 2];
            final headphone = segments[segments.length - 3];
            final ids = idsFor[_profileKey(headphone, source)];
            if (ids == null) {
              unmatched++;
              file.clear();
              return;
            }
            final content = file.content as List<int>;
            for (final id in ids) {
              File(p.join(dataDir.path, '$id.txt')).writeAsBytesSync(content);
              written++;
            }
            file.clear();
          },
        );
      } finally {
        pass2Stream.closeSync();
      }

      if (written == 0) {
        throw Exception(
          'AutoEQ archive layout not recognised — extracted 0 of '
          '${profiles.length} profiles',
        );
      }

      // Clean up temporary .tar archive
      try {
        File(tarPath).deleteSync();
      } catch (_) {}

      // Sort by name
      profiles.sort((a, b) => a.name.compareTo(b.name));

      // Save our own index
      final indexJson = jsonEncode(profiles.map((p) => p.toJson()).toList());
      File(p.join(dir.path, 'index.json')).writeAsStringSync(indexJson);

      // Save metadata. cacheVersion gates isAvailable, so an older cache is
      // re-downloaded instead of being read with the wrong layout.
      final meta = {
        'commitTime': commitTime,
        'profileCount': profiles.length,
        'curveCount': written,
        'cacheVersion': _cacheVersion,
      };
      File(p.join(dir.path, 'meta.json')).writeAsStringSync(jsonEncode(meta));

      if (unmatched > 0) {
        yield '$written curves extracted ($unmatched unmatched)';
      }

      _index = profiles;
      yield 'Done! ${profiles.length} profiles available.';
    } catch (e) {
      // Clean up temporary archive files on failure
      try {
        final dir = await cacheDir;
        final gzFile = File(p.join(dir.path, 'archive.tar.gz'));
        if (gzFile.existsSync()) gzFile.deleteSync();
        final tarFile = File(p.join(dir.path, 'archive.tar'));
        if (tarFile.existsSync()) tarFile.deleteSync();
      } catch (_) {}
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
    _index = data
        .map((e) => AutoEqProfile.fromJson(e as Map<String, dynamic>))
        .toList();
    return _index!;
  }

  /// Search profiles by query string (case-insensitive substring match).
  Future<List<AutoEqProfile>> search(String query) async {
    final index = await loadIndex();
    if (query.isEmpty) return index;

    final lower = query.toLowerCase();
    return index.where((p) => p.name.toLowerCase().contains(lower)).toList();
  }

  /// Load the GraphicEQ curve for a specific profile.
  ///
  /// Returns null when the curve is missing, which callers must treat as a
  /// failure rather than falling back to the profile unchanged — a profile with
  /// no curve applies no correction, and doing that silently is what made a
  /// broken cache look like a working one.
  Future<AutoEqProfile?> loadProfile(AutoEqProfile profile) async {
    final dir = await cacheDir;
    final file = File(p.join(dir.path, 'data', '${profile.id}.txt'));
    if (!file.existsSync()) return null;

    final raw = file.readAsStringSync().trim();
    if (raw.isEmpty) return null;
    profile.rawGraphicEq = raw;
    // A curve that parses to nothing is no more useful than a missing file.
    return profile.points.isEmpty ? null : profile;
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
