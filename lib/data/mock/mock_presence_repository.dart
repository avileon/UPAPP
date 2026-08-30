import 'dart:async';
import 'dart:math';

import '../../domain/entities/live_session.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/room_status.dart';
import '../../domain/repositories/presence_repository.dart';
import 'mock_data.dart';

/// Fake radio.
///
/// Discovers a new person every [_discoveryInterval] while Live, in a random
/// order, and drops everyone the moment Live stops — which is exactly what the
/// real implementation must do when the session expires.
class MockPresenceRepository implements PresenceRepository {
  MockPresenceRepository({Random? random, DateTime Function()? now})
      : _random = random ?? Random(),
        _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;

  final StreamController<List<NearbyPerson>> _controller =
      StreamController<List<NearbyPerson>>.broadcast();

  final List<NearbyPerson> _discovered = <NearbyPerson>[];
  Timer? _discoveryTimer;
  Timer? _firstDiscoveryTimer;
  LiveSession? _session;

  static const Duration _discoveryInterval = Duration(seconds: 7);
  static const Duration _firstDiscoveryDelay = Duration(milliseconds: 900);

  LiveSession? get session => _session;

  @override
  Future<LiveSession> startLive(Duration duration) async {
    final DateTime start = _now();
    _session = LiveSession(
      id: 'live-${start.microsecondsSinceEpoch}',
      startedAt: start,
      expiresAt: start.add(duration),
    );
    _discovered.clear();
    _emit();

    _discoveryTimer?.cancel();
    _firstDiscoveryTimer?.cancel();
    _firstDiscoveryTimer = Timer(_firstDiscoveryDelay, () {
      simulateDiscovery();
      _discoveryTimer = Timer.periodic(
        _discoveryInterval,
        (_) => simulateDiscovery(),
      );
    });
    return _session!;
  }

  @override
  Future<void> stopLive() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _firstDiscoveryTimer?.cancel();
    _firstDiscoveryTimer = null;
    _session = null;
    _discovered.clear();
    _emit();
  }

  @override
  Stream<List<NearbyPerson>> watchNearby() => _controller.stream;

  /// The mock stack has no server and therefore no room: the fake radio finds
  /// people directly. Emitting nothing is the honest answer — the UI treats an
  /// absent room status as "not applicable" rather than as an empty room.
  @override
  Stream<RoomStatus> watchRoom() => const Stream<RoomStatus>.empty();

  @override
  Future<void> syncVenue() async {}

  @override
  void simulateDiscovery() {
    if (_session == null) {
      return;
    }
    final List<NearbyPerson> remaining = MockData.people
        .where((NearbyPerson p) => !_discovered.contains(p))
        .toList(growable: false);
    if (remaining.isEmpty) {
      return;
    }
    _discovered.add(remaining[_random.nextInt(remaining.length)]);
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(List<NearbyPerson>.unmodifiable(_discovered));
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _firstDiscoveryTimer?.cancel();
    _firstDiscoveryTimer = null;
    _controller.close();
  }
}
