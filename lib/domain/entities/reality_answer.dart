/// The Reality Check answer set.
///
/// Three options, and none of them is about attractiveness. The moment this
/// enum grows a "hot / not" axis the feature has become a rating system and
/// stops being defensible — keep it about photo honesty only.
enum RealityAnswer {
  yes,
  somewhat,
  no;

  /// Only [yes] counts toward the badge. [somewhat] is neutral rather than
  /// negative: people photograph differently, and one soft answer should not
  /// punish anyone.
  bool get countsPositive => this == RealityAnswer.yes;
}

/// Server-side badge rules, kept here so the UI and the future backend agree
/// on one definition.
abstract final class RealityBadgeRules {
  /// Below this many eligible answers there is no badge at all — a single
  /// opinion is noise, and showing it would make the badge gameable.
  static const int minimumAnswers = 3;

  /// Share of positive answers required.
  static const double positiveThreshold = 0.7;

  static bool qualifies({required int total, required int positive}) {
    if (total < minimumAnswers) {
      return false;
    }
    return positive / total >= positiveThreshold;
  }
}
