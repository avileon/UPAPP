import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:up/data/mock/mock_presence_repository.dart';
import 'package:up/domain/entities/live_session.dart';
import 'package:up/domain/entities/nearby_person.dart';

void main() {
  group('LiveSession', () {
    final DateTime start = DateTime(2026, 8, 26, 22, 0);

    test('reports the time left', () {
      final LiveSession session = LiveSession(
        id: 's',
        startedAt: start,
        expiresAt: start.add(const Duration(minutes: 60)),
      );

      expect(
        session.remainingAt(start.add(const Duration(minutes: 20))),
        const Duration(minutes: 40),
      );
    });

    test('never reports negative time left', () {
      final LiveSession session = LiveSession(
        id: 's',
        startedAt: start,
        expiresAt: start.add(const Duration(minutes: 30)),
      );

      expect(
        session.remainingAt(start.add(const Duration(hours: 3))),
        Duration.zero,
      );
      expect(
        session.isActiveAt(start.add(const Duration(hours: 3))),
        isFalse,
      );
    });

    test('a session is always bounded', () {
      for (final Duration d in LiveSession.selectableDurations) {
        expect(d, greaterThan(Duration.zero));
        expect(d, lessThanOrEqualTo(const Duration(hours: 2)));
      }
    });
  });

  group('MockPresenceRepository', () {
    test('discovers nobody until Live starts', () {
      final MockPresenceRepository repo =
          MockPresenceRepository(random: Random(1));
      addTearDown(repo.dispose);

      repo.simulateDiscovery();

      expect(repo.session, isNull);
    });

    test('stopping Live empties the nearby list', () async {
      final MockPresenceRepository repo =
          MockPresenceRepository(random: Random(1));
      addTearDown(repo.dispose);

      final List<List<NearbyPerson>> emissions = <List<NearbyPerson>>[];
      final sub = repo.watchNearby().listen(emissions.add);
      addTearDown(sub.cancel);

      await repo.startLive(const Duration(minutes: 30));
      repo.simulateDiscovery();
      repo.simulateDiscovery();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, hasLength(2));

      await repo.stopLive();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, isEmpty);
      expect(repo.session, isNull);
    });

    test('never discovers the same person twice', () async {
      final MockPresenceRepository repo =
          MockPresenceRepository(random: Random(7));
      addTearDown(repo.dispose);

      final List<List<NearbyPerson>> emissions = <List<NearbyPerson>>[];
      final sub = repo.watchNearby().listen(emissions.add);
      addTearDown(sub.cancel);

      await repo.startLive(const Duration(minutes: 30));
      for (int i = 0; i < 20; i++) {
        repo.simulateDiscovery();
      }
      await Future<void>.delayed(Duration.zero);

      final List<NearbyPerson> last = emissions.last;
      final Set<String> ids =
          last.map((NearbyPerson p) => p.id).toSet();

      expect(ids.length, last.length);
    });
  });
}
