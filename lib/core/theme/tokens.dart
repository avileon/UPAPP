/// Design tokens. Every spacing, radius and duration in the app comes from
/// here — no magic numbers inside widgets.
library;

abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 32;

  /// Horizontal padding of every full-screen surface.
  static const double screen = 22;
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 520);

  /// One radar sweep.
  static const Duration sweep = Duration(milliseconds: 3400);
}

abstract final class Sizes {
  static const double touchTarget = 48;
  static const double goLiveDiameter = 132;
  static const double radarDiameter = 250;
  static const double avatarSm = 52;
  static const double upButton = 80;
  static const double passButton = 60;
}
