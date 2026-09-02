import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:up/domain/entities/match_thread.dart';
import 'package:up/domain/entities/message.dart';
import 'package:up/domain/entities/reality_answer.dart';
import 'package:up/domain/repositories/interaction_repository.dart';
import 'package:up/state/interaction_controller.dart';

/// Knowing that a message arrived, and from whom.
///
/// The bug this pins down was not that messages failed to arrive — they did,
/// every five seconds. It was that arriving was all they did. The list was
/// ordered by when each match was made, the only signal was a badge on a tab
/// you were not looking at, and a thread you had read came back unread on
/// every browser refresh. Three separate ways for one message to go unnoticed.
void main() {
  DateTime at(int minute) => DateTime(2026, 1, 1, 12, minute);

  Message theirs(String id, int minute) =>
      Message(id: id, body: id, isMine: false, sentAt: at(minute));

  Message mine(String id, int minute) =>
      Message(id: id, body: id, isMine: true, sentAt: at(minute));

  MatchThread thread(
    String id, {
    List<Message> messages = const <Message>[],
    bool isUnread = false,
  }) {
    return MatchThread(
      id: id,
      personId: 'p-$id',
      matchedAt: at(0),
      messages: messages,
      isUnread: isUnread,
    );
  }

  ({InteractionController controller, _FakeRepository repository}) build() {
    final _FakeRepository repository = _FakeRepository();
    final InteractionController controller =
        InteractionController(interactions: repository);
    addTearDown(controller.dispose);
    return (controller: controller, repository: repository);
  }

  test('the first list after signing in announces nothing', () async {
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    // Everything here is new to the app and none of it just happened. A
    // fistful of banners on launch is noise, not news.
    c.repository.emit(<MatchThread>[
      thread('a', messages: <Message>[theirs('m1', 1)]),
      thread('b', messages: <Message>[theirs('m2', 2)]),
    ]);
    await pumpEventQueue();

    expect(announced, isEmpty);
  });

  test('a message from the other person is announced with its thread',
      () async {
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.repository.emit(<MatchThread>[thread('a')]);
    await pumpEventQueue();

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    c.repository
        .emit(<MatchThread>[thread('a', messages: <Message>[theirs('m1', 3)])]);
    await pumpEventQueue();

    expect(announced.single.id, 'a');
    expect(announced.single.lastMessage?.id, 'm1');
  });

  test('your own message is not an arrival', () async {
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.repository.emit(<MatchThread>[thread('a')]);
    await pumpEventQueue();

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    c.repository
        .emit(<MatchThread>[thread('a', messages: <Message>[mine('m1', 3)])]);
    await pumpEventQueue();

    expect(announced, isEmpty);
  });

  test('the same list arriving twice announces nothing', () async {
    // The poll re-emits every five seconds whether or not anything changed.
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    final List<Message> messages = <Message>[theirs('m1', 1)];
    c.repository.emit(<MatchThread>[thread('a', messages: messages)]);
    await pumpEventQueue();

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    c.repository.emit(<MatchThread>[thread('a', messages: messages)]);
    c.repository.emit(<MatchThread>[thread('a', messages: messages)]);
    await pumpEventQueue();

    expect(announced, isEmpty);
  });

  test('a message in the open thread is marked read, not announced', () async {
    // You are looking straight at it. A banner over the conversation it
    // belongs to is absurd, and a badge for it is a lie.
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.repository.emit(<MatchThread>[thread('a')]);
    await pumpEventQueue();

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);
    c.controller.openThread('a');

    c.repository.emit(<MatchThread>[
      thread('a', messages: <Message>[theirs('m1', 3)], isUnread: true),
    ]);
    await pumpEventQueue();

    expect(announced, isEmpty);
    expect(c.repository.readIds, contains('a'));
    expect(c.controller.unreadCount, 0);
  });

  test('closing the thread lets the next message be announced again',
      () async {
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.repository.emit(<MatchThread>[thread('a')]);
    await pumpEventQueue();

    c.controller.openThread('a');
    c.controller.closeThread('a');

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    c.repository
        .emit(<MatchThread>[thread('a', messages: <Message>[theirs('m1', 3)])]);
    await pumpEventQueue();

    expect(announced.single.id, 'a');
  });

  test('a thread that appears already holding a message is an arrival',
      () async {
    // Someone matched and wrote inside the same poll window.
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.repository.emit(<MatchThread>[thread('a')]);
    await pumpEventQueue();

    final List<MatchThread> announced = <MatchThread>[];
    c.controller.arrivals.listen(announced.add);

    c.repository.emit(<MatchThread>[
      thread('a'),
      thread('b', messages: <Message>[theirs('m9', 4)]),
    ]);
    await pumpEventQueue();

    expect(announced.single.id, 'b');
  });

  test('marking read goes through the repository, not around it', () {
    // It used to be a cast to one implementation, so the mock stack silently
    // did nothing and the next poll brought every badge straight back.
    final ({InteractionController controller, _FakeRepository repository}) c =
        build();
    c.controller.markRead('a');
    expect(c.repository.readIds, <String>['a']);
  });

  group('the key the chat list is ordered by', () {
    test('is the last message when there is one', () {
      final MatchThread t =
          thread('a', messages: <Message>[theirs('m1', 1), mine('m2', 9)]);
      expect(t.lastActivityAt, at(9));
    });

    test('is the match itself when nothing has been said', () {
      // Otherwise a match made a minute ago sorts as the oldest thing in the
      // list, which is exactly where nobody looks for it.
      expect(thread('a').lastActivityAt, at(0));
    });

    test('says when the thread is waiting on you', () {
      expect(thread('a', messages: <Message>[theirs('m1', 1)]).awaitingReply,
          isTrue);
      expect(thread('a', messages: <Message>[mine('m1', 1)]).awaitingReply,
          isFalse);
      expect(thread('a').awaitingReply, isFalse);
    });
  });
}

class _FakeRepository implements InteractionRepository {
  final StreamController<List<MatchThread>> _controller =
      StreamController<List<MatchThread>>.broadcast();

  final List<String> readIds = <String>[];
  List<MatchThread> _matches = const <MatchThread>[];

  void emit(List<MatchThread> matches) {
    _matches = matches;
    _controller.add(matches);
  }

  @override
  List<MatchThread> get matches => _matches;

  @override
  Stream<List<MatchThread>> watchMatches() => _controller.stream;

  @override
  void markRead(String matchId) => readIds.add(matchId);

  @override
  Set<String> get passedIds => const <String>{};

  @override
  Set<String> get blockedIds => const <String>{};

  @override
  Set<String> get incomingUpIds => const <String>{};

  @override
  Future<UpResult> sendUp(String personId) async =>
      const UpResult(UpOutcome.recorded);

  @override
  void pass(String personId) {}

  @override
  Future<void> sendMessage(String matchId, String body) async {}

  @override
  Future<void> submitRealityAnswer(String matchId, RealityAnswer answer) async {}

  @override
  Future<void> unmatch(String matchId) async {}

  @override
  Future<void> block(String personId) async {}

  @override
  Future<void> report(String personId) async {}

  @override
  void simulateIncomingUp(String personId) {}

  @override
  void reset() {}

  @override
  void dispose() {
    _controller.close();
  }
}
