import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/logging/app_logger.dart';

/// Tracks whether the previously configured external storage volume was missing/unmounted
/// and fell back to internal storage.
final missingStorageWarningProvider = StateProvider<String?>((ref) => null);

/// Information about free and total space on a storage volume.
class DiskSpaceInfo {
  final int totalBytes;
  final int availableBytes;

  const DiskSpaceInfo({required this.totalBytes, required this.availableBytes});

  double get freeFraction =>
      totalBytes > 0 ? (availableBytes / totalBytes).clamp(0.0, 1.0) : 1.0;

  @override
  String toString() =>
      'DiskSpaceInfo(total: $totalBytes, available: $availableBytes)';
}

/// Represents a detected storage volume (e.g. Internal Storage, SD Card).
class StorageVolume {
  final String id;
  final String label;
  final String path;
  final bool isRemovable;
  final int totalBytes;
  final int availableBytes;

  const StorageVolume({
    required this.id,
    required this.label,
    required this.path,
    required this.isRemovable,
    this.totalBytes = 0,
    this.availableBytes = 0,
  });

  StorageVolume copyWith({
    String? id,
    String? label,
    String? path,
    bool? isRemovable,
    int? totalBytes,
    int? availableBytes,
  }) {
    return StorageVolume(
      id: id ?? this.id,
      label: label ?? this.label,
      path: path ?? this.path,
      isRemovable: isRemovable ?? this.isRemovable,
      totalBytes: totalBytes ?? this.totalBytes,
      availableBytes: availableBytes ?? this.availableBytes,
    );
  }
}

/// Service managing disk space queries, mobile storage devices, and cache migration.
class StorageManager {
  static const prefStoragePathKey = 'flax_audio_cache_custom_path';
  static const prefStorageVolumeIdKey = 'flax_audio_cache_volume_id';

  /// Minimum safety headroom in bytes to prevent host disk exhaustion (1.5 GB).
  static const int minSafetyBufferBytes = 1536 * 1024 * 1024;

  /// Minimum safety headroom ratio (10% of total volume space).
  static const double minSafetyBufferRatio = 0.10;

  /// Queries the available and total disk space for the volume containing [path].
  static DiskSpaceInfo? getDiskSpace(String path) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        final parent = dir.parent;
        if (parent.existsSync()) {
          return getDiskSpace(parent.path);
        }
      }

      if (Platform.isMacOS || Platform.isIOS) {
        final lib = DynamicLibrary.process();
        final statvfsFunc = lib
            .lookupFunction<
              Int32 Function(Pointer<Utf8>, Pointer<Uint8>),
              int Function(Pointer<Utf8>, Pointer<Uint8>)
            >('statvfs');

        final pathPtr = path.toNativeUtf8();
        final ptr = calloc<Uint8>(512);
        try {
          final res = statvfsFunc(pathPtr, ptr);
          if (res == 0) {
            final u64 = ptr.cast<Uint64>().asTypedList(2);
            final u32 = (ptr + 16).cast<Uint32>().asTypedList(3);
            final bsize = u64[0];
            final frsize = u64[1] > 0 ? u64[1] : bsize;
            final blocks = u32[0];
            final bavail = u32[2];
            final total = blocks * frsize;
            final avail = bavail * frsize;
            return DiskSpaceInfo(totalBytes: total, availableBytes: avail);
          }
        } finally {
          calloc.free(pathPtr);
          calloc.free(ptr);
        }
      } else if (Platform.isLinux || Platform.isAndroid) {
        DynamicLibrary lib;
        try {
          lib = DynamicLibrary.process();
        } catch (_) {
          try {
            lib = DynamicLibrary.open('libc.so.6');
          } catch (_) {
            lib = DynamicLibrary.open('libc.so');
          }
        }
        final statvfsFunc = lib
            .lookupFunction<
              Int32 Function(Pointer<Utf8>, Pointer<Uint8>),
              int Function(Pointer<Utf8>, Pointer<Uint8>)
            >('statvfs');

        final pathPtr = path.toNativeUtf8();
        final ptr = calloc<Uint8>(512);
        try {
          final res = statvfsFunc(pathPtr, ptr);
          if (res == 0) {
            final u64 = ptr.cast<Uint64>().asTypedList(5);
            final bsize = u64[0];
            final frsize = u64[1] > 0 ? u64[1] : bsize;
            final blocks = u64[2];
            final bavail = u64[4];
            final total = blocks * frsize;
            final avail = bavail * frsize;
            return DiskSpaceInfo(totalBytes: total, availableBytes: avail);
          }
        } finally {
          calloc.free(pathPtr);
          calloc.free(ptr);
        }
      }
    } catch (e) {
      AppLogger.w('Storage', 'Failed to query disk space for $path: $e');
    }
    return null;
  }

  /// Checks whether writing [additionalBytes] would violate the minimum disk safety buffer.
  static bool isDiskSpaceSafe(String path, {int additionalBytes = 0}) {
    final info = getDiskSpace(path);
    if (info == null) return true; // Fail-open if unsupported

    final dynamicHeadroom = (info.totalBytes * minSafetyBufferRatio).round();
    final requiredBuffer = dynamicHeadroom > minSafetyBufferBytes
        ? minSafetyBufferBytes
        : dynamicHeadroom;

    final projectedAvailable = info.availableBytes - additionalBytes;
    return projectedAvailable >= requiredBuffer;
  }

  /// Discovers all available storage volumes for caching.
  /// On Android, enumerates internal files and secondary SD cards.
  static Future<List<StorageVolume>> getAvailableStorageVolumes() async {
    final volumes = <StorageVolume>[];

    // 1. Standard App Support Directory (Internal)
    try {
      final appDir = await getApplicationSupportDirectory();
      final internalAudioCache = p.join(appDir.path, 'audio_cache');
      final diskInfo = getDiskSpace(appDir.path);
      volumes.add(
        StorageVolume(
          id: 'internal_app',
          label: 'Internal App Storage',
          path: internalAudioCache,
          isRemovable: false,
          totalBytes: diskInfo?.totalBytes ?? 0,
          availableBytes: diskInfo?.availableBytes ?? 0,
        ),
      );
    } catch (_) {}

    // 2. Android External / Removable Storage Directories
    if (Platform.isAndroid) {
      try {
        final externalDirs = await getExternalStorageDirectories(
          type: StorageDirectory.music,
        );
        if (externalDirs != null) {
          for (var i = 0; i < externalDirs.length; i++) {
            final dir = externalDirs[i];
            final audioCachePath = p.join(dir.path, 'flax_cache');
            final diskInfo = getDiskSpace(dir.path);
            final isPrimary = i == 0;
            final isRemovable =
                !isPrimary ||
                (dir.path.contains('/storage/') &&
                    !dir.path.contains('/emulated/'));

            // Extract a clean label (e.g. "SanDisk SD Card" or volume UUID)
            String label;
            if (isPrimary && dir.path.contains('/emulated/0')) {
              label = 'Primary Shared Storage';
            } else {
              final segments = p.split(dir.path);
              final storageIdx = segments.indexOf('storage');
              final volumeUuid =
                  (storageIdx != -1 && segments.length > storageIdx + 1)
                  ? segments[storageIdx + 1]
                  : 'SD Card ${i > 0 ? i : ""}';
              label = 'SD Card ($volumeUuid)';
            }

            volumes.add(
              StorageVolume(
                id: 'external_$i',
                label: label,
                path: audioCachePath,
                isRemovable: isRemovable,
                totalBytes: diskInfo?.totalBytes ?? 0,
                availableBytes: diskInfo?.availableBytes ?? 0,
              ),
            );
          }
        }
      } catch (e) {
        AppLogger.w(
          'Storage',
          'Error discovering external storage directories: $e',
        );
      }
    }

    return volumes;
  }

  /// Determines the active base path for the audio cache.
  static Future<String> resolveActiveCacheBasePath({
    void Function(String missingPath)? onMissingVolume,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(prefStoragePathKey);
      if (customPath != null && customPath.isNotEmpty) {
        final dir = Directory(customPath);
        if (dir.existsSync() || (await _canCreateDir(dir))) {
          return customPath;
        } else {
          onMissingVolume?.call(customPath);
        }
      }
    } catch (_) {}

    // Default fallback: internal app support directory
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'audio_cache');
  }

  static Future<bool> _canCreateDir(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final testFile = File(p.join(dir.path, '.flax_write_test'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Migrates all cache files from [sourcePath] to [targetPath].
  static Future<bool> migrateCacheDirectory({
    required String sourcePath,
    required String targetPath,
    void Function(double fraction, String status)? onProgress,
  }) async {
    final sourceDir = Directory(sourcePath);
    if (!sourceDir.existsSync()) return true;

    final targetDir = Directory(targetPath);
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    try {
      final allFiles = <File>[];
      for (final entity in sourceDir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) allFiles.add(entity);
      }

      final total = allFiles.length;
      var copied = 0;

      for (final file in allFiles) {
        final relPath = p.relative(file.path, from: sourcePath);
        final destFile = File(p.join(targetPath, relPath));
        final destDir = destFile.parent;
        if (!destDir.existsSync()) {
          destDir.createSync(recursive: true);
        }

        try {
          // Attempt fast atomic rename on same volume, fallback to copy
          file.renameSync(destFile.path);
        } catch (_) {
          file.copySync(destFile.path);
          file.deleteSync();
        }

        copied++;
        onProgress?.call(
          total > 0 ? copied / total : 1.0,
          'Migrating track $copied of $total...',
        );
      }

      // Cleanup remaining empty directories
      try {
        sourceDir.deleteSync(recursive: true);
      } catch (_) {}

      return true;
    } catch (e) {
      AppLogger.e('Storage', 'Cache migration failed: $e', error: e);
      return false;
    }
  }
}
