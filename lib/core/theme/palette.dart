import 'package:flutter/material.dart';

/// The UP palette — "Night Glow".
///
/// Two meanings, two hues, and they never swap roles:
///   * [cyan]  — the machine signal. Live, room, radar, verification. Drawn
///               as a mint glow.
///   * [amber] — the human moment. UP, match, warmth, the primary action.
///               Drawn as a hot pink. (The field names predate the colours;
///               they name the role, not the hue.)
///
/// Neutrals sit on a near-black with a violet bias so the dark theme reads as
/// a room at night, lit by the two accents.
@immutable
class UpPalette extends ThemeExtension<UpPalette> {
  const UpPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.foreground,
    required this.muted,
    required this.dim,
    required this.amber,
    required this.onAmber,
    required this.cyan,
    required this.onCyan,
    required this.danger,
    required this.ok,
    required this.glow,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color foreground;
  final Color muted;
  final Color dim;
  final Color amber;
  final Color onAmber;
  final Color cyan;
  final Color onCyan;
  final Color danger;
  final Color ok;
  final Color glow;

  static const UpPalette dark = UpPalette(
    background: Color(0xFF09080F),
    surface: Color(0xFF14121D),
    surfaceHigh: Color(0xFF1C1A28),
    line: Color(0xFF2A2738),
    foreground: Color(0xFFF5F3FA),
    muted: Color(0xFFA7A3B8),
    dim: Color(0xFF7D7891),
    amber: Color(0xFFFF4F7B),
    onAmber: Color(0xFF1A0710),
    cyan: Color(0xFF4DF2B0),
    onCyan: Color(0xFF062419),
    danger: Color(0xFFFF6B6B),
    ok: Color(0xFF4DF2B0),
    glow: Color(0x47FF4F7B),
  );

  static const UpPalette light = UpPalette(
    background: Color(0xFFF7F5FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEEEBF5),
    line: Color(0xFFDCD8E6),
    foreground: Color(0xFF14121D),
    muted: Color(0xFF5E5A70),
    dim: Color(0xFF8A86A0),
    amber: Color(0xFFD6245A),
    onAmber: Color(0xFFFFF2F6),
    cyan: Color(0xFF0B8A62),
    onCyan: Color(0xFFE8FBF3),
    danger: Color(0xFFC43B3B),
    ok: Color(0xFF0B8A62),
    glow: Color(0x29D6245A),
  );

  @override
  UpPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? line,
    Color? foreground,
    Color? muted,
    Color? dim,
    Color? amber,
    Color? onAmber,
    Color? cyan,
    Color? onCyan,
    Color? danger,
    Color? ok,
    Color? glow,
  }) {
    return UpPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      line: line ?? this.line,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      dim: dim ?? this.dim,
      amber: amber ?? this.amber,
      onAmber: onAmber ?? this.onAmber,
      cyan: cyan ?? this.cyan,
      onCyan: onCyan ?? this.onCyan,
      danger: danger ?? this.danger,
      ok: ok ?? this.ok,
      glow: glow ?? this.glow,
    );
  }

  @override
  UpPalette lerp(ThemeExtension<UpPalette>? other, double t) {
    if (other is! UpPalette) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return UpPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      line: mix(line, other.line),
      foreground: mix(foreground, other.foreground),
      muted: mix(muted, other.muted),
      dim: mix(dim, other.dim),
      amber: mix(amber, other.amber),
      onAmber: mix(onAmber, other.onAmber),
      cyan: mix(cyan, other.cyan),
      onCyan: mix(onCyan, other.onCyan),
      danger: mix(danger, other.danger),
      ok: mix(ok, other.ok),
      glow: mix(glow, other.glow),
    );
  }
}

extension PaletteAccess on BuildContext {
  UpPalette get palette =>
      Theme.of(this).extension<UpPalette>() ?? UpPalette.dark;
}
