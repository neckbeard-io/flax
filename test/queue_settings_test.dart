import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/queue_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncQueueWithServerProvider defaults to true', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(syncQueueWithServerProvider), isTrue);
  });

  test('setEnabled persists false to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(syncQueueWithServerProvider.notifier)
        .setEnabled(false);

    expect(container.read(syncQueueWithServerProvider), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SyncQueueWithServerNotifier.storageKey), isFalse);
  });

  test('loads saved false value on initialization', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SyncQueueWithServerNotifier.storageKey, false);

    final notifier = SyncQueueWithServerNotifier();
    // Wait for async _load
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notifier.state, isFalse);
  });

  // The queue restore read the setting the moment it was created, got the
  // default, and fetched the server's queue on a device where sharing was off.
  test('loaded waits for the saved choice on a first read', () async {
    SharedPreferences.setMockInitialValues({
      SyncQueueWithServerNotifier.storageKey: false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(syncQueueWithServerProvider.notifier);
    expect(container.read(syncQueueWithServerProvider), isTrue);
    expect(await notifier.loaded, isFalse);
  });

  test('loaded is the default when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(syncQueueWithServerProvider.notifier).loaded,
      isTrue,
    );
  });

  test('loaded follows a later change', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(syncQueueWithServerProvider.notifier);
    await notifier.loaded;
    await notifier.setEnabled(false);
    expect(await notifier.loaded, isFalse);
  });
}
