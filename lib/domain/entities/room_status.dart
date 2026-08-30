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
@immutable
class RoomStatus {
  const RoomStatus({required this.code, required this.peers});

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
      other is RoomStatus && other.code == code && other.peers == peers;

  @override
  int get hashCode => Object.hash(code, peers);

  @override
  String toString() => 'RoomStatus($code, peers: $peers)';
}
