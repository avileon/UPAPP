import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:up/domain/entities/live_session.dart';
import 'package:up/domain/entities/nearby_person.dart';
import 'package:up/domain/entities/room_status.dart';
import 'package:up/domain/repositories/presence_repository.dart';
import 'package:up/state/live_controller.dart';

/// The bug these tests exist for, in one sentence: choosing a venue code while
/// already Live changed what the phone displayed and nothing on the server, so
/// two people on the same code sat in different rooms and the screen said they
/// were in the same one.
///
/// Both halves matter and both are asserted here — that the change is pushed to
/// the server at all, and that what the screen reads is the server's answer
/// rather than the phone's own hope.
class _FakePresence implements PresenceRepository {
  final StreamController<List<NearbyPerson>> _nearby =
      StreamController<List<NearbyPerson>>.broadcast();
  final StreamController<RoomStatus> _room =
      StreamController<RoomStatus>.broadcast();

  int syncVenueCalls = 0;
  bool stopped = false;

  void emitRoom(RoomStatus status) => _room.add(status);

  @override
  Future<LiveSession> startLive(Duration duration) async {
    final DateTime now = DateTime.now();
    return LiveSession(
      id: 'fake',
      startedAt: now,
      expiresAt: now.add(duration),
    );
  }

  @override
  Future<void> stopLive() async {
    stopped = true;
  }

  @override
  Stream<List<NearbyPerson>> watchNearby() => _nearby.stream;

  @override
  Stream<RoomStatus> watchRoom() => _room.stream;

  @override
  Future<void> syncVenue() async {
    syncVenueCalls++;
  }

  @override
  void simulateDiscovery() {}

  @override
  void dispose() {
    _nearby.close();
    _room.close();
  }
}

void main() {
  group('RoomStatus', () {
    test('an empty code is not a room', () {
      expect(RoomStatus.none.isJoined, isFalse);
      expect(const RoomStatus(code: '', peers: 3).isJoined, isFalse);
      expect(const RoomStatus(code: 'BAR12', peers: 0).isJoined, isTrue);
    });

    test('compares by value, so an unchanged poll does not repaint', () {
      expect(
        const RoomStatus(code: 'BAR12', peers: 2),
        const RoomStatus(code: 'BAR12', peers: 2),
      );
      expect(
        const RoomStatus(code: 'BAR12', peers: 2),
        isNot(const RoomStatus(code: 'BAR12', peers: 3)),
      );
    });
  });

  group('LiveController and the room', () {
    test('starts with no room at all', () {
      final _FakePresence presence = _FakePresence();
      final LiveController live = LiveController(presence: presence);
      addTearDown(() {
        live.dispose();
        presence.dispose();
      });

      expect(live.room, RoomStatus.none);
      expect(live.room.isJoined, isFalse);
    });

    test('takes the room from the server, not from what was typed', () async {
      final _FakePresence presence = _FakePresence();
      final LiveController live = LiveController(presence: presence);
      addTearDown(() {
        live.dispose();
        presence.dispose();
      });

      presence.emitRoom(const RoomStatus(code: 'BAR12', peers: 2));
      await Future<void>.delayed(Duration.zero);

      expect(live.room.code, 'BAR12');
      expect(live.room.peers, 2);
    });

    test('notifies once per change and not on a repeat', () async {
      final _FakePresence presence = _FakePresence();
      final LiveController live = LiveController(presence: presence);
      int notifications = 0;
      live.addListener(() => notifications++);
      addTearDown(() {
        live.dispose();
        presence.dispose();
      });

      presence.emitRoom(const RoomStatus(code: 'BAR12', peers: 1));
      await Future<void>.delayed(Duration.zero);
      presence.emitRoom(const RoomStatus(code: 'BAR12', peers: 1));
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });

    test('stopping Live leaves no room behind', () async {
      final _FakePresence presence = _FakePresence();
      final LiveController live = LiveController(presence: presence);
      addTearDown(() {
        live.dispose();
        presence.dispose();
      });

      await live.start(const Duration(minutes: 30));
      presence.emitRoom(const RoomStatus(code: 'BAR12', peers: 2));
      await Future<void>.delayed(Duration.zero);
      expect(live.room.isJoined, isTrue);

      await live.stop();

      expect(live.room, RoomStatus.none);
      expect(presence.stopped, isTrue);
    });

    test('a venue change is pushed to the server', () async {
      final _FakePresence presence = _FakePresence();
      final LiveController live = LiveController(presence: presence);
      addTearDown(() {
        live.dispose();
        presence.dispose();
      });

      await live.syncVenue();

      expect(presence.syncVenueCalls, 1);
    });
  });
}
