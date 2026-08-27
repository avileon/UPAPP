import 'dart:async';

import '../../domain/entities/match_thread.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/reality_answer.dart';
import '../../domain/repositories/interaction_repository.dart';
import 'api_client.dart';
import 'api_mappers.dart';

/// Likes, matches, chat and safety, against the real server.
///
/// Polling rather than a socket, deliberately and temporarily: a WebSocket is
/// the right answer and it is the next piece of work, but it is also the piece
/// that fails silently on a flaky tunnel. Polling gets two phones talking
/// today, and the seam it hides behind — [watchMatches] — is the same one the
/// socket will push into.
class ApiInteractionRepository implements InteractionRepository {
  ApiInteractionRepository({
    required ApiClient client,
    void Function(Iterable<NearbyPerson> people)? onPeople,
  })  : _client = client,
        _onPeople = onPeople;

  final ApiClient _client;
  final void Function(Iterable<NearbyPerson> people)? _onPeople;

  final StreamController<List<MatchThread>> _matchController =
      StreamController<List<MatchThread>>.broadcast();

  final Set<String> _passedIds = <String>{};
  final Set<String> _blockedIds = <String>{};
  /// How many messages this device had seen the last time each thread was
  /// opened. Absent means never opened.
  final Map<String, int> _readUpTo = <String, int>{};

  List<MatchThread> _matches = const <MatchThread>[];
  Timer? _poll;
  bool _inFlight = false;

  static const Duration _pollInterval = Duration(seconds: 5);

  /// Starts the poll. Called once the app has a signed-in session.
  void startPolling() {
    if (_poll != null) {
      return;
    }
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  Set<String> get passedIds => Set<String>.unmodifiable(_passedIds);

  @override
  Set<String> get blockedIds => Set<String>.unmodifiable(_blockedIds);

  /// Always empty, and that is the feature.
  ///
  /// The server has no endpoint that reveals a pending one-way UP — not one
  /// that filters it out, one that does not exist. An app that could show
  /// "someone likes you" would turn a private signal into leverage.
  @override
  Set<String> get incomingUpIds => const <String>{};

  @override
  List<MatchThread> get matches => _matches;

  @override
  Stream<List<MatchThread>> watchMatches() => _matchController.stream;

  @override
  Future<UpResult> sendUp(String personId) async {
    try {
      final Map<String, dynamic> result =
          await _client.post('/likes/$personId');
      final String outcome = ApiMappers.string(result['outcome']);
      final Map<String, dynamic> match = ApiMappers.map(result['match']);

      if (outcome == 'matched' && match.isNotEmpty) {
        // Pull the real thread rather than synthesising one, so the match the
        // UI opens is the same object every later poll will update.
        await refresh();
        final MatchThread? thread = _matchById(ApiMappers.string(match['id']));
        return UpResult(UpOutcome.matched, thread);
      }
      if (outcome == 'duplicate') {
        return const UpResult(UpOutcome.duplicate);
      }
      return const UpResult(UpOutcome.recorded);
    } on ApiException catch (error) {
      if (error.isRateLimited) {
        return const UpResult(UpOutcome.rateLimited);
      }
      if (error.code == 'blocked') {
        return const UpResult(UpOutcome.duplicate);
      }
      rethrow;
    }
  }

  /// Local and stays local. A pass is not an event anyone else is entitled to.
  @override
  void pass(String personId) => _passedIds.add(personId);

  @override
  Future<void> sendMessage(String matchId, String body) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _client.post(
      '/matches/$matchId/messages',
      <String, dynamic>{
        'body': trimmed.length > Message.maxLength
            ? trimmed.substring(0, Message.maxLength)
            : trimmed,
      },
    );
    await refresh();
  }

  @override
  Future<void> submitRealityAnswer(
    String matchId,
    RealityAnswer answer,
  ) async {
    try {
      await _client.post(
        '/matches/$matchId/reality-feedback',
        <String, dynamic>{'answer': ApiMappers.realityAnswerKey(answer)},
      );
    } on ApiException catch (error) {
      // Answering twice is refused by design; from the UI's point of view the
      // answer is already in and the prompt should close either way.
      if (error.code != 'already_answered') {
        rethrow;
      }
    }
    await refresh();
  }

  @override
  Future<void> unmatch(String matchId) async {
    await _client.post('/matches/$matchId/unmatch');
    await refresh();
  }

  @override
  Future<void> block(String personId) async {
    _blockedIds.add(personId);
    await _client.post('/users/$personId/block');
    await refresh();
  }

  @override
  Future<void> report(String personId) async {
    await _client.post(
      '/users/$personId/report',
      <String, dynamic>{'category': 'other'},
    );
  }

  /// Nothing to simulate against a real server — the other phone is real.
  @override
  void simulateIncomingUp(String personId) {}

  @override
  void reset() {
    _passedIds.clear();
    _blockedIds.clear();
    _readUpTo.clear();
    _matches = const <MatchThread>[];
    _emit();
  }

  /// Records that this device has now seen everything in [matchId].
  void markRead(String matchId) {
    _readUpTo[matchId] = _matchById(matchId)?.messages.length ?? 0;
  }

  /// One pass over `GET /matches`, plus the messages of each thread.
  ///
  /// Fetching every thread's messages on every tick is fine at the scale a
  /// person actually has matches, and it keeps the chat screen correct without
  /// a notion of "the open thread" leaking down into the data layer.
  Future<void> refresh() async {
    if (_inFlight) {
      return;
    }
    _inFlight = true;
    try {
      final Map<String, dynamic> result = await _client.get('/matches');
      final List<Map<String, dynamic>> raw = ApiMappers.list(result['matches']);
      final DateTime now = DateTime.now();

      final List<NearbyPerson> people = <NearbyPerson>[];
      final List<MatchThread> threads = <MatchThread>[];

      for (final Map<String, dynamic> json in raw) {
        final String id = ApiMappers.string(json['id']);
        if (id.isEmpty) {
          continue;
        }
        final Map<String, dynamic> person = ApiMappers.map(json['person']);
        if (person.isNotEmpty) {
          people.add(ApiMappers.nearbyPerson(person));
        }

        final List<Message> messages = await _messagesFor(id, now);
        threads.add(
          ApiMappers.matchThread(
            json,
            messages: messages,
            isUnread: _isUnread(id, messages),
            fallbackTime: now,
          ),
        );
      }

      _onPeople?.call(people);
      _matches = List<MatchThread>.unmodifiable(threads);
      _emit();
    } on ApiException catch (_) {
      // A dropped tunnel must not empty the list that is already on screen.
    } finally {
      _inFlight = false;
    }
  }

  Future<List<Message>> _messagesFor(String matchId, DateTime now) async {
    try {
      final Map<String, dynamic> result =
          await _client.get('/matches/$matchId/messages');
      return ApiMappers.list(result['messages'])
          .map((Map<String, dynamic> json) => ApiMappers.message(json, now))
          .toList(growable: false);
    } on ApiException {
      return const <Message>[];
    }
  }

  /// Unread state is the client's own bookkeeping.
  ///
  /// The server has no read receipts, and it should not: "seen at 23:41" is a
  /// feature that costs people something and buys them nothing here. A thread
  /// is unread when it has never been opened, or has grown since it was.
  bool _isUnread(String matchId, List<Message> messages) {
    if (messages.isEmpty) {
      // A brand-new match with nothing said yet is itself the thing to look at.
      return !_readUpTo.containsKey(matchId);
    }
    // Your own message never makes a thread unread. Stating it this way also
    // removes a race: sending a message and re-reading the thread no longer
    // have to happen in a particular order.
    if (messages.last.isMine) {
      return false;
    }
    final int? readUpTo = _readUpTo[matchId];
    return readUpTo == null || messages.length > readUpTo;
  }

  MatchThread? _matchById(String id) {
    for (final MatchThread thread in _matches) {
      if (thread.id == id) {
        return thread;
      }
    }
    return null;
  }

  void _emit() {
    if (!_matchController.isClosed) {
      _matchController.add(_matches);
    }
  }

  @override
  void dispose() {
    stopPolling();
    _matchController.close();
  }
}
