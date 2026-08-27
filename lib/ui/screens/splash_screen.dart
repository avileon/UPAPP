import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Short hold while the app would check for an existing session.
///
/// In Milestone 2 this is where a valid refresh token skips straight to
/// [Routes.main]. Today it just gives the wordmark a beat.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      if (context.session.isSignedIn) {
        Navigator.of(context).pushReplacementNamed(Routes.main);
      } else {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return UpScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ShaderMask(
              shaderCallback: (Rect bounds) => LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[p.amber, p.cyan],
              ).createShader(bounds),
              child: Text(
                'UP',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: Insets.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                context.strings.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: Insets.xxl),
            AnimatedOpacity(
              opacity: _ready ? 1.0 : 0.0,
              duration: Motion.normal,
              child: UpButton(
                label: context.strings.start,
                expand: false,
                onPressed: _ready
                    ? () => Navigator.of(context)
                        .pushReplacementNamed(Routes.intro)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
