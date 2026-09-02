import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../domain/entities/match_thread.dart';
import '../domain/entities/message.dart';
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

  /// A message that has just arrived from the other person, for whoever is
  /// willing to say so on screen.
  ///
  /// A badge answers "is there something?" and nothing else. It cannot say who
  /// wrote, and on a tab you are not looking at it cannot even get your
  /// attention — which is the whole complaint it was built to answer. This
  /// stream carries the arrival itself so the shell can put a name in front of
  /// you and offer to open it.
  Stream<MatchThread> get arrivals => _arrivals.stream;
  final StreamController<MatchThread> _arrivals =
      StreamController<MatchThread>.broadcast();

  /// The thread currently on screen, if any.
  ///
  /// Two things need it: a message arriving in the open conversation must be
  /// marked read rather than counted (you are looking straight at it), and it
  /// must not raise a banner over the very chat it belongs to.
  String? get openMatchId => _openMatchId;
  String? _openMatchId;

  void openThread(String matchId) {
    _openMatchId = matchId;
    markRead(matchId);
  }

  void closeThread(String matchId) {
    if (_openMatchId == matchId) {
      _openMatchId = null;
    }
  }

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
    // own note. The repository owns it — it is the thing that persists it and
    // the thing the next poll asks.
    _interactions.markRead(matchId);
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
    final List<MatchThread> arrived = _incomingSince(_matches, matches);
    _matches = matches;
    for (final MatchThread thread in arrived) {
      if (thread.id == _openMatchId) {
        // You are reading it. Counting it as unread would leave a badge behind
        // for a message you watched arrive.
        markRead(thread.id);
        continue;
      }
      if (!_arrivals.isClosed) {
        _arrivals.add(thread);
      }
    }
    notifyListeners();
  }

  /// Threads whose newest message is from the other person and is one we had
  /// not seen in the previous list.
  ///
  /// Keyed on the message id rather than on a count, so a thread that both
  /// gained and lost a message between two polls does not slip through, and a
  /// re-emission of an unchanged list announces nothing. The very first list
  /// after signing in announces nothing either: everything in it is new to
  /// this object but none of it just happened, and a fistful of banners on
  /// launch is noise, not news.
  List<MatchThread> _incomingSince(
    List<MatchThread> before,
    List<MatchThread> after,
  ) {
    if (!_seenFirstList) {
      _seenFirstList = true;
      return const <MatchThread>[];
    }
    final Map<String, String?> lastSeen = <String, String?>{
      for (final MatchThread thread in before)
        thread.id: thread.lastMessage?.id,
    };
    final List<MatchThread> arrived = <MatchThread>[];
    for (final MatchThread thread in after) {
      final Message? last = thread.lastMessage;
      if (last == null || last.isMine) {
        continue;
      }
      if (!lastSeen.containsKey(thread.id)) {
        // A thread that appeared with a message already in it — a match made
        // by someone who then wrote before our next poll.
        arrived.add(thread);
        continue;
      }
      if (lastSeen[thread.id] != last.id) {
        arrived.add(thread);
      }
    }
    return arrived;
  }

  bool _seenFirstList = false;

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _matchSubscription = null;
    _arrivals.close();
    _interactions.dispose();
    super.dispose();
  }
}
