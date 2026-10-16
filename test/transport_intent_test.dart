import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/player/transport_intent.dart';

void main() {
  late TransportIntent intent;

  setUp(() => intent = TransportIntent());

  test('a play during the load is wanted after it', () {
    final mark = intent.mark();
    intent.play();
    expect(intent.playRequestedSince(mark), isTrue);
  });

  test('a pause after the play wins', () {
    final mark = intent.mark();
    intent.play();
    intent.pause();
    expect(intent.playRequestedSince(mark), isFalse);
  });

  test('nothing during the load leaves it paused', () {
    final mark = intent.mark();
    expect(intent.playRequestedSince(mark), isFalse);
  });

  test('a pause alone leaves it paused', () {
    final mark = intent.mark();
    intent.pause();
    expect(intent.playRequestedSince(mark), isFalse);
  });

  test('a play before the load started does not count', () {
    intent.play();
    final mark = intent.mark();
    expect(intent.playRequestedSince(mark), isFalse);
  });

  test('a pause then a play during the load still plays', () {
    final mark = intent.mark();
    intent.pause();
    intent.play();
    expect(intent.playRequestedSince(mark), isTrue);
  });
}
