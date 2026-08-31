import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/services/audio/flax_audio_handler.dart';

final audioHandlerProvider = StateProvider<FlaxAudioHandler?>((ref) {
  return null;
});

class AudioServiceInitializer {
  static Future<FlaxAudioHandler?> initialize(
    ProviderContainer container,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      AppLogger.i('AudioService', 'Initializing AudioService for Android Auto');
      final handler = await AudioService.init(
        builder: () => FlaxAudioHandler(container),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.flaxplayer.flax.audio',
          androidNotificationChannelName: 'Flax Audio Playback',
          androidNotificationChannelDescription:
              'Playback controls and notification for Flax Music Player',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      return handler;
    } catch (e, st) {
      AppLogger.e(
        'AudioService',
        'Failed to initialize AudioService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
