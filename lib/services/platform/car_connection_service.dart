import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/logging/app_logger.dart';

final carConnectionServiceProvider = Provider<CarConnectionService>((ref) {
  final service = CarConnectionService();
  ref.onDispose(service.dispose);
  return service;
});

final isCarConnectedProvider =
    StateNotifierProvider<CarConnectionNotifier, bool>((ref) {
      final service = ref.watch(carConnectionServiceProvider);
      return service.notifier;
    });

class CarConnectionNotifier extends StateNotifier<bool> {
  CarConnectionNotifier([super.initial = false]);

  void setCarConnected(bool connected) {
    if (state != connected) {
      AppLogger.i('CarConnection', 'Car connection state changed: $connected');
      state = connected;
    }
  }
}

class CarConnectionService {
  static const _channel = MethodChannel('com.flax/car_connection');
  static const _eventChannel = EventChannel('com.flax/car_connection_events');

  final CarConnectionNotifier notifier;
  StreamSubscription? _subscription;

  /// [initiallyConnected] is the state startup already read (see
  /// [queryCarConnected]), so offline decisions made before the first event
  /// arrives are made with the real answer rather than "not connected".
  CarConnectionService({bool initiallyConnected = false})
    : notifier = CarConnectionNotifier(initiallyConnected) {
    _init();
  }

  /// Asks the platform once whether a car is connected — Android Auto or an
  /// Android Automotive head unit. False elsewhere.
  ///
  /// Safe to await before `runApp`: the channel is registered on every engine
  /// by the app itself, so it answers whether or not an Activity is attached.
  static Future<bool> queryCarConnected() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isCarConnected') ?? false;
  }

  Future<void> _init() async {
    if (!Platform.isAndroid) return;

    try {
      final initial = await _channel.invokeMethod<bool>('isCarConnected');
      if (initial != null) {
        notifier.setCarConnected(initial);
      }
    } catch (e) {
      AppLogger.d(
        'CarConnection',
        () => 'Initial car connection query error: $e',
      );
    }

    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is bool) {
            notifier.setCarConnected(event);
            if (event) {
              activateMediaSession();
            }
          }
        },
        onError: (err) {
          AppLogger.d(
            'CarConnection',
            () => 'Car connection event stream error: $err',
          );
        },
      );
    } catch (e) {
      AppLogger.d(
        'CarConnection',
        () => 'Car connection event stream listen error: $e',
      );
    }
  }

  Future<void> activateMediaSession() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('activateMediaSession');
    } catch (e) {
      AppLogger.d('CarConnection', () => 'activateMediaSession error: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
