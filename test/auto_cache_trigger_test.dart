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
  late Completer<void> download;
  late AutoCacheTrigger trigger;

  setUp(() {
    cached = [];
    onDisk = {};
    enabled = true;
    download = Completer<void>();
    trigger = AutoCacheTrigger(
      enabled: () => enabled,
      isCached: (song) => onDisk.contains(song.id),
      cache: (song) {
        cached.add(song.id);
        return download.future;
      },
    );
  });

  test('a queue loaded paused is not cached', () {
    // What taking another device's queue from the server looks like: the
    // track is current, but nothing plays.
    trigger.update(a, playing: false);
    expect(cached, isEmpty);
  });

  test('a track is cached once it starts playing', () {
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    expect(cached, ['a']);
  });

  test('repeated states for the same track cache it once', () {
    // Every position tick is a new player state.
    for (var i = 0; i < 5; i++) {
      trigger.update(a, playing: true);
    }
    expect(cached, ['a']);
  });

  test('pausing and resuming does not start a second download', () {
    trigger.update(a, playing: true);
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    expect(cached, ['a']);
  });

  test('a failed download is tried again the next time it plays', () async {
    trigger.update(a, playing: true);
    download.complete();
    await pumpEventQueue();
    trigger.update(a, playing: false);
    trigger.update(a, playing: true);
    expect(cached, ['a', 'a']);
  });

  test('moving to the next track while playing caches it', () {
    trigger.update(a, playing: true);
    trigger.update(b, playing: true);
    expect(cached, ['a', 'b']);
  });

  test('nothing is cached when the setting is off or the track is on disk', () {
    enabled = false;
    trigger.update(a, playing: true);
    enabled = true;
    onDisk.add('b');
    trigger.update(b, playing: true);
    expect(cached, isEmpty);
  });
}
