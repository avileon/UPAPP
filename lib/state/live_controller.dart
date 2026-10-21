import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../domain/entities/geo_fix.dart';
import '../domain/entities/live_intent.dart';
import '../domain/entities/live_session.dart';
import '../domain/entities/nearby_person.dart';
import '../domain/entities/room_status.dart';
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
    _roomSubscription = _presence.watchRoom().listen(_onRoom);
  }

  final PresenceRepository _presence;
  final DateTime Function() _now;

  StreamSubscription<List<NearbyPerson>>? _nearbySubscription;
  StreamSubscription<RoomStatus>? _roomSubscription;
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

  /// The room the server says this session is in. [RoomStatus.none] until the
  /// first answer, and on the mock stack forever — which is correct, because
  /// there is no room there to be in.
  RoomStatus get room => _room;
  RoomStatus _room = RoomStatus.none;

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

  Future<void> start(
    Duration duration, {
    LiveIntent intent = LiveIntent.meet,
    String note = '',
    String venue = '',
    GeoFix? fix,
  }) async {
    _lastErrorCode = null;
    _endedVenue = null;
    try {
      final LiveSession session = await _presence.startLive(
        duration,
        intent: intent,
        note: note,
        venue: venue,
        fix: fix,
      );
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

  /// The place whose hour just ran out, so the home screen can offer to scan
  /// again instead of silently dropping the person out of the room. Cleared by
  /// the next start.
  LiveSession? get endedVenue => _endedVenue;
  LiveSession? _endedVenue;

  void dismissEndedVenue() {
    if (_endedVenue == null) {
      return;
    }
    _endedVenue = null;
    notifyListeners();
  }

  /// Someone in the room just sent you an UP. One event per person per app
  /// run — the screen flips once, not on every poll.
  Stream<NearbyPerson> get incomingUps => _incomingUps.stream;
  final StreamController<NearbyPerson> _incomingUps =
      StreamController<NearbyPerson>.broadcast();
  final Set<String> _announcedUps = <String>{};

  Future<void> stop() async {
    _lastErrorCode = null;
    _ticker?.cancel();
    _ticker = null;
    _session = null;
    _remaining = Duration.zero;
    _room = RoomStatus.none;
    await _presence.stopLive();
    notifyListeners();
  }

  Future<void> toggle(
    Duration duration, {
    LiveIntent intent = LiveIntent.meet,
    String note = '',
    GeoFix? fix,
  }) =>
      isLive ? stop() : start(duration, intent: intent, note: note, fix: fix);

  /// The intent of the running session, or the default when not Live.
  LiveIntent get intent => _session?.intent ?? LiveIntent.meet;

  /// Rooms already holding people, for the intent about to be used.
  Future<List<RoomSummary>> rooms(LiveIntent intent) => _presence.rooms(intent);

  /// Moves a running session into the venue code chosen since it started.
  ///
  /// Called when the code changes rather than when Live starts, because those
  /// are the two orders people actually do it in and only one of them used to
  /// work.
  Future<void> syncVenue() => _presence.syncVenue();

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
        unawaited(stop().then((_) {
          if (session.isVenue) {
            _endedVenue = session;
            notifyListeners();
          }
        }));
        return;
      }
      _remaining = session.remainingAt(now);
      notifyListeners();
    });
  }

  void _onNearby(List<NearbyPerson> people) {
    _nearby = people;
    for (final NearbyPerson person in people) {
      if (person.sentYouUp &&
          !person.youSentUp &&
          _announcedUps.add(person.id) &&
          !_incomingUps.isClosed) {
        _incomingUps.add(person);
      }
    }
    notifyListeners();
  }

  void _onRoom(RoomStatus room) {
    if (room == _room) {
      return;
    }
    _room = room;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nearbySubscription?.cancel();
    _nearbySubscription = null;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _incomingUps.close();
    _presence.dispose();
    super.dispose();
  }
}
