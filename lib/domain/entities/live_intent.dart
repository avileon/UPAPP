/// Why you are Live right now.
///
/// The single most important thing UP asks, and until now it never asked it.
/// Everyone was assumed to be looking for the same thing, so the app filtered
/// every room by gender preference — which is a rule that only makes sense if
/// the answer is romance, and which quietly made most of every room invisible
/// for everybody else.
///
/// Chosen per session, never stored on the profile. The same person wants a
/// running partner at seven in the morning and a date on Friday night, and an
/// app that makes them edit a profile to say so gets neither.
///
/// Four, and no more. Every extra option splits the room, and a room split
/// four ways in a bar holding twelve people already has three empty corners.
enum LiveIntent {
  /// The default, and the one this app is now about: meet whoever is around.
  meet('meet'),

  /// The only intent where "who are you interested in" filters anything.
  date('date'),

  work('work'),

  /// Something specific, now: a run, a coffee, a fourth for a game.
  doing('doing');

  const LiveIntent(this.wire);

  /// What the server calls it. Kept separate from the Dart name so renaming
  /// one never silently changes the protocol.
  final String wire;

  static LiveIntent fromWire(String? value) {
    for (final LiveIntent intent in LiveIntent.values) {
      if (intent.wire == value) {
        return intent;
      }
    }
    // An intent this build does not know about is not an error. A phone one
    // version behind must still be able to go Live.
    return LiveIntent.meet;
  }

  /// Whether gender preference decides who you see.
  ///
  /// Mirrored from `preferencesGateDiscovery` on the server, and the server is
  /// the one that enforces it — this exists so the app can *explain* the rule
  /// on the screen where it is chosen, which is the only place a person can
  /// act on knowing it.
  bool get preferencesApply => this == LiveIntent.date;
}
