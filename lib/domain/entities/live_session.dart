import 'package:flutter/foundation.dart';

/// A single explicit stretch of being discoverable.
///
/// Live is always bounded. There is no "always on" state in UP by design: the
/// session carries its own expiry, and the UI has no way to extend it silently.
@immutable
class LiveSession {
  const LiveSession({
    required this.id,
    required this.startedAt,
    required this.expiresAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime expiresAt;

  Duration remainingAt(DateTime now) {
    final Duration left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);

  Duration get totalDuration => expiresAt.difference(startedAt);

  /// Fraction of the session already spent, clamped to 0..1.
  double progressAt(DateTime now) {
    final int total = totalDuration.inMilliseconds;
    if (total <= 0) {
      return 1;
    }
    final int spent = now.difference(startedAt).inMilliseconds;
    return (spent / total).clamp(0.0, 1.0).toDouble();
  }

  static const List<Duration> selectableDurations = <Duration>[
    Duration(minutes: 30),
    Duration(minutes: 60),
    Duration(minutes: 120),
  ];
}
