import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/entities/nearby_person.dart';
import '../../../state/app_scope.dart';
import '../../../state/interaction_controller.dart';
import '../../../state/live_controller.dart';
import '../../../state/session_controller.dart';
import '../../components/aura_photo.dart';
import '../../components/common.dart';
import '../../components/radar_view.dart';
import '../../components/up_buttons.dart';
import '../../components/up_chip.dart';
import '../../components/up_nav_bar.dart';
import '../../navigation/routes.dart';
import '../demo_sheet.dart';
import '../main_shell.dart';

/// The one screen the product lives or dies on.
///
/// Duration is chosen here, before going Live, not buried in settings — it is a
/// decision people make in the moment ("I'm here for one drink") and burying it
/// turns Live into an always-on switch, which is exactly what UP is not.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: Listenable.merge(
        <Listenable>[session, live, interactions],
      ),
      builder: (BuildContext context, Widget? _) {
        final List<NearbyPerson> visible = live.visibleNearby(
          passedIds: interactions.passedIds,
          blockedIds: interactions.blockedIds,
        );
        final int incoming = interactions.incomingUpIds.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StatusRow(isLive: live.isLive),
              if (incoming > 0) ...<Widget>[
                const SizedBox(height: Insets.md),
                _IncomingBanner(
                  label: s.incomingUps(incoming),
                  onTap: () => MainShell.of(context)?.select(UpTab.nearby),
                ),
              ],
              const SizedBox(height: Insets.lg),
              RadarView(
                isLive: live.isLive,
                blipCount: visible.length,
                child: _GoLiveButton(
                  isLive: live.isLive,
                  label: live.isLive ? s.stopLive : s.goLive,
                  onPressed: () => _toggleLive(context, live, session),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(
                live.isLive ? s.visibleTitle : s.invisibleTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                live.isLive ? s.visibleBody : s.invisibleBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (live.isLive) ...<Widget>[
                const SizedBox(height: Insets.md),
                Text(
                  '${s.visibleFor} ${_formatRemaining(live.remaining)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.palette.cyan,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                ),
              ],
              const Spacer(),
              if (live.isLive)
                _NearbySummary(
                  people: visible,
                  localeCode: session.localeCode,
                  label: '${s.peopleNearby(visible.length)} · ${s.seeNearby}',
                  onTap: () => MainShell.of(context)?.select(UpTab.nearby),
                )
              else
                _DurationPicker(
                  selected: session.liveDuration,
                  minutesShort: s.minutesShort,
                  caption: s.durationLabel,
                  onSelect: session.setLiveDuration,
                ),
              const SizedBox(height: Insets.lg),
            ],
          ),
        );
      },
    );
  }

  static String _formatRemaining(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}


/// Goes Live, and surfaces a refusal instead of swallowing it.
Future<void> _toggleLive(
  BuildContext context,
  LiveController live,
  SessionController session,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppStrings s = context.strings;
  await live.toggle(session.liveDuration);
  final String? code = live.lastErrorCode;
  if (code != null) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(s, code))));
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          SectionLabel(
            isLive ? s.bluetoothOn : s.bluetoothOff,
            color: isLive ? context.palette.cyan : context.palette.dim,
          ),
          Row(
            children: <Widget>[
              if (kDemoControlsEnabled)
                TextButton(
                  onPressed: () => DemoSheet.show(context),
                  child: SectionLabel(s.demoTitle),
                ),
              const SizedBox(width: Insets.xs),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.settings),
                child: SectionLabel(s.settingsTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoLiveButton extends StatelessWidget {
  const _GoLiveButton({
    required this.isLive,
    required this.label,
    required this.onPressed,
  });

  final bool isLive;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: Material(
        color: isLive ? Colors.transparent : p.amber,
        shape: CircleBorder(
          side: BorderSide(color: isLive ? p.cyan : p.amber, width: 1.5),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: Sizes.goLiveDiameter,
            height: Sizes.goLiveDiameter,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isLive ? p.cyan : p.onAmber,
                      height: 1.1,
                      fontSize: 20,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingBanner extends StatelessWidget {
  const _IncomingBanner({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return UpCard(
      onTap: onTap,
      borderColor: p.amber,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.arrow_upward_rounded, color: p.amber, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbySummary extends StatelessWidget {
  const _NearbySummary({
    required this.people,
    required this.localeCode,
    required this.label,
    required this.onTap,
  });

  final List<NearbyPerson> people;
  final String localeCode;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    const double overlapStep = 34;
    final int count = math.min(people.length, 5);

    return Column(
      children: <Widget>[
        if (count > 0)
          Center(
            child: SizedBox(
              height: Sizes.avatarSm,
              width: Sizes.avatarSm + (count - 1) * overlapStep,
              child: Stack(
                children: <Widget>[
                  for (int i = 0; i < count; i++)
                    PositionedDirectional(
                      start: i * overlapStep,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: p.background, width: 2),
                        ),
                        child: AuraPhoto.circle(
                          seed: people[i].auraSeed,
                          initial: people[i].initialFor(localeCode),
                          diameter: Sizes.avatarSm,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Insets.md),
        UpButton(
          label: label,
          style: UpButtonStyle.ghost,
          onPressed: onTap,
        ),
      ],
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({
    required this.selected,
    required this.minutesShort,
    required this.caption,
    required this.onSelect,
  });

  final Duration selected;
  final String minutesShort;
  final String caption;
  final ValueChanged<Duration> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: Insets.sm,
          alignment: WrapAlignment.center,
          children: LiveSession.selectableDurations.map((Duration d) {
            return UpChip(
              label: '${d.inMinutes} $minutesShort',
              selected: d == selected,
              onSelected: () => onSelect(d),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: Insets.sm),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
