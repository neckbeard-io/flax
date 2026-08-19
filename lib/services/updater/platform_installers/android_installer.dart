import 'dart:io';
import 'package:flutter/services.dart';

class AndroidInstaller {
  static const _channel = MethodChannel('com.flax/package_installer');

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
