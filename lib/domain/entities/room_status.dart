import 'package:flutter/foundation.dart';

/// The room the live session actually joined, and who else is in it.
///
/// This exists because of a failure that cost an evening of testing: two phones
/// on the same code, both Live, and an empty list on both — with nothing on
/// screen to say which of the three possible reasons it was. The stored venue
/// code answers "what did I type"; this answers "what did the server put me
/// in", and those are different questions whenever the code was chosen after
/// Live had already started.
///
/// [peers] counts people, not identities: everyone in it typed the same code on
/// purpose, and a number carries nothing that could name them.
/// Tonight's UPs at this place: four, so you choose. Null on [RoomStatus]
/// means there is no limit (around me, or the server switched it off).
@immutable
class UpQuota {
  const UpQuota({required this.limit, required this.remaining});

  final int limit;
  final int remaining;

  bool get isSpent => remaining <= 0;

  UpQuota withRemaining(int value) =>
      UpQuota(limit: limit, remaining: value.clamp(0, limit));

  /// Reads the server's `upQuota` object; null when absent or no limit.
  static UpQuota? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? limit = raw['limit'];
    final Object? remaining = raw['remaining'];
    if (limit is! num || remaining is! num || limit <= 0) {
      return null;
    }
    return UpQuota(limit: limit.toInt(), remaining: remaining.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is UpQuota && other.limit == limit && other.remaining == remaining;

  @override
  int get hashCode => Object.hash(limit, remaining);
}

@immutable
class RoomStatus {
  const RoomStatus({
    required this.code,
    required this.peers,
    this.name = '',
    this.quota,
  });

  /// UPs left here tonight. Null = no limit.
  final UpQuota? quota;

  RoomStatus withQuota(UpQuota? value) =>
      RoomStatus(code: code, peers: peers, name: name, quota: value);

  /// The place's display name, e.g. "פאב הנמל". Empty outside a venue.
  final String name;

  /// The normalised key the server put this session in. Empty means the live
  /// session has no room at all.
  final String code;

  /// Other people live in the same room, before any preference or block
  /// filtering. Always at least as large as the visible list.
  final int peers;

  bool get isJoined => code.isNotEmpty;

  static const RoomStatus none = RoomStatus(code: '', peers: 0);

  @override
  bool operator ==(Object other) =>
      other is RoomStatus &&
      other.code == code &&
      other.peers == peers &&
      other.name == name &&
      other.quota == quota;

  @override
  int get hashCode => Object.hash(code, peers, name, quota);

  @override
  String toString() => 'RoomStatus($code, peers: $peers)';
}
