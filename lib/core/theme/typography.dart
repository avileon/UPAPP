import 'package:flutter/material.dart';

/// The type scale.
///
/// Milestone 1 ships on the platform's own faces (SF on iOS, Roboto on
/// Android) so the project has no font assets and no download step. The scale,
/// weights and tracking below are what carry the personality; swapping in a
/// display face later is a change in this one file — see NEXT_MILESTONE.md.
abstract final class AppTypography {
  static const String? displayFamily = null;

  static TextTheme textTheme({
    required Color foreground,
    required Color muted,
  }) {
    TextStyle display(double size, {double tracking = -0.03}) => TextStyle(
          fontFamily: displayFamily,
          fontSize: size,
          height: 1.12,
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
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: foreground,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.16,
        color: foreground,
      ),

      // Running text.
      bodyLarge: TextStyle(
        fontSize: 15.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: foreground,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: muted,
      ),

      // Buttons.
      labelLarge: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: foreground,
      ),
      labelMedium: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),

      // Eyebrows and technical labels. Always uppercase at the call site.
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: muted,
      ),
    );
  }
}
