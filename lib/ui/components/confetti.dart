import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

/// A one-shot burst of confetti, drawn by hand.
///
/// No package: a hundred rectangles with gravity and a spin is a CustomPainter,
/// not a dependency. Plays once when it appears, never hit-tests, and draws
/// nothing at all for someone who asked the system to reduce motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    this.particles = 120,
    this.duration = const Duration(milliseconds: 2600),
    this.origin = const Alignment(0, -0.2),
    super.key,
  });

  final int particles;
  final Duration duration;

  /// Where the burst starts, in the box this widget fills.
  final Alignment origin;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  List<_Particle> _particles = const <_Particle>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isNotEmpty) {
      return;
    }
    final UpPalette p = context.palette;
    final List<Color> colours = <Color>[
      p.amber,
      p.cyan,
      const Color(0xFFFFD84D),
      const Color(0xFFB57BFF),
      Colors.white,
    ];
    final math.Random random = math.Random();
    _particles = List<_Particle>.generate(widget.particles, (int i) {
      final double angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.1;
      final double speed = 0.55 + random.nextDouble() * 0.75;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        spin: (random.nextDouble() - 0.5) * 18,
        size: 5 + random.nextDouble() * 7,
        colour: colours[i % colours.length],
        wobble: random.nextDouble() * math.pi * 2,
      );
    });
    if (!MediaQuery.of(context).disableAnimations) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            t: _controller.value,
            origin: widget.origin,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.colour,
    required this.wobble,
  });

  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color colour;
  final double wobble;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.origin,
  });

  final List<_Particle> particles;
  final double t;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) {
      return;
    }
    final Offset start = origin.alongSize(size);
    final double scale = size.shortestSide;
    final double fade = t < 0.75 ? 1 : (1 - t) / 0.25;
    final Paint paint = Paint();
    for (final _Particle particle in particles) {
      // Launch, then gravity pulls everything down past the bottom edge.
      final double x = start.dx +
          particle.vx * scale * t * 1.1 +
          math.sin(particle.wobble + t * 12) * 6;
      final double y = start.dy +
          particle.vy * scale * t * 1.1 +
          0.5 * 2.4 * scale * t * t;
      paint.color = particle.colour.withValues(alpha: fade.clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.55,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
