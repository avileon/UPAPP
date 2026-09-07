import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/live_intent.dart';

/// Labels, hints and icons for the four intents, in one place.
///
/// A switch over an enum spread across three widgets is how a fifth intent
/// gets added in two of them.
extension LiveIntentPresentation on LiveIntent {
  String label(AppStrings s) => switch (this) {
        LiveIntent.meet => s.intentMeet,
        LiveIntent.date => s.intentDate,
        LiveIntent.work => s.intentWork,
        LiveIntent.doing => s.intentDoing,
      };

  String hint(AppStrings s) => switch (this) {
        LiveIntent.meet => s.intentMeetHint,
        LiveIntent.date => s.intentDateHint,
        LiveIntent.work => s.intentWorkHint,
        LiveIntent.doing => s.intentDoingHint,
      };

  IconData get icon => switch (this) {
        LiveIntent.meet => Icons.groups_2_rounded,
        LiveIntent.date => Icons.favorite_rounded,
        LiveIntent.work => Icons.work_outline_rounded,
        LiveIntent.doing => Icons.directions_run_rounded,
      };

  List<String> openers(AppStrings s) => switch (this) {
        LiveIntent.meet => s.openersMeet,
        LiveIntent.date => s.openersDate,
        LiveIntent.work => s.openersWork,
        LiveIntent.doing => s.openersDoing,
      };
}

/// The first thing on the home screen, above the button.
///
/// It is a row of four rather than a dropdown because the choice has to be
/// visible without being opened: a person who cannot see that "dating" is one
/// of four options will assume it is the only one, which is precisely the
/// impression the app used to give. And it sits *above* Go Live because it
/// changes what going Live means — asking afterwards would be asking about a
/// decision already made.
class IntentPicker extends StatelessWidget {
  const IntentPicker({
    required this.selected,
    required this.onSelect,
    required this.strings,
    this.enabled = true,
    super.key,
  });

  final LiveIntent selected;
  final ValueChanged<LiveIntent> onSelect;
  final AppStrings strings;

  /// False while Live. The intent is fixed for the length of a session — it is
  /// what the server matched people on, and changing it underneath a running
  /// session would silently empty the room.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.intentQuestion,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: p.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            for (final LiveIntent intent in LiveIntent.values) ...<Widget>[
              if (intent != LiveIntent.values.first)
                const SizedBox(width: Insets.sm),
              Expanded(
                child: _IntentTile(
                  intent: intent,
                  selected: intent == selected,
                  enabled: enabled,
                  strings: strings,
                  onTap: () => onSelect(intent),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.sm),
        // The consequence of the current choice, always on screen. This is the
        // only place the preference filter is ever explained, and explaining it
        // where it is chosen is the difference between a rule and a mystery.
        AnimatedSwitcher(
          duration: Motion.fast,
          child: Text(
            enabled
                ? selected.hint(strings)
                : '${selected.hint(strings)} · ${strings.intentLockedWhileLive}',
            key: ValueKey<String>('${selected.name}$enabled'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: p.dim),
          ),
        ),
      ],
    );
  }
}

class _IntentTile extends StatelessWidget {
  const _IntentTile({
    required this.intent,
    required this.selected,
    required this.enabled,
    required this.strings,
    required this.onTap,
  });

  final LiveIntent intent;
  final bool selected;
  final bool enabled;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    // Dimmed rather than hidden while Live: the answer to "what am I set to"
    // has to stay on screen, and a picker that vanishes takes it with it.
    final double opacity = enabled || selected ? 1 : 0.35;

    return Semantics(
      selected: selected,
      button: enabled,
      label: intent.label(strings),
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: selected ? p.amber.withValues(alpha: 0.14) : p.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                vertical: Insets.md,
                horizontal: Insets.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: selected ? p.amber : p.line,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    intent.icon,
                    size: 20,
                    color: selected ? p.amber : p.muted,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    intent.label(strings),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? p.amber : p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
