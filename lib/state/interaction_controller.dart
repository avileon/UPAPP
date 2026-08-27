import 'dart:async';

import 'package:flutter/foundation.dart';

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
  Set<String> get blockedIds => _interactions.blockedIds;
  Set<String> get incomingUpIds => _interactions.incomingUpIds;

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
    final UpResult result = await _interactions.sendUp(personId);
    if (result.outcome != UpOutcome.rateLimited) {
      _sentUpIds.add(personId);
    }
    notifyListeners();
    return result;
  }

  void pass(String personId) {
    _interactions.pass(personId);
    notifyListeners();
  }

  Future<void> sendMessage(String matchId, String body) async {
    await _interactions.sendMessage(matchId, body);
  }

  Future<void> submitReality(String matchId, RealityAnswer answer) =>
      _interactions.submitRealityAnswer(matchId, answer);

  Future<void> unmatch(String matchId) => _interactions.unmatch(matchId);

  Future<void> block(String personId) async {
    await _interactions.block(personId);
    _sentUpIds.remove(personId);
    notifyListeners();
  }

  Future<void> report(String personId) => _interactions.report(personId);

  void markRead(String matchId) {
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
