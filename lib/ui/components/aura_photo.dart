import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Placeholder portrait.
///
/// Milestone 1 ships no photo assets — nobody's face belongs in a demo repo,
/// and stock portraits make a prototype read as further along than it is. Each
/// person gets a deterministic three-colour aura from their seed, so the same
/// person always looks the same and the grid still has colour and rhythm.
/// Milestone 2 replaces this widget's body with a signed-URL `Image.network`
/// and keeps the same call sites.
class AuraPhoto extends StatelessWidget {
  const AuraPhoto({
    required this.seed,
    required this.initial,
    this.size,
    this.aspectRatio,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  const AuraPhoto.circle({
    required this.seed,
    required this.initial,
    required double diameter,
    super.key,
  })  : size = diameter,
        aspectRatio = null,
        borderRadius = null,
        shape = BoxShape.circle;

  final int seed;
  final String initial;
  final double? size;
  final double? aspectRatio;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  // Night Glow duotones: a lit top colour falling into a deep night shade.
  static const List<List<Color>> _auras = <List<Color>>[
    <Color>[Color(0xFFFF8FAB), Color(0xFFB4307A), Color(0xFF2A1240)],
    <Color>[Color(0xFF9AA8FF), Color(0xFF3B2E8A), Color(0xFF160F33)],
    <Color>[Color(0xFFFFB547), Color(0xFFA8432A), Color(0xFF2C1416)],
    <Color>[Color(0xFF4DF2B0), Color(0xFF1E7A6A), Color(0xFF0D2622)],
    <Color>[Color(0xFFC38BFF), Color(0xFF6C3BB8), Color(0xFF1E1236)],
    <Color>[Color(0xFFFF6FA0), Color(0xFF8E2257), Color(0xFF2A0F24)],
    <Color>[Color(0xFF3FD3C4), Color(0xFF1F5E7A), Color(0xFF0F1E2C)],
    <Color>[Color(0xFF7C6CFF), Color(0xFF3A2C99), Color(0xFF130E30)],
  ];

  List<Color> get _colors => _auras[seed.abs() % _auras.length];

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _colors;
    final double fontSize = (size ?? 96) * 0.36;

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(Radii.md))
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors[0], colors[1], colors[2]],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xEBFFFFFF),
            shadows: const <Shadow>[
              Shadow(color: Color(0x66000000), blurRadius: 14),
            ],
          ),
        ),
      ),
    );

    if (aspectRatio != null) {
      content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    }
    if (size != null) {
      content = SizedBox(width: size, height: size, child: content);
    }
    return ExcludeSemantics(child: content);
  }
}
