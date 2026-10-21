import 'dart:async';

import '../../domain/entities/geo_fix.dart';
import '../../domain/entities/live_intent.dart';
import '../../domain/entities/live_session.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/room_status.dart';
import '../../domain/repositories/presence_repository.dart';
import 'api_client.dart';
import 'api_mappers.dart';

/// Going Live and discovering people, against the real server.
///
/// Three ways to be Live, all decided by the server:
///
/// - **At a venue**: the code from the place's QR plus a location fix inside
///   it. One hour, then scan again.
/// - **In the area**: a location fix; everyone else in area mode nearby. The
///   fix is refreshed while the session runs, so walking across town changes
///   who you see.
/// - **Radio only**: neither — the BLE path, for the native app.
class ApiPresenceRepository implements PresenceRepository {
  ApiPresenceRepository({
    required ApiClient client,
    Future<GeoFix?> Function()? locate,
    void Function(Iterable<NearbyPerson> people)? onPeople,
    void Function(Object error)? onError,
  })  : _client = client,
        _locate = locate,
        _onPeople = onPeople,
        _onError = onError;

  final ApiClient _client;

  /// Reads the phone's location for area mode. Null when there is no way to.
  final Future<GeoFix?> Function()? _locate;
  final void Function(Iterable<NearbyPerson> people)? _onPeople;
  final void Function(Object error)? _onError;

  final StreamController<List<NearbyPerson>> _controller =
      StreamController<List<NearbyPerson>>.broadcast();

  final StreamController<RoomStatus> _room =
      StreamController<RoomStatus>.broadcast();

  /// Tokens heard off the air this session. Empty until the radio lands.
  final Set<String> _observedTokens = <String>{};

  Timer? _poll;
  LiveSession? _session;
  bool _inFlight = false;
  bool _rearming = false;

  /// What every re-issue of the session has to carry: a server restart drops
  /// sessions from memory, and the one silent re-arm below must put the person
  /// back where they were, not in a different room or intent.
  LiveIntent _intent = LiveIntent.meet;
  String _note = '';
  String _venue = '';
  GeoFix? _fix;

  /// The last time the area fix was refreshed.
  DateTime _fixAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _pollInterval = Duration(seconds: 5);

  /// How often area mode re-reads the location. Often enough that a walk to
  /// the next street counts, rarely enough not to drain a battery.
  static const Duration _fixInterval = Duration(seconds: 60);

  LiveSession? get session => _session;

  @override
  Future<LiveSession> startLive(
    Duration duration, {
    LiveIntent intent = LiveIntent.meet,
    String note = '',
    String venue = '',
    GeoFix? fix,
  }) async {
    final Map<String, dynamic> result = await _client.post(
      '/live/start',
      _startBody(duration.inSeconds, intent, note, venue, fix),
    );
    _intent = intent;
    _note = note;
    _venue = venue;
    _fix = fix;
    _fixAt = DateTime.now();

    final DateTime now = DateTime.now();
    _session = _sessionFrom(result, now, now.add(duration));
    _intent = _session!.intent;
    _observedTokens.clear();
    _controller.add(const <NearbyPerson>[]);
    _emitRoom(_session!.venueCode, 0, _session!.venueName);

    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_resolve()));
    unawaited(_resolve());
    return _session!;
  }

  LiveSession _sessionFrom(
    Map<String, dynamic> result,
    DateTime now,
    DateTime fallbackExpiry,
  ) {
    return LiveSession(
      id: ApiMappers.string(result['sessionId']),
      startedAt: now,
      expiresAt: ApiMappers.dateTime(result['expiresAt'], fallbackExpiry),
      // What the server recorded, not what we asked for.
      intent: LiveIntent.fromWire(ApiMappers.string(result['intent'])),
      note: ApiMappers.string(result['note']),
      venueCode: ApiMappers.string(result['venue']),
      venueName: ApiMappers.string(result['venueName']),
      isArea: ApiMappers.string(result['mode']) == 'area',
    );
  }

  /// Venues are joined explicitly now (scan → location → join), so there is
  /// no saved code to move a running session into.
  @override
  Future<void> syncVenue() async {}

  /// One shape for every `/live/start`, so no path can forget a field.
  Map<String, dynamic> _startBody(
    int seconds,
    LiveIntent intent,
    String note,
    String venue,
    GeoFix? fix,
  ) =>
      <String, dynamic>{
        'durationSeconds': seconds,
        if (venue.isNotEmpty) 'venue': venue,
        if (venue.isEmpty && fix != null) 'mode': 'area',
        if (fix != null) ...fix.toJson(),
        'intent': intent.wire,
        if (note.isNotEmpty) 'note': note,
      };

  @override
  Future<List<RoomSummary>> rooms(LiveIntent intent) async {
    try {
      final Map<String, dynamic> result =
          await _client.get('/rooms?intent=${intent.wire}');
      return ApiMappers.list(result['rooms'])
          .map(
            (Map<String, dynamic> json) => RoomSummary(
              code: ApiMappers.string(json['code']),
              people: ApiMappers.integer(json['people']),
            ),
          )
          .toList(growable: false);
    } on ApiException catch (_) {
      return const <RoomSummary>[];
    }
  }

  @override
  Future<void> stopLive() async {
    _poll?.cancel();
    _poll = null;
    _session = null;
    _observedTokens.clear();
    _venue = '';
    _fix = null;
    if (!_controller.isClosed) {
      _controller.add(const <NearbyPerson>[]);
    }
    _emitRoom('', 0, '');
    try {
      await _client.post('/live/stop');
    } on ApiException catch (_) {
      // The session expires on its own either way. Failing to tell the server
      // must not leave the app stuck in a Live state.
    }
  }

  @override
  Stream<List<NearbyPerson>> watchNearby() => _controller.stream;

  @override
  Stream<RoomStatus> watchRoom() => _room.stream;

  void _emitRoom(String code, int peers, String name) {
    if (!_room.isClosed) {
      _room.add(RoomStatus(code: code, peers: peers, name: name));
    }
  }

  @override
  void simulateDiscovery() => unawaited(_resolve());

  /// Area mode only: a fresh fix every [_fixInterval]. A failed read keeps
  /// the last one — the server ignores a missing position rather than
  /// dropping anyone.
  Future<GeoFix?> _freshFix() async {
    final LiveSession? session = _session;
    final Future<GeoFix?> Function()? locate = _locate;
    if (session == null || !session.isArea || locate == null) {
      return null;
    }
    if (DateTime.now().difference(_fixAt) < _fixInterval) {
      return null;
    }
    _fixAt = DateTime.now();
    try {
      final GeoFix? fix = await locate();
      if (fix != null) {
        _fix = fix;
      }
      return fix;
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolve() async {
    if (_session == null || _inFlight) {
      return;
    }
    _inFlight = true;
    try {
      final GeoFix? fix = await _freshFix();
      final Map<String, dynamic> result = await _client.post(
        '/nearby/resolve',
        <String, dynamic>{
          'tokens': _observedTokens.toList(growable: false),
          if (fix != null) ...fix.toJson(),
        },
      );
      final List<NearbyPerson> people = ApiMappers.list(result['people'])
          .map(ApiMappers.nearbyPerson)
          .toList(growable: false);
      _onPeople?.call(people);
      if (!_controller.isClosed) {
        _controller.add(people);
      }
      _intent = LiveIntent.fromWire(ApiMappers.string(result['intent']));
      _emitRoom(
        ApiMappers.string(result['room']),
        ApiMappers.integer(result['roomPeers']),
        ApiMappers.string(result['roomName']),
      );
    } on ApiException catch (error) {
      if (error.code == 'not_live') {
        unawaited(_rearm());
      }
      _onError?.call(error);
    } finally {
      _inFlight = false;
    }
  }

  /// Goes live again for whatever time was left, exactly once.
  ///
  /// Live sessions live in the server's memory, so a restart drops them. A
  /// venue session re-arms with the fix it joined with; if the server refuses
  /// (the place was switched off, the fix is now too old) the poll stops and
  /// the countdown runs out on its own.
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
      await _client.post(
        '/live/start',
        _startBody(left.inSeconds, _intent, _note, _venue, _fix),
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
