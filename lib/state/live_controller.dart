import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../domain/entities/live_session.dart';
import '../domain/entities/nearby_person.dart';
import '../domain/repositories/presence_repository.dart';

/// Owns the Live session and the nearby list.
///
/// The ticking clock lives here, not in a widget, so the countdown keeps
/// running across navigation and so expiry is a single code path.
class LiveController extends ChangeNotifier {
  LiveController({
    required PresenceRepository presence,
    DateTime Function()? now,
  })  : _presence = presence,
        _now = now ?? DateTime.now {
    _nearbySubscription = _presence.watchNearby().listen(_onNearby);
  }

  final PresenceRepository _presence;
  final DateTime Function() _now;

  StreamSubscription<List<NearbyPerson>>? _nearbySubscription;
  Timer? _ticker;

  LiveSession? _session;
  List<NearbyPerson> _nearby = const <NearbyPerson>[];
  Duration _remaining = Duration.zero;

  LiveSession? get session => _session;
  bool get isLive => _session != null;

  /// Why the last attempt to go Live failed, as the server's error code.
  /// Cleared by the next attempt.
  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;
  Duration get remaining => _remaining;
  List<NearbyPerson> get nearby => _nearby;

  /// Nearby minus everyone hidden for this session.
  List<NearbyPerson> visibleNearby({
    required Set<String> passedIds,
    required Set<String> blockedIds,
  }) {
    return _nearby
        .where((NearbyPerson p) =>
            !passedIds.contains(p.id) && !blockedIds.contains(p.id))
        .toList(growable: false);
  }

  Future<void> start(Duration duration) async {
    _lastErrorCode = null;
    try {
      final LiveSession session = await _presence.startLive(duration);
      _session = session;
      _remaining = session.remainingAt(_now());
      _startTicker();
    } on ApiException catch (error) {
      // Going Live is one tap on the main screen. A dead tunnel there must
      // leave the button where it was and say why, not throw into the void.
      _lastErrorCode = error.code;
      _session = null;
      _remaining = Duration.zero;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _lastErrorCode = null;
    _ticker?.cancel();
    _ticker = null;
    _session = null;
    _remaining = Duration.zero;
    await _presence.stopLive();
    notifyListeners();
  }

  Future<void> toggle(Duration duration) =>
      isLive ? stop() : start(duration);

  void discoverOneMore() => _presence.simulateDiscovery();

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final LiveSession? session = _session;
      if (session == null) {
        return;
      }
      final DateTime now = _now();
      if (!session.isActiveAt(now)) {
        // Expiry is not a special case in the UI — it is the same stop path.
        unawaited(stop());
        return;
      }
      _remaining = session.remainingAt(now);
      notifyListeners();
    });
  }

  void _onNearby(List<NearbyPerson> people) {
    _nearby = people;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nearbySubscription?.cancel();
    _nearbySubscription = null;
    _presence.dispose();
    super.dispose();
  }
}
