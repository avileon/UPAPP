import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// The Live radar.
///
/// Three static rings plus, while Live, three expanding sweeps and one blip per
/// discovered person. The blip positions are decorative and derived from the
/// index — they are not, and must never become, a direction or a distance.
class RadarView extends StatefulWidget {
  const RadarView({
    required this.isLive,
    required this.blipCount,
    required this.child,
    super.key,
  });

  final bool isLive;
  final int blipCount;
  final Widget child;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.sweep,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(RadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isLive) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      width: Sizes.radarDiameter,
      height: Sizes.radarDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  size: const Size.square(Sizes.radarDiameter),
                  painter: _RadarPainter(
                    progress: reduceMotion ? 0.0 : _controller.value,
                    isLive: widget.isLive,
                    showSweeps: widget.isLive && !reduceMotion,
                    blipCount: widget.blipCount,
                    ringColor: p.line,
                    sweepColor: p.cyan,
                    blipColor: p.amber,
                    glowColor: p.glow,
                  ),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.isLive,
    required this.showSweeps,
    required this.blipCount,
    required this.ringColor,
    required this.sweepColor,
    required this.blipColor,
    required this.glowColor,
  });

  final double progress;
  final bool isLive;
  final bool showSweeps;
  final int blipCount;
  final Color ringColor;
  final Color sweepColor;
  final Color blipColor;
  final Color glowColor;

  static const List<double> _ringFractions = <double>[1.0, 0.7, 0.42];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double maxRadius = size.width / 2;

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ringColor;
    for (final double f in _ringFractions) {
      canvas.drawCircle(centre, maxRadius * f, ring);
    }

    if (showSweeps) {
      for (int i = 0; i < 3; i++) {
        final double phase = (progress + i / 3) % 1.0;
        final double radius = maxRadius * (0.42 + phase * 0.58);
        final Paint sweep = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          // ignore: deprecated_member_use
          ..color = sweepColor.withOpacity((1 - phase) * 0.85);
        canvas.drawCircle(centre, radius, sweep);
      }
    }

    if (!isLive || blipCount == 0) {
      return;
    }

    final Paint blip = Paint()..color = blipColor;
    final Paint halo = Paint()..color = glowColor;
    final int count = math.min(blipCount, 7);
    for (int i = 0; i < count; i++) {
      final double angle = (i * 51 + 22) * math.pi / 180;
      final double radius = maxRadius * (0.64 + (i % 3) * 0.11);
      final Offset at = centre +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(at, 8.5, halo);
      canvas.drawCircle(at, 4.5, blip);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress ||
      old.isLive != isLive ||
      old.showSweeps != showSweeps ||
      old.blipCount != blipCount ||
      old.ringColor != ringColor;
}
