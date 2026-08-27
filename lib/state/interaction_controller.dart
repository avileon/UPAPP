import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_interaction_repository.dart';
import '../domain/entities/match_thread.dart';
import '../domain/entities/reality_answer.dart';
import '../domain/repositories/interaction_repository.dart';

/// Likes, matches, chat and the safety actions.
class InteractionController extends ChangeNotifier {
  InteractionController({required InteractionRepository interactions})
      : _interactions = interactions {
    _matchSubscription = _interactions.watchMatches().listen(_onMatches);
  }

  final InteractionRepository _interactions;
  StreamSubscription<List<MatchThread>>? _matchSubscription;

  List<MatchThread> _matches = const <MatchThread>[];

  List<MatchThread> get matches => _matches;
  Set<String> get passedIds => _interactions.passedIds;
  Set<String> get blockedIds =>
      <String>{..._interactions.blockedIds, ..._blockedIdsPending};

  final Set<String> _blockedIdsPending = <String>{};
  Set<String> get incomingUpIds => _interactions.incomingUpIds;

  /// Why the last action failed, as the server's error code. Cleared by the
  /// next one.
  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;

  int get unreadCount =>
      _matches.where((MatchThread m) => m.isUnread).length;

  MatchThread? matchById(String matchId) {
    for (final MatchThread m in _matches) {
      if (m.id == matchId) {
        return m;
      }
    }
    return null;
  }

  MatchThread? matchForPerson(String personId) {
    for (final MatchThread m in _matches) {
      if (m.personId == personId) {
        return m;
      }
    }
    return null;
  }

  bool hasSentUpTo(String personId) =>
      matchForPerson(personId) != null || _sentUpIds.contains(personId);

  final Set<String> _sentUpIds = <String>{};

  Future<UpResult> sendUp(String personId) async {
    _lastErrorCode = null;
    UpResult result;
    try {
      result = await _interactions.sendUp(personId);
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      result = const UpResult(UpOutcome.failed);
    }
    if (result.outcome != UpOutcome.rateLimited &&
        result.outcome != UpOutcome.failed) {
      _sentUpIds.add(personId);
    }
    notifyListeners();
    return result;
  }

  void pass(String personId) {
    _interactions.pass(personId);
    notifyListeners();
  }

  Future<void> sendMessage(String matchId, String body) =>
      _guard(() => _interactions.sendMessage(matchId, body));

  Future<void> submitReality(String matchId, RealityAnswer answer) =>
      _guard(() => _interactions.submitRealityAnswer(matchId, answer));

  Future<void> unmatch(String matchId) =>
      _guard(() => _interactions.unmatch(matchId));

  Future<void> block(String personId) async {
    // The local set first, so the person disappears from the UI even if the
    // request never lands. A block the user asked for has to take effect on
    // their screen whatever the network is doing.
    _blockedIdsPending.add(personId);
    _sentUpIds.remove(personId);
    notifyListeners();
    await _guard(() => _interactions.block(personId));
  }

  Future<void> report(String personId) =>
      _guard(() => _interactions.report(personId));

  /// Runs an action and records why it failed instead of throwing.
  ///
  /// Every one of these is a button on a screen. An uncaught async error from
  /// a tap is a crash the user cannot report and a developer cannot see.
  Future<void> _guard(Future<void> Function() action) async {
    _lastErrorCode = null;
    try {
      await action();
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      notifyListeners();
    }
  }

  void markRead(String matchId) {
    // The server has no read receipts by design, so "read" is this device's
    // own note. Tell the repository too, or the next poll brings the badge
    // straight back.
    final InteractionRepository repository = _interactions;
    if (repository is ApiInteractionRepository) {
      repository.markRead(matchId);
    }
    final int index = _matches.indexWhere((MatchThread m) => m.id == matchId);
    if (index == -1 || !_matches[index].isUnread) {
      return;
    }
    final List<MatchThread> next = List<MatchThread>.of(_matches);
    next[index] = next[index].copyWith(isUnread: false);
    _matches = List<MatchThread>.unmodifiable(next);
    notifyListeners();
  }

  void simulateIncomingUp(String personId) {
    _interactions.simulateIncomingUp(personId);
    notifyListeners();
  }

  void reset() {
    _sentUpIds.clear();
    _blockedIdsPending.clear();
    _interactions.reset();
    notifyListeners();
  }

  void _onMatches(List<MatchThread> matches) {
    _matches = matches;
    notifyListeners();
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _matchSubscription = null;
    _interactions.dispose();
    super.dispose();
  }
}
