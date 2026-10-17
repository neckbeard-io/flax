import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/services/cache/audio_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loaded gives the saved auto-cache choice, not the default', () async {
    SharedPreferences.setMockInitialValues({'flax_auto_cache_streamed': true});

    final notifier = AudioCacheConfigNotifier();
    addTearDown(notifier.dispose);

    // What the player read the moment the first track played.
    expect(notifier.state.autoCacheStreamed, isFalse);

    final config = await notifier.loaded;
    expect(config.autoCacheStreamed, isTrue);
    expect(notifier.state.autoCacheStreamed, isTrue);
  });

  test('auto-cache is off when nothing was saved', () async {
    SharedPreferences.setMockInitialValues({});

    final notifier = AudioCacheConfigNotifier();
    addTearDown(notifier.dispose);

    expect((await notifier.loaded).autoCacheStreamed, isFalse);
  });
}
