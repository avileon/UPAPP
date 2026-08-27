import '../entities/match_thread.dart';
import '../entities/reality_answer.dart';

/// The result of pressing UP.
enum UpOutcome {
  /// One-way like recorded. The other side is not told.
  recorded,

  /// They had already sent one — a match exists now.
  matched,

  /// Already sent earlier; nothing changed.
  duplicate,

  /// Blocked by the rate limiter.
  rateLimited,
}

class UpResult {
  const UpResult(this.outcome, [this.match]);

  final UpOutcome outcome;
  final MatchThread? match;
}

abstract interface class InteractionRepository {
  /// Maps to `POST /likes/:userId`.
  Future<UpResult> sendUp(String personId);

  /// Local-only. A pass hides someone for the rest of this live session and is
  /// never reported to them.
  void pass(String personId);

  Set<String> get passedIds;

  /// Maps to `GET /matches`.
  List<MatchThread> get matches;

  Stream<List<MatchThread>> watchMatches();

  /// Maps to `POST /matches/:id/messages`.
  Future<void> sendMessage(String matchId, String body);

  /// Maps to `POST /matches/:id/reality-feedback`.
  Future<void> submitRealityAnswer(String matchId, RealityAnswer answer);

  /// Maps to `POST /matches/:id/unmatch`.
  Future<void> unmatch(String matchId);

  /// Maps to `POST /users/:id/block`.
  Future<void> block(String personId);

  /// Maps to `POST /users/:id/report`.
  Future<void> report(String personId);

  Set<String> get blockedIds;

  /// People who sent us an UP that we have not answered. Never surfaced as a
  /// notification before we have also sent one — see [InteractionRepository]
  /// docs in NEXT_MILESTONE.md for why.
  Set<String> get incomingUpIds;

  /// Test and demo hook.
  void simulateIncomingUp(String personId);

  void reset();

  void dispose();
}
