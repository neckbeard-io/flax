import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/domain/models/song.dart';

typedef MediaCallback = void Function();
typedef SeekCallback = void Function(Duration position);

class NowPlayingService {
  static const _channel = MethodChannel('com.flax/now_playing');

  MediaCallback? onPlay;
  MediaCallback? onPause;
  MediaCallback? onTogglePlayPause;
  MediaCallback? onNext;
  MediaCallback? onPrevious;
  SeekCallback? onSeek;

  NowPlayingService() {
    if (Platform.isMacOS) {
      _channel.setMethodCallHandler(_handleMethod);
    }
  }

  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onPlay':
        onPlay?.call();
      case 'onPause':
        onPause?.call();
      case 'onTogglePlayPause':
        onTogglePlayPause?.call();
      case 'onNext':
        onNext?.call();
      case 'onPrevious':
        onPrevious?.call();
      case 'onSeek':
        final seconds = call.arguments as double;
        onSeek?.call(Duration(milliseconds: (seconds * 1000).toInt()));
    }
  }

  Future<void> updateNowPlaying({
    required Song song,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    String? artUrl,
  }) async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('updateNowPlaying', {
        'title': song.title,
        'artist': song.artistName ?? '',
        'album': song.albumName ?? '',
        'duration': duration.inMilliseconds / 1000.0,
        'position': position.inMilliseconds / 1000.0,
        'rate': isPlaying ? 1.0 : 0.0,
        if (song.track != null) 'trackNumber': song.track!,
        if (artUrl != null) 'artUrl': artUrl,
      });
    } catch (_) {
      // Silently ignore if channel not available
    }
  }

  Future<void> updatePlaybackState({
    required Duration position,
    required bool isPlaying,
  }) async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'position': position.inMilliseconds / 1000.0,
        'rate': isPlaying ? 1.0 : 0.0,
      });
    } catch (_) {
      // Silently ignore
    }
  }

  Future<void> clear() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('clearNowPlaying');
    } catch (_) {}
  }
}

final nowPlayingServiceProvider = Provider<NowPlayingService>((ref) {
  return NowPlayingService();
});
