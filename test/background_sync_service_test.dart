import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/platform/background_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundSyncStatus', () {
    test('default status constructor values', () {
      const status = BackgroundSyncStatus();
      expect(status.isScheduled, isFalse);
      expect(status.lastSyncTimestamp, isNull);
    });

    test('custom status constructor values', () {
      final now = DateTime.now();
      final status = BackgroundSyncStatus(
        isScheduled: true,
        lastSyncTimestamp: now,
      );
      expect(status.isScheduled, isTrue);
      expect(status.lastSyncTimestamp, equals(now));
    });
  });

  group('BackgroundSyncService', () {
    test('instantiates and provides supported platform check', () {
      final service = BackgroundSyncService();
      expect(service, isNotNull);
      // On macOS test runner, isSupported is false (Platform.isAndroid is false)
      expect(BackgroundSyncService.isSupported, isFalse);
    });

    test('non-Android platform returns false/empty gracefully', () async {
      final service = BackgroundSyncService();
      final scheduled = await service.schedulePeriodicSync();
      expect(scheduled, isFalse);

      final canceled = await service.cancelPeriodicSync();
      expect(canceled, isFalse);

      final triggered = await service.triggerImmediateSync();
      expect(triggered, isFalse);

      final status = await service.getSyncStatus();
      expect(status.isScheduled, isFalse);
      expect(status.lastSyncTimestamp, isNull);
    });
  });
}
