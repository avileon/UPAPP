import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:up/state/photo_cache.dart';

/// The cache sits between a scrolling list and the network, which is the one
/// place where "fetch it again" quietly becomes "fetch it sixty times a
/// second". These tests are about how often it asks, not about what it draws.
void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  test('the first ask starts a fetch and returns nothing yet', () async {
    int calls = 0;
    final PhotoCache cache = PhotoCache(fetch: (String key) async {
      calls++;
      return bytes;
    });

    expect(cache.bytesFor('a'), isNull);
    expect(calls, 1);

    await Future<void>.delayed(Duration.zero);
    expect(cache.bytesFor('a'), bytes);
    expect(calls, 1, reason: 'a cached photo is not fetched again');
  });

  test('a repeat ask while in flight does not start a second fetch', () async {
    int calls = 0;
    final PhotoCache cache = PhotoCache(fetch: (String key) async {
      calls++;
      return bytes;
    });

    // What a list does: several widgets asking for the same face in one frame.
    cache.bytesFor('a');
    cache.bytesFor('a');
    cache.bytesFor('a');
    expect(calls, 1);
  });

  test('a photo that is not there is asked for once, not every frame', () async {
    int calls = 0;
    final PhotoCache cache = PhotoCache(fetch: (String key) async {
      calls++;
      return null;
    });

    cache.bytesFor('gone');
    await Future<void>.delayed(Duration.zero);
    cache.bytesFor('gone');
    cache.bytesFor('gone');
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);

    // Until something says conditions changed.
    cache.retryFailed();
    cache.bytesFor('gone');
    expect(calls, 2);
  });

  test('a fetch that throws is a miss, not a crash', () async {
    final PhotoCache cache = PhotoCache(fetch: (String key) async {
      throw Exception('network down');
    });

    expect(cache.bytesFor('a'), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(cache.bytesFor('a'), isNull);
  });

  test('a blip parks a photo briefly; a real 404 parks it for good', () async {
    // The distinction that matters on a scrolling list: two seconds of dead
    // tunnel must not blank someone's face for the rest of the session, and a
    // photo that genuinely is not there must not be asked for every frame.
    int calls = 0;
    bool offline = true;
    final PhotoCache cache = PhotoCache(fetch: (String key) async {
      calls++;
      if (offline) {
        throw Exception('tunnel down');
      }
      return bytes;
    });

    cache.bytesFor('a');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    // Still parked a moment later — no request storm while the tunnel is down.
    cache.bytesFor('a');
    expect(calls, 1);

    // The connection comes back and something says so.
    offline = false;
    cache.retryFailed();
    cache.bytesFor('a');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
    expect(cache.bytesFor('a'), bytes);
  });

  test('with no fetcher every key is a placeholder', () {
    // This is the mock stack: the app runs end to end with no server at all.
    final PhotoCache cache = PhotoCache();
    expect(cache.bytesFor('anything'), isNull);
    expect(cache.bytesFor(null), isNull);
    expect(cache.bytesFor(''), isNull);
  });

  test('bytes handed in directly are available immediately', () {
    final PhotoCache cache = PhotoCache();
    cache.remember('mine', bytes);
    expect(cache.bytesFor('mine'), bytes);

    cache.forget('mine');
    expect(cache.bytesFor('mine'), isNull);
  });

  test('the cache is bounded', () async {
    final PhotoCache cache = PhotoCache();
    for (int i = 0; i < 200; i++) {
      cache.remember('key$i', bytes);
    }
    // The oldest are gone; the newest are not.
    expect(cache.bytesFor('key0'), isNull);
    expect(cache.bytesFor('key199'), bytes);
  });
}
