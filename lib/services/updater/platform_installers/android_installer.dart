import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class AndroidInstaller {
  static const _channel = MethodChannel('com.flax/package_installer');
  static const _eventChannel = EventChannel(
    'com.flax/package_installer_events',
  );

  /// Downloads the APK using high-throughput native OkHttp over HTTP/2.
  static Future<String> downloadApk(
    String url,
    String destinationPath, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Native APK download only supported on Android');
    }

    final sub = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'progress') {
          final received = (event['received'] as num?)?.toInt() ?? 0;
          final total = (event['total'] as num?)?.toInt() ?? 0;
          onProgress(received, total);
        }
      }
    });

    void cancelListener() {
      _channel.invokeMethod('cancelDownload').ignore();
    }

    cancelToken?.whenCancel.then((_) => cancelListener());

    try {
      final path = await _channel.invokeMethod<String>('downloadApk', {
        'url': url,
        'destinationPath': destinationPath,
      });
      return path ?? destinationPath;
    } finally {
      await sub.cancel();
    }
  }

  /// Prompts the Android OS package installer to install the downloaded APK.
  static Future<bool> installApk(String apkFilePath) async {
    if (!Platform.isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': apkFilePath,
      });
      return success ?? false;
    } catch (e) {
      throw Exception('Failed to trigger package installer on Android: $e');
    }
  }
}
