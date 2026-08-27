import 'package:flutter/foundation.dart';

@immutable
class Message {
  const Message({
    required this.id,
    required this.body,
    required this.isMine,
    required this.sentAt,
  });

  final String id;
  final String body;
  final bool isMine;
  final DateTime sentAt;

  /// Text only in Milestone 1 — and in the MVP. Images would pull in a whole
  /// moderation pipeline before there is a single real user.
  static const int maxLength = 1000;

  @override
  bool operator ==(Object other) => other is Message && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
