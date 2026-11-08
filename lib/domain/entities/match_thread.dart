import 'package:flutter/foundation.dart';

import 'message.dart';
import 'reality_answer.dart';

/// Where a match stands between "you both sent UP" and a date.
///
/// Decided by the server (`date` in `GET /matches`); the phone only renders it.
enum DatePhase {
  /// Matched, nobody has replied yet. The clock has not started.
  waiting,

  /// Someone replied: the seven minutes are running.
  chatting,

  /// Time is up: meet, phone, or not a match.
  deciding,

  /// Both said yes — meet now.
  meet,

  /// Both asked to talk on the phone; numbers are shared.
  phone,

  /// Not a match (or it ran out). The room is open again.
  ended,

  /// Nobody answered in time. Still listed, no longer holding the room.
  stale;

  static DatePhase fromWire(String? value) {
    for (final DatePhase phase in DatePhase.values) {
      if (phase.name == value) {
        return phase;
      }
    }
    return DatePhase.waiting;
  }
}

/// The `date` block of a match.
@immutable
class DateInfo {
  const DateInfo({
    this.phase = DatePhase.waiting,
    this.canWrite = true,
    this.holdsRoom = false,
    this.chatStartedAt,
    this.chatEndsAt,
    this.decideBy,
    this.myChoice,
    this.theyChose = false,
    this.theirPhone,
  });

  final DatePhase phase;
  final bool canWrite;
  final bool holdsRoom;
  final DateTime? chatStartedAt;
  final DateTime? chatEndsAt;
  final DateTime? decideBy;

  /// 'meet' | 'phone' | 'no', or null.
  final String? myChoice;
  final bool theyChose;

  /// Only when both chose the phone.
  final String? theirPhone;
}

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
    this.date,
  });

  final String id;
  final String personId;
  final DateTime matchedAt;
  final List<Message> messages;
  final RealityAnswer? realityAnswer;
  final bool isUnread;

  /// Null on the mock stack and on an older server.
  final DateInfo? date;

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
    DateInfo? date,
  }) {
    return MatchThread(
      id: id,
      personId: personId,
      matchedAt: matchedAt,
      messages: messages ?? this.messages,
      realityAnswer: realityAnswer ?? this.realityAnswer,
      isUnread: isUnread ?? this.isUnread,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) => other is MatchThread && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
