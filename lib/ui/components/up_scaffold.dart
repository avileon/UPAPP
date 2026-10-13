import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// Every screen's outer surface: background from the theme, safe area handled
/// once, and the single horizontal gutter the whole app shares.
///
/// Behind the content sit two soft pools of light — the accent and a violet —
/// which is most of what makes the dark theme read as "night" rather than
/// "black". Painted once, under everything, and never hit-tested.
class UpScaffold extends StatelessWidget {
  const UpScaffold({
    required this.child,
    this.bottomBar,
    this.padded = true,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget child;
  final Widget? bottomBar;
  final bool padded;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // The bar floats: the glow runs on behind it, and the SafeArea below
      // (which sees the bar's height as bottom padding) keeps the content
      // clear of it.
      extendBody: bottomBar != null,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(child: _AmbientGlow(accent: p.amber)),
          SafeArea(
            child: padded
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.screen,
                    ),
                    child: child,
                  )
                : child,
          ),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.accent});

  final Color accent;

  static const Color _violet = Color(0xFF6E5CFF);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double strength = dark ? 1 : 0.45;
    Widget pool(Color c, double alpha) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                c.withValues(alpha: alpha * strength),
                c.withValues(alpha: 0),
              ],
            ),
          ),
        );
    return Stack(
      children: <Widget>[
        Positioned(
          top: -160,
          left: -140,
          width: 440,
          height: 440,
          child: pool(accent, 0.22),
        ),
        Positioned(
          bottom: -40,
          right: -170,
          width: 440,
          height: 440,
          child: pool(_violet, 0.18),
        ),
      ],
    );
  }
}
