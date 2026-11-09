import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

/// The AppDate logo: the heart with its "here, now" ping, and the wordmark.
///
/// Sources live in assets/brand/*.svg; the mark ships as a PNG so the app
/// needs no SVG package for one picture.
class AppDateLogo extends StatelessWidget {
  const AppDateLogo({this.size = 96, this.showWordmark = true, super.key});

  /// Height of the mark. The wordmark scales with it.
  final double size;
  final bool showWordmark;

  static const String name = 'AppDate';

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final Widget mark = Image.asset(
      'assets/brand/mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: showWordmark ? null : name,
    );
    if (!showWordmark) {
      return mark;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        SizedBox(height: size * 0.16),
        Semantics(
          label: name,
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'App', style: TextStyle(color: p.foreground)),
                TextSpan(text: 'Date', style: TextStyle(color: p.amber)),
              ],
            ),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontWeight: FontWeight.w800,
              fontSize: size * 0.48,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
