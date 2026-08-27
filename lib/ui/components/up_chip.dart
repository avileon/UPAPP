import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// Single-select pill. Used for gender, preference and Live duration.
class UpChip extends StatelessWidget {
  const UpChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.amber : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: selected ? p.amber : p.line),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? p.onAmber : p.muted,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only pill. Used for "near you right now" and the new-match tag.
class UpTag extends StatelessWidget {
  const UpTag({
    required this.label,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs + 1,
      ),
      decoration: BoxDecoration(
        color: emphasized ? p.amber : p.surfaceHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: emphasized ? p.onAmber : p.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// The Reality Verified badge.
///
/// Cyan, like everything else that is a signal rather than a feeling — and
/// worded as a statement about photos, never about the person.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs + 1,
      ),
      decoration: BoxDecoration(
        color: p.onCyan,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: p.cyan),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 13, color: p.cyan),
          const SizedBox(width: Insets.xs + 1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
