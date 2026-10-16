import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/auto_cache.dart';

void main() {
  const a = Song(id: 'a', serverId: 'srv', title: 'Am Abgrund');
  const b = Song(id: 'b', serverId: 'srv', title: 'Tormento');

  late List<String> cached;
  late Set<String> onDisk;
  late bool enabled;
  late Completer<bool>? setting;
  late Completer<void> download;
  late AutoCacheTrigger trigger;

  setUp(() {
    cached = [];
    onDisk = {};
    enabled = true;
    // Null once the saved setting has loaded; a completer while it is still
    // being read.
    setting = null;
    download = Completer<void>();
    trigger = AutoCacheTrigger(
      enabled: () => setting?.future ?? Future.value(enabled),
      isCached: (song) => onDisk.contains(song.id),
      cache: (song) {
        cached.add(song.id);
        return download.future;
      },
    );
  });

  test('a queue loaded paused is not cached', () async {
    // What taking another device's queue from the server looks like: the
    // track is current, but nothing plays.
    trigger.update(a, playing: false);
    await pumpEventQueue();
    expect(cached, isEmpty);
  });

  test('a track is cached once it starts playing', () async {
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    await pumpEventQueue();
    expect(cached, ['a']);
  });

  test('repeated states for the same track cache it once', () async {
    // Every position tick is a new player state.
    for (var i = 0; i < 5; i++) {
      trigger.update(a, playing: true);
    }
    await pumpEventQueue();
    expect(cached, ['a']);
  });

  test('pausing and resuming does not start a second download', () async {
    trigger.update(a, playing: true);
    await pumpEventQueue();
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    await pumpEventQueue();
    expect(cached, ['a']);
  });

  test('a failed download is tried again the next time it plays', () async {
    trigger.update(a, playing: true);
    await pumpEventQueue();
    download.complete();
    await pumpEventQueue();
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    await pumpEventQueue();
    expect(cached, ['a', 'a']);
  });

  test('moving to the next track while playing caches it', () async {
    trigger.update(a, playing: true);
    trigger.update(b, playing: true);
    await pumpEventQueue();
    expect(cached, ['a', 'b']);
  });

  test(
    'nothing is cached when the setting is off or the track is on disk',
    () async {
      enabled = false;
      trigger.update(a, playing: true);
      await pumpEventQueue();
      enabled = true;
      onDisk.add('b');
      trigger.update(b, playing: true);
      await pumpEventQueue();
      expect(cached, isEmpty);
    },
  );

  group('before the saved setting has loaded', () {
    // The first track after a launch can start playing before the setting is
    // read from disk. Reading it then gave the default, which is on.
    setUp(() => setting = Completer<bool>());

    test('nothing is cached while it loads, nor once it loads off', () async {
      trigger.update(a, playing: true);
      await pumpEventQueue();
      expect(cached, isEmpty);

      setting!.complete(false);
      await pumpEventQueue();
      expect(cached, isEmpty);
    });

    test('the track is cached once, when it loads on', () async {
      trigger.update(a, playing: true);
      await pumpEventQueue();
      expect(cached, isEmpty);

      setting!.complete(true);
      await pumpEventQueue();
      expect(cached, ['a']);
    });

    test(
      'states for the same track while it loads start one download',
      () async {
        trigger.update(a, playing: true);
        trigger.update(a, playing: false);
        trigger.update(a, playing: true);
        await pumpEventQueue();

        setting!.complete(true);
        await pumpEventQueue();
        expect(cached, ['a']);
      },
    );

    test('a track that reached the disk meanwhile is not cached', () async {
      trigger.update(a, playing: true);
      onDisk.add('a');

      setting!.complete(true);
      await pumpEventQueue();
      expect(cached, isEmpty);
    });
  });
}
