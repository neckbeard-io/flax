import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
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

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      final handler = await AudioService.init(
        builder: () => FlaxAudioHandler(container),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.flaxplayer.flax.audio',
          androidNotificationChannelName: 'Flax Audio Playback',
          androidNotificationChannelDescription:
              'Playback controls and notification for Flax Music Player',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidShowNotificationBadge: true,
          // Monochrome, as a notification small icon must be: the full-color
          // launcher icon rendered as a solid blob in the status bar.
          androidNotificationIcon: 'drawable/ic_flax_logo_mono',
          androidBrowsableRootExtras: {
            AndroidContentStyle.supportedKey: true,
            AndroidContentStyle.browsableHintKey:
                AndroidContentStyle.gridItemHintValue,
            AndroidContentStyle.playableHintKey:
                AndroidContentStyle.listItemHintValue,
          },
        ),
      );
      AppLogger.i('AudioService', 'AudioService ready');
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
