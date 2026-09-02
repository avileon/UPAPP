import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How much of each thread this device has already seen.
///
/// Unread is a *client* fact here. The server has no read receipts by design —
/// "seen at 23:41" costs the people using this something and buys them
/// nothing — so the only place that knows a thread was opened is the device
/// that opened it. Which means that when this lived in memory alone, every
/// browser refresh threw the knowledge away and the app announced fourteen
/// unread conversations that had all been read days ago. A badge that is
/// always on is the same as no badge at all: after the second time, nobody
/// looks at it, and then the one message that mattered goes unseen too.
///
/// One key holding a JSON object, written whole. The map is a handful of
/// integers — a thread id against the number of messages that had been seen —
/// so there is nothing here worth the complexity of a real store, and writing
/// it whole means it can never be half-updated.
class ReadStateStore {
  ReadStateStore({this.namespace = 'default'});

  /// Keeps one account's read state off another's on a shared browser.
  ///
  /// Two people signing into the same laptop must not inherit each other's
  /// badges — and the same person on two servers is two different sets of
  /// threads whose ids may well collide.
  final String namespace;

  String get _key => 'up.readUpTo.$namespace';

  /// A store that hangs must not hold up the app; losing this costs one
  /// unnecessary badge, never a message.
  static const Duration _timeout = Duration(seconds: 3);

  final Map<String, int> _readUpTo = <String, int>{};
  bool _loaded = false;

  Map<String, int> get entries => Map<String, int>.unmodifiable(_readUpTo);

  bool contains(String matchId) => _readUpTo.containsKey(matchId);

  int? operator [](String matchId) => _readUpTo[matchId];

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance().timeout(_timeout);
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      decoded.forEach((String matchId, Object? value) {
        if (value is int && value >= 0) {
          _readUpTo[matchId] = value;
        }
      });
    } catch (_) {
      // Unreadable or absent is a first run, not an error.
    }
  }

  /// Never moves backwards: a poll that arrives with a shorter thread than the
  /// one already seen (a deleted message, a partial response) must not turn a
  /// read conversation unread again.
  void mark(String matchId, int seen) {
    final int? current = _readUpTo[matchId];
    if (current != null && current >= seen) {
      return;
    }
    _readUpTo[matchId] = seen;
    unawaited(_persist());
  }

  /// Drops threads that no longer exist, so an unmatch does not leave a row
  /// here for the rest of the install's life.
  void retainOnly(Iterable<String> matchIds) {
    final Set<String> live = matchIds.toSet();
    final int before = _readUpTo.length;
    _readUpTo.removeWhere((String id, _) => !live.contains(id));
    if (_readUpTo.length != before) {
      unawaited(_persist());
    }
  }

  void clear() {
    _readUpTo.clear();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance().timeout(_timeout);
      await prefs.setString(_key, jsonEncode(_readUpTo));
    } catch (_) {
      // Best effort. The in-memory map is still correct for this session.
    }
  }
}
