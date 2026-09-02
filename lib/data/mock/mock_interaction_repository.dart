import 'dart:async';

import '../../domain/entities/match_thread.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/reality_answer.dart';
import '../../domain/repositories/interaction_repository.dart';
import 'mock_data.dart';

/// In-memory likes, matches, chat and safety actions.
///
/// The match rule lives here rather than in any widget, and it is the one piece
/// of Milestone 1 logic that must survive unchanged into the backend: a match
/// exists exactly once per pair, created only when both sides have an active
/// like.
class MockInteractionRepository implements InteractionRepository {
  MockInteractionRepository({
    String Function()? localeCode,
    DateTime Function()? now,
  })  : _localeCode = localeCode ?? _defaultLocale,
        _now = now ?? DateTime.now;

  final String Function() _localeCode;
  final DateTime Function() _now;

  static String _defaultLocale() => 'he';

  final Set<String> _sentUpIds = <String>{};
  final Set<String> _incomingUpIds = <String>{};
  final Set<String> _passedIds = <String>{};
  final Set<String> _blockedIds = <String>{};
  final List<MatchThread> _matches = <MatchThread>[];
  final List<Timer> _pendingReplies = <Timer>[];

  final StreamController<List<MatchThread>> _matchController =
      StreamController<List<MatchThread>>.broadcast();

  /// Deliberately low. An UP is cheap to send and expensive to receive, so the
  /// server caps it long before it becomes a harassment tool.
  static const int maxUpsPerSession = 40;

  static const Duration _replyDelay = Duration(milliseconds: 1100);

  @override
  Set<String> get passedIds => Set<String>.unmodifiable(_passedIds);

  @override
  Set<String> get blockedIds => Set<String>.unmodifiable(_blockedIds);

  @override
  Set<String> get incomingUpIds => Set<String>.unmodifiable(_incomingUpIds);

  Set<String> get sentUpIds => Set<String>.unmodifiable(_sentUpIds);

  @override
  List<MatchThread> get matches => List<MatchThread>.unmodifiable(_matches);

  @override
  Stream<List<MatchThread>> watchMatches() => _matchController.stream;

  @override
  Future<UpResult> sendUp(String personId) async {
    if (_blockedIds.contains(personId)) {
      return const UpResult(UpOutcome.duplicate);
    }
    if (_sentUpIds.contains(personId)) {
      return const UpResult(UpOutcome.duplicate);
    }
    if (_sentUpIds.length >= maxUpsPerSession) {
      return const UpResult(UpOutcome.rateLimited);
    }

    _sentUpIds.add(personId);

    if (_incomingUpIds.contains(personId)) {
      final MatchThread match = _createMatch(personId);
      return UpResult(UpOutcome.matched, match);
    }
    return const UpResult(UpOutcome.recorded);
  }

  /// The unique-per-pair guard. In Postgres this is a unique constraint on the
  /// ordered pair; here it is a lookup, and the test suite holds it honest.
  MatchThread _createMatch(String personId) {
    _incomingUpIds.remove(personId);
    final int existing =
        _matches.indexWhere((MatchThread m) => m.personId == personId);
    if (existing != -1) {
      return _matches[existing];
    }
    final DateTime at = _now();
    final MatchThread match = MatchThread(
      id: 'match-$personId',
      personId: personId,
      matchedAt: at,
    );
    _matches.insert(0, match);
    _emitMatches();
    return match;
  }

  @override
  void pass(String personId) {
    _passedIds.add(personId);
  }

  @override
  Future<void> sendMessage(String matchId, String body) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final int index = _matches.indexWhere((MatchThread m) => m.id == matchId);
    if (index == -1) {
      return;
    }

    final MatchThread thread = _matches[index];
    final List<Message> messages = <Message>[
      ...thread.messages,
      Message(
        id: '${matchId}-${thread.messages.length}',
        body: trimmed.length > Message.maxLength
            ? trimmed.substring(0, Message.maxLength)
            : trimmed,
        isMine: true,
        sentAt: _now(),
      ),
    ];
    _matches[index] = thread.copyWith(messages: messages, isUnread: false);
    _emitMatches();

    _scheduleReply(matchId);
  }

  /// Milestone 1 only: the other side answers so chat can be demoed on one
  /// phone. Milestone 2 replaces this with a WebSocket event.
  void _scheduleReply(String matchId) {
    final Timer timer = Timer(_replyDelay, () {
      final int index = _matches.indexWhere((MatchThread m) => m.id == matchId);
      if (index == -1) {
        return;
      }
      final MatchThread thread = _matches[index];
      final List<String> replies = MockData.repliesFor(_localeCode());
      final int replyIndex =
          (thread.messages.length ~/ 2).clamp(0, replies.length - 1).toInt();
      _matches[index] = thread.copyWith(
        messages: <Message>[
          ...thread.messages,
          Message(
            id: '$matchId-${thread.messages.length}',
            body: replies[replyIndex],
            isMine: false,
            sentAt: _now(),
          ),
        ],
      );
      _emitMatches();
    });
    _pendingReplies.add(timer);
  }

  @override
  Future<void> submitRealityAnswer(
    String matchId,
    RealityAnswer answer,
  ) async {
    final int index = _matches.indexWhere((MatchThread m) => m.id == matchId);
    if (index == -1) {
      return;
    }
    _matches[index] = _matches[index].copyWith(realityAnswer: answer);
    _emitMatches();
  }

  @override
  Future<void> unmatch(String matchId) async {
    _matches.removeWhere((MatchThread m) => m.id == matchId);
    _emitMatches();
  }

  @override
  Future<void> block(String personId) async {
    _blockedIds.add(personId);
    _sentUpIds.remove(personId);
    _incomingUpIds.remove(personId);
    _matches.removeWhere((MatchThread m) => m.personId == personId);
    _emitMatches();
  }

  @override
  Future<void> report(String personId) async {
    // Milestone 2 posts to the moderation queue. Reporting does not block on
    // its own — the two actions are separate on purpose so a report is cheap.
  }

  @override
  void simulateIncomingUp(String personId) {
    if (_blockedIds.contains(personId)) {
      return;
    }
    if (_sentUpIds.contains(personId)) {
      _createMatch(personId);
      return;
    }
    _incomingUpIds.add(personId);
  }

  /// The mock threads live in this list, so "read" is just a flag on one.
  @override
  void markRead(String matchId) {
    final int index = _matches.indexWhere((MatchThread m) => m.id == matchId);
    if (index == -1 || !_matches[index].isUnread) {
      return;
    }
    _matches[index] = _matches[index].copyWith(isUnread: false);
    _emitMatches();
  }

  @override
  void reset() {
    _sentUpIds.clear();
    _incomingUpIds.clear();
    _passedIds.clear();
    _blockedIds.clear();
    _matches.clear();
    _emitMatches();
  }

  void _emitMatches() {
    if (_matchController.isClosed) {
      return;
    }
    _matchController.add(List<MatchThread>.unmodifiable(_matches));
  }

  @override
  void dispose() {
    for (final Timer timer in _pendingReplies) {
      timer.cancel();
    }
    _pendingReplies.clear();
    _matchController.close();
  }
}
