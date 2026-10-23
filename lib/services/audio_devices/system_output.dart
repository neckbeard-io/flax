import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/services/audio_devices/audio_device.dart';

/// Which physical device the system's default output is. Issue #69.
///
/// mpv plays to "auto" unless a device is chosen under Audio Output, and it
/// cannot say what "auto" resolves to, so each platform is asked directly.
abstract class SystemOutputSource {
  /// The current default output, then each change to it.
  Stream<AudioEndpoint> watch();

  factory SystemOutputSource.forPlatform() {
    // Widget tests start the player, and with it this. A real `pactl` answers
    // in real time, after the test's fake clock has moved on, which left the
    // device switch's settle timer pending at the end of tests on Linux.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const _SilentSystemOutput();
    }
    if (Platform.isMacOS || Platform.isAndroid) return NativeSystemOutput();
    if (Platform.isLinux) return PactlSystemOutput();
    // Windows: no native resolver yet, so the default stands for itself.
    return const FixedSystemOutput(AudioEndpoint.systemDefault);
  }
}

/// Never reports an output, so nothing switches.
class _SilentSystemOutput implements SystemOutputSource {
  const _SilentSystemOutput();

  @override
  Stream<AudioEndpoint> watch() => const Stream.empty();
}

class FixedSystemOutput implements SystemOutputSource {
  const FixedSystemOutput(this.endpoint);

  final AudioEndpoint endpoint;

  @override
  Stream<AudioEndpoint> watch() => Stream.value(endpoint);
}

/// macOS (CoreAudio, `AudioRouteBridge.swift`) and Android (`AudioManager`,
/// `FlaxAudioRoute.kt`).
///
/// Both send `{id, name, type}`. macOS ids are `coreaudio/<UID>`, the name mpv
/// gives the same device, so choosing it under Audio Output keeps its profiles.
class NativeSystemOutput implements SystemOutputSource {
  static const _channel = MethodChannel('com.flax/audio_route');
  static const _events = EventChannel('com.flax/audio_route_events');

  @override
  Stream<AudioEndpoint> watch() async* {
    try {
      final first = AudioEndpoint.fromPlatform(
        await _channel.invokeMethod<Object?>('currentOutput'),
      );
      yield first ?? AudioEndpoint.systemDefault;
    } catch (e) {
      // No handler: a test, or a build without the native side.
      AppLogger.d('AudioRoute', () => 'currentOutput unavailable: $e');
      yield AudioEndpoint.systemDefault;
      return;
    }
    yield* _events
        .receiveBroadcastStream()
        .handleError((Object e) {
          AppLogger.d('AudioRoute', () => 'route events failed: $e');
        })
        .map(AudioEndpoint.fromPlatform)
        .where((e) => e != null)
        .cast<AudioEndpoint>();
  }
}

/// Linux, through PulseAudio's `pactl`, which PipeWire also answers.
///
/// Reports the default sink as `pulse/<sink>`, which is the name mpv gives the
/// same sink; [normalizeMpvDeviceId] folds mpv's `pipewire/` spelling onto it.
/// The sink name is all `pactl info` says, so the description is filled in
/// from mpv's device list by the caller.
class PactlSystemOutput implements SystemOutputSource {
  PactlSystemOutput({
    Future<ProcessResult> Function(
      String,
      List<String>, {
      Map<String, String>? environment,
    })?
    run,
    Future<Process> Function(String, List<String>)? start,
  }) : _run = run ?? Process.run,
       _start = start ?? Process.start;

  final Future<ProcessResult> Function(
    String,
    List<String>, {
    Map<String, String>? environment,
  })
  _run;
  final Future<Process> Function(String, List<String>) _start;

  @override
  Stream<AudioEndpoint> watch() {
    late final StreamController<AudioEndpoint> controller;
    Process? subscription;
    Timer? settle;

    Future<void> emit() async {
      final endpoint = await current();
      if (!controller.isClosed) {
        controller.add(endpoint ?? AudioEndpoint.systemDefault);
      }
    }

    controller = StreamController<AudioEndpoint>(
      onListen: () async {
        await emit();
        try {
          subscription = await _start('pactl', ['subscribe']);
          subscription!.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                // "Event 'change' on server #N" is how a new default sink is
                // announced. A burst of them follows one switch.
                if (!line.contains('on server')) return;
                settle?.cancel();
                settle = Timer(const Duration(milliseconds: 300), emit);
              });
        } catch (e) {
          AppLogger.d('AudioRoute', () => 'pactl subscribe failed: $e');
        }
      },
      onCancel: () {
        settle?.cancel();
        subscription?.kill();
      },
    );
    return controller.stream;
  }

  /// The default sink, or null when `pactl` is missing or says nothing.
  Future<AudioEndpoint?> current() async {
    try {
      // `pactl info` rather than `get-default-sink`, which needs pactl 15;
      // the C locale keeps the "Default Sink:" label untranslated.
      final result = await _run(
        'pactl',
        ['info'],
        environment: const {'LC_ALL': 'C'},
      );
      if (result.exitCode != 0) return null;
      final sink = parseDefaultSink(result.stdout as String);
      if (sink == null) return null;
      return AudioEndpoint(
        id: 'pulse/$sink',
        name: sink,
        type: classifyDevice(sink, ''),
      );
    } catch (e) {
      AppLogger.d('AudioRoute', () => 'pactl info failed: $e');
      return null;
    }
  }

  static String? parseDefaultSink(String info) {
    for (final line in const LineSplitter().convert(info)) {
      if (!line.startsWith('Default Sink:')) continue;
      final sink = line.substring('Default Sink:'.length).trim();
      return sink.isEmpty ? null : sink;
    }
    return null;
  }
}

/// One id per physical device whichever of mpv's outputs names it.
///
/// On Linux mpv lists every sink twice, as `pipewire/<x>` and `pulse/<x>`;
/// both are the same device, and so is the default sink `pactl` reports.
String normalizeMpvDeviceId(String name) {
  if (name.startsWith('pipewire/')) {
    return 'pulse/${name.substring('pipewire/'.length)}';
  }
  return name;
}
