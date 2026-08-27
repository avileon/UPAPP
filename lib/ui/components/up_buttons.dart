import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

enum UpButtonStyle { primary, ghost, quiet, danger }

/// The one button in the app. Variants, not four different widgets.
class UpButton extends StatelessWidget {
  const UpButton({
    required this.label,
    required this.onPressed,
    this.style = UpButtonStyle.primary,
    this.expand = true,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final UpButtonStyle style;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool enabled = onPressed != null;

    Color background = Colors.transparent;
    Color foreground = p.foreground;
    BorderSide side = BorderSide.none;

    switch (style) {
      case UpButtonStyle.primary:
        background = p.amber;
        foreground = p.onAmber;
      case UpButtonStyle.ghost:
        foreground = p.foreground;
        side = BorderSide(color: p.line);
      case UpButtonStyle.quiet:
        foreground = p.muted;
      case UpButtonStyle.danger:
        foreground = p.danger;
        side = BorderSide(color: p.danger);
    }

    final Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: Insets.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: style == UpButtonStyle.quiet
                      ? FontWeight.w600
                      : FontWeight.w700,
                ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: Sizes.touchTarget),
            padding: EdgeInsets.symmetric(
              horizontal: expand ? Insets.lg : Insets.xl,
              vertical: style == UpButtonStyle.quiet ? Insets.md : Insets.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: side == BorderSide.none
                  ? null
                  : Border.fromBorderSide(side),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The two circular actions on a profile. UP is deliberately the larger of the
/// two and the only one that carries colour.
class CircleAction extends StatelessWidget {
  const CircleAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final double diameter =
        emphasized ? Sizes.upButton : Sizes.passButton;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1.0,
        child: Material(
          color: emphasized ? p.amber : Colors.transparent,
          shape: CircleBorder(
            side: emphasized
                ? BorderSide.none
                : BorderSide(color: p.line),
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Icon(
                icon,
                size: emphasized ? 32.0 : 24.0,
                color: emphasized ? p.onAmber : p.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
