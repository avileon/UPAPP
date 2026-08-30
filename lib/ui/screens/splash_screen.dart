import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// The hold while the app works out whether this device is already signed in.
///
/// It waits for the answer rather than guessing after a fixed beat. Reading a
/// stored session ends in a network round trip, and a phone on a slow
/// connection took longer than the old 1.2-second timer allowed — so a person
/// who had already registered was shown the sign-up flow again, every single
/// time they opened the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _ready = false;
  bool _decided = false;
  int _waitedMs = 0;

  /// The wordmark gets a beat regardless — an instant jump reads as a glitch.
  static const int _minimumHoldMs = 1200;

  /// And a ceiling, so an unreachable server cannot hold someone on a splash
  /// screen forever. Past this we treat them as signed out, which is
  /// recoverable: they land on the intro and can try again.
  static const int _maximumWaitMs = 12000;

  static const Duration _tick = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: _minimumHoldMs), () {
      _waitedMs = _minimumHoldMs;
      _check();
    });
  }

  void _check() {
    if (!mounted || _decided) {
      return;
    }
    if (context.booting && _waitedMs < _maximumWaitMs) {
      _timer = Timer(_tick, () {
        _waitedMs += _tick.inMilliseconds;
        _check();
      });
      return;
    }
    _decided = true;
    if (context.session.isSignedIn) {
      Navigator.of(context).pushReplacementNamed(Routes.main);
    } else {
      setState(() => _ready = true);
    }
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
