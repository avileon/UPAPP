import 'package:flutter/material.dart';

/// The type scale.
///
/// Two bundled faces, both with full Hebrew and Latin (assets/fonts, OFL):
///   * Rubik — display: the wordmark, headlines, the match moment.
///   * IBM Plex Sans Hebrew — everything people read.
/// Bundled rather than fetched so the web build renders the same on the first
/// frame as on Android, and needs no network for type.
abstract final class AppTypography {
  static const String displayFamily = 'Rubik';
  static const String bodyFamily = 'IBMPlexSansHebrew';

  static TextTheme textTheme({
    required Color foreground,
    required Color muted,
  }) {
    TextStyle display(double size, {double tracking = -0.03}) => TextStyle(
          fontFamily: displayFamily,
          fontSize: size,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: size * tracking,
          color: foreground,
        );

    return TextTheme(
      // Reserved for the wordmark and the match moment.
      displayLarge: display(64),
      displayMedium: display(38),

      headlineLarge: display(29),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: foreground,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.16,
        color: foreground,
      ),

      // Running text.
      bodyLarge: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 15.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: foreground,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 14.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: muted,
      ),

      // Buttons.
      labelLarge: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: foreground,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),

      // Eyebrows and technical labels. Always uppercase at the call site.
      labelSmall: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: muted,
      ),
    );
  }
}
