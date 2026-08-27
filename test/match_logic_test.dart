import 'package:flutter_test/flutter_test.dart';
import 'package:up/data/mock/mock_interaction_repository.dart';
import 'package:up/domain/entities/reality_answer.dart';
import 'package:up/domain/repositories/interaction_repository.dart';

/// The match rule is the one piece of Milestone 1 logic that must survive
/// unchanged into the backend, so it is tested here rather than demonstrated
/// by tapping through the UI.
void main() {
  late MockInteractionRepository repo;

  setUp(() {
    repo = MockInteractionRepository();
  });

  tearDown(() {
    repo.dispose();
  });

  group('sending an UP', () {
    test('a one-way UP does not create a match', () async {
      final UpResult result = await repo.sendUp('p1');

      expect(result.outcome, UpOutcome.recorded);
      expect(result.match, isNull);
      expect(repo.matches, isEmpty);
    });

    test('a mutual UP creates exactly one match', () async {
      repo.simulateIncomingUp('p1');
      final UpResult result = await repo.sendUp('p1');

      expect(result.outcome, UpOutcome.matched);
      expect(result.match, isNotNull);
      expect(repo.matches, hasLength(1));
      expect(repo.matches.single.personId, 'p1');
    });

    test('order does not matter — we UP first, they UP second', () async {
      await repo.sendUp('p2');
      expect(repo.matches, isEmpty);

      repo.simulateIncomingUp('p2');

      expect(repo.matches, hasLength(1));
      expect(repo.matches.single.personId, 'p2');
    });

    test('a repeated UP never produces a second match', () async {
      repo.simulateIncomingUp('p3');
      await repo.sendUp('p3');
      final UpResult again = await repo.sendUp('p3');

      expect(again.outcome, UpOutcome.duplicate);
      expect(repo.matches, hasLength(1));
    });

    test('UPs are rate limited', () async {
      for (int i = 0; i < MockInteractionRepository.maxUpsPerSession; i++) {
        await repo.sendUp('filler-$i');
      }
      final UpResult overflow = await repo.sendUp('one-too-many');

      expect(overflow.outcome, UpOutcome.rateLimited);
    });
  });

  group('safety', () {
    test('blocking removes the match and the pending like', () async {
      repo.simulateIncomingUp('p4');
      await repo.sendUp('p4');
      expect(repo.matches, hasLength(1));

      await repo.block('p4');

      expect(repo.matches, isEmpty);
      expect(repo.blockedIds, contains('p4'));
      expect(repo.incomingUpIds, isNot(contains('p4')));
    });

    test('a blocked person can never match again', () async {
      await repo.block('p5');
      repo.simulateIncomingUp('p5');
      final UpResult result = await repo.sendUp('p5');

      expect(result.outcome, UpOutcome.duplicate);
      expect(repo.matches, isEmpty);
    });

    test('a pass is local and does not reach the other side', () {
      repo.pass('p6');

      expect(repo.passedIds, contains('p6'));
      expect(repo.matches, isEmpty);
      expect(repo.incomingUpIds, isEmpty);
    });
  });

  group('reality check', () {
    test('is not offered before the match becomes a conversation', () async {
      repo.simulateIncomingUp('p7');
      await repo.sendUp('p7');

      expect(repo.matches.single.isEligibleForRealityCheck, isFalse);
    });

    test('an answer is recorded once', () async {
      repo.simulateIncomingUp('p8');
      final UpResult result = await repo.sendUp('p8');
      final String matchId = result.match!.id;

      await repo.submitRealityAnswer(matchId, RealityAnswer.yes);

      expect(repo.matches.single.realityAnswer, RealityAnswer.yes);
    });
  });

  group('badge rules', () {
    test('no badge below the minimum number of answers', () {
      expect(
        RealityBadgeRules.qualifies(total: 2, positive: 2),
        isFalse,
      );
    });

    test('a clear positive majority earns the badge', () {
      expect(
        RealityBadgeRules.qualifies(total: 5, positive: 4),
        isTrue,
      );
    });

    test('a single negative answer does not remove the badge', () {
      expect(
        RealityBadgeRules.qualifies(total: 10, positive: 9),
        isTrue,
      );
    });

    test('a weak majority does not earn the badge', () {
      expect(
        RealityBadgeRules.qualifies(total: 10, positive: 6),
        isFalse,
      );
    });
  });
}
