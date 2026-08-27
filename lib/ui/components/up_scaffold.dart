import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Every screen's outer surface: background from the theme, safe area handled
/// once, and the single horizontal gutter the whole app shares.
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
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        bottom: bottomBar == null,
        child: padded
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.screen,
                ),
                child: child,
              )
            : child,
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
