import 'package:flutter/foundation.dart';

import 'message.dart';
import 'reality_answer.dart';

/// A mutual UP, plus everything that hangs off it.
@immutable
class MatchThread {
  const MatchThread({
    required this.id,
    required this.personId,
    required this.matchedAt,
    this.messages = const <Message>[],
    this.realityAnswer,
    this.isUnread = true,
  });

  final String id;
  final String personId;
  final DateTime matchedAt;
  final List<Message> messages;
  final RealityAnswer? realityAnswer;
  final bool isUnread;

  bool get hasMessages => messages.isNotEmpty;

  Message? get lastMessage => messages.isEmpty ? null : messages.last;

  /// When this thread last did anything — the ordering key for the chat list.
  ///
  /// A thread with no messages is still an event: the match itself. Falling
  /// back to [matchedAt] is what keeps a brand-new match at the top of the
  /// list instead of at the bottom, where it reads as the oldest thing there.
  DateTime get lastActivityAt => lastMessage?.sentAt ?? matchedAt;

  /// True when the other person spoke last — the thread is waiting on you.
  bool get awaitingReply => lastMessage != null && !lastMessage!.isMine;

  /// Reality Check is offered only once a match has actually turned into a
  /// conversation — a mutual UP alone is not evidence anyone met in person.
  static const int messagesBeforeRealityCheck = 4;

  bool get isEligibleForRealityCheck =>
      realityAnswer == null && messages.length >= messagesBeforeRealityCheck;

  MatchThread copyWith({
    List<Message>? messages,
    RealityAnswer? realityAnswer,
    bool? isUnread,
  }) {
    return MatchThread(
      id: id,
      personId: personId,
      matchedAt: matchedAt,
      messages: messages ?? this.messages,
      realityAnswer: realityAnswer ?? this.realityAnswer,
      isUnread: isUnread ?? this.isUnread,
    );
  }

  @override
  bool operator ==(Object other) => other is MatchThread && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
