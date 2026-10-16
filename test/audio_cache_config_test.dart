import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/services/cache/audio_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loaded gives the saved auto-cache choice, not the default', () async {
    SharedPreferences.setMockInitialValues({'flax_auto_cache_streamed': false});

    final notifier = AudioCacheConfigNotifier();
    addTearDown(notifier.dispose);

    // What the player read the moment the first track played.
    expect(notifier.state.autoCacheStreamed, isTrue);

    final config = await notifier.loaded;
    expect(config.autoCacheStreamed, isFalse);
    expect(notifier.state.autoCacheStreamed, isFalse);
  });

  test('loaded keeps the default when nothing was saved', () async {
    SharedPreferences.setMockInitialValues({});

    final notifier = AudioCacheConfigNotifier();
    addTearDown(notifier.dispose);

    expect((await notifier.loaded).autoCacheStreamed, isTrue);
  });
}
