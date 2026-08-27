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

  static const List<List<Color>> _auras = <List<Color>>[
    <Color>[Color(0xFFFF9A5B), Color(0xFFC2477A), Color(0xFF3A1F35)],
    <Color>[Color(0xFF4FD6E0), Color(0xFF2F6F8F), Color(0xFF141E2C)],
    <Color>[Color(0xFFF5C86B), Color(0xFFD9724A), Color(0xFF3A2118)],
    <Color>[Color(0xFF8BD98B), Color(0xFF3E8E7E), Color(0xFF16261F)],
    <Color>[Color(0xFFC99BFF), Color(0xFF6C4BB8), Color(0xFF211436)],
    <Color>[Color(0xFFFF8A80), Color(0xFFA63D5B), Color(0xFF2E1520)],
    <Color>[Color(0xFF7BE0C0), Color(0xFF2D8C87), Color(0xFF122824)],
    <Color>[Color(0xFFFFB35B), Color(0xFFB75A2E), Color(0xFF2C1810)],
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
