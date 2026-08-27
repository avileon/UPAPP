import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// Uppercase eyebrow label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: color ?? context.palette.dim),
    );
  }
}

/// Every empty state in the app: icon, headline, one line of why.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: p.dim, size: 26),
            ),
            const SizedBox(height: Insets.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Insets.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: Insets.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Card surface. One elevation, one radius, everywhere.
class UpCard extends StatelessWidget {
  const UpCard({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: borderColor ?? p.line),
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: content,
    );
  }
}

/// Back arrow that mirrors itself in RTL, plus an optional trailing action.
class UpTopBar extends StatelessWidget {
  const UpTopBar({
    this.title,
    this.onBack,
    this.trailing,
    this.leading,
    super.key,
  });

  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm, bottom: Insets.lg),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            _RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack!,
              mirrorInRtl: true,
              semanticLabel:
                  MaterialLocalizations.of(context).backButtonTooltip,
            ),
          if (leading != null) leading!,
          if (onBack != null || leading != null)
            const SizedBox(width: Insets.md),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.mirrorInRtl = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool flip =
        mirrorInRtl && Directionality.of(context) == TextDirection.rtl;

    Widget glyph = Icon(icon, size: 18, color: p.foreground);
    if (flip) {
      glyph = Transform.scale(scaleX: -1, child: glyph);
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 40, height: 40, child: glyph),
        ),
      ),
    );
  }
}

/// Icon button used for the "more" affordance in top bars.
class UpIconButton extends StatelessWidget {
  const UpIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _RoundIconButton(
      icon: icon,
      onPressed: onPressed,
      semanticLabel: semanticLabel,
    );
  }
}
