import 'package:flutter/material.dart';

/// The UP palette.
///
/// Two meanings, two hues, and they never swap roles:
///   * [cyan]  — the machine signal. Live, Bluetooth, radar, verification.
///   * [amber] — the human moment. UP, match, warmth, the primary action.
///
/// Neutrals carry a slight plum bias so the dark theme reads as a room at
/// night rather than as flat grey.
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
    background: Color(0xFF0C0A0D),
    surface: Color(0xFF161219),
    surfaceHigh: Color(0xFF1F1922),
    line: Color(0xFF2C2430),
    foreground: Color(0xFFF6F0F3),
    muted: Color(0xFFA2929C),
    dim: Color(0xFF6C5C66),
    amber: Color(0xFFFFA24B),
    onAmber: Color(0xFF20130A),
    cyan: Color(0xFF4FD6E0),
    onCyan: Color(0xFF04191C),
    danger: Color(0xFFFF6B6B),
    ok: Color(0xFF8BD98B),
    glow: Color(0x29FFA24B),
  );

  static const UpPalette light = UpPalette(
    background: Color(0xFFFBF6F2),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF2EAE4),
    line: Color(0xFFE3D7CE),
    foreground: Color(0xFF1B1216),
    muted: Color(0xFF6B5A62),
    dim: Color(0xFF9A8891),
    amber: Color(0xFFC96A11),
    onAmber: Color(0xFFFFF6EC),
    cyan: Color(0xFF12808C),
    onCyan: Color(0xFFEAFBFC),
    danger: Color(0xFFC43B3B),
    ok: Color(0xFF3F8A46),
    glow: Color(0x1FC96A11),
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
