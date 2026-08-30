import 'dart:async';

import '../../domain/entities/live_session.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/room_status.dart';
import '../../domain/repositories/presence_repository.dart';
import 'api_client.dart';
import 'api_mappers.dart';

/// Going Live and discovering people, against the real server.
///
/// **What this does not do yet: talk to the radio.** BLE arrives in Milestone
/// 3, and until it does the server's venue key is the discovery channel — two
/// phones that entered the same short code resolve each other. The rest of the
/// pipeline is already the real one: the server mints rotating tokens on
/// `/live/start`, and `/nearby/resolve` decides who may be seen. When the radio
/// lands, the only change here is filling [_observedTokens] from a scan instead
/// of leaving it empty.
class ApiPresenceRepository implements PresenceRepository {
  ApiPresenceRepository({
    required ApiClient client,
    required String Function() venueCode,
    void Function(Iterable<NearbyPerson> people)? onPeople,
    void Function(Object error)? onError,
  })  : _client = client,
        _venueCode = venueCode,
        _onPeople = onPeople,
        _onError = onError;

  final ApiClient _client;
  final String Function() _venueCode;
  final void Function(Iterable<NearbyPerson> people)? _onPeople;
  final void Function(Object error)? _onError;

  final StreamController<List<NearbyPerson>> _controller =
      StreamController<List<NearbyPerson>>.broadcast();

  final StreamController<RoomStatus> _room =
      StreamController<RoomStatus>.broadcast();

  /// Tokens heard off the air this session. Empty until Milestone 3.
  final Set<String> _observedTokens = <String>{};

  Timer? _poll;
  LiveSession? _session;
  bool _inFlight = false;
  bool _rearming = false;

  /// The venue the *server* put this session in, normalised, as echoed by
  /// `/live/start`. Compared against the chosen code to decide whether a
  /// re-issue is needed; never assumed equal to what the user typed.
  String _joinedVenue = '';

  /// Often enough that walking into a room feels immediate, rarely enough that
  /// an hour of Live is not thousands of requests. A socket replaces this.
  static const Duration _pollInterval = Duration(seconds: 5);

  LiveSession? get session => _session;

  @override
  Future<LiveSession> startLive(Duration duration) async {
    final String venue = _venueCode();
    final Map<String, dynamic> result = await _client.post(
      '/live/start',
      <String, dynamic>{
        'durationSeconds': duration.inSeconds,
        if (venue.isNotEmpty) 'venue': venue,
      },
    );

    final DateTime now = DateTime.now();
    _session = LiveSession(
      id: ApiMappers.string(result['sessionId']),
      startedAt: now,
      expiresAt: ApiMappers.dateTime(
        result['expiresAt'],
        now.add(duration),
      ),
    );
    _joinedVenue = ApiMappers.string(result['venue']);
    _observedTokens.clear();
    _controller.add(const <NearbyPerson>[]);
    _emitRoom(_joinedVenue, 0);

    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_resolve()));
    unawaited(_resolve());
    return _session!;
  }

  @override
  Future<void> syncVenue() async {
    final LiveSession? current = _session;
    if (current == null) {
      return;
    }
    // `_joinedVenue` is the server's normalised answer and `_venueCode()` is
    // already normalised by BackendConfig with the same rule, so this compares
    // like with like. Anything else would re-issue the session on every poll.
    final String wanted = _venueCode();
    if (wanted == _joinedVenue) {
      return;
    }
    final Duration left = current.remainingAt(DateTime.now());
    if (left.inSeconds < 60) {
      return;
    }
    try {
      final Map<String, dynamic> result = await _client.post(
        '/live/start',
        <String, dynamic>{
          'durationSeconds': left.inSeconds,
          if (wanted.isNotEmpty) 'venue': wanted,
        },
      );
      _joinedVenue = ApiMappers.string(result['venue']);
      final DateTime now = DateTime.now();
      _session = LiveSession(
        id: ApiMappers.string(result['sessionId']),
        // The clock keeps running: a new room is not more time. Re-anchoring
        // `startedAt` to now with the *remaining* duration keeps the countdown
        // and the radar sweep exactly where they were.
        startedAt: now,
        expiresAt: ApiMappers.dateTime(result['expiresAt'], now.add(left)),
      );
      // The old session's tokens died with it.
      _observedTokens.clear();
      _emitRoom(_joinedVenue, 0);
      await _resolve();
    } on ApiException catch (error) {
      _onError?.call(error);
    }
  }

  @override
  Future<void> stopLive() async {
    _poll?.cancel();
    _poll = null;
    _session = null;
    _observedTokens.clear();
    _joinedVenue = '';
    if (!_controller.isClosed) {
      _controller.add(const <NearbyPerson>[]);
    }
    _emitRoom('', 0);
    try {
      await _client.post('/live/stop');
    } on ApiException catch (_) {
      // The session expires on its own within the hour either way. Failing to
      // tell the server must not leave the app stuck in a Live state.
    }
  }

  @override
  Stream<List<NearbyPerson>> watchNearby() => _controller.stream;

  @override
  Stream<RoomStatus> watchRoom() => _room.stream;

  void _emitRoom(String code, int peers) {
    if (!_room.isClosed) {
      _room.add(RoomStatus(code: code, peers: peers));
    }
  }

  @override
  void simulateDiscovery() => unawaited(_resolve());

  Future<void> _resolve() async {
    if (_session == null || _inFlight) {
      return;
    }
    _inFlight = true;
    try {
      final Map<String, dynamic> result = await _client.post(
        '/nearby/resolve',
        <String, dynamic>{'tokens': _observedTokens.toList(growable: false)},
      );
      final List<NearbyPerson> people = ApiMappers.list(result['people'])
          .map(ApiMappers.nearbyPerson)
          .toList(growable: false);
      _onPeople?.call(people);
      if (!_controller.isClosed) {
        _controller.add(people);
      }
      // The server's own view of the room, not the phone's. If a restart lost
      // the session and the re-arm below put it back without a code, this is
      // what says so.
      _joinedVenue = ApiMappers.string(result['room']);
      _emitRoom(_joinedVenue, ApiMappers.integer(result['roomPeers']));
    } on ApiException catch (error) {
      if (error.code == 'not_live') {
        unawaited(_rearm());
      }
      _onError?.call(error);
    } finally {
      _inFlight = false;
    }
  }

  /// Goes live again for whatever time was left.
  ///
  /// Live sessions live in the server's memory, so restarting the server drops
  /// them — which during development happens constantly and looks, from the
  /// phone, like the app quietly breaking. One re-arm attempt fixes that
  /// silently. Exactly one: if the server refuses again the poll stops rather
  /// than hammering it, and the countdown expires on its own a moment later.
  Future<void> _rearm() async {
    final LiveSession? current = _session;
    if (current == null || _rearming) {
      return;
    }
    _rearming = true;
    try {
      final Duration left = current.remainingAt(DateTime.now());
      if (left.inSeconds < 60) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      final String venue = _venueCode();
      await _client.post(
        '/live/start',
        <String, dynamic>{
          'durationSeconds': left.inSeconds,
          if (venue.isNotEmpty) 'venue': venue,
        },
      );
    } on ApiException catch (_) {
      _poll?.cancel();
      _poll = null;
    } finally {
      _rearming = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _poll = null;
    _controller.close();
    _room.close();
  }
}
