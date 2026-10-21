import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/dating_strings.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/location/location_service.dart';
import '../../../domain/entities/geo_fix.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/entities/nearby_person.dart';
import '../../../state/app_scope.dart';
import '../../../state/interaction_controller.dart';
import '../../../state/live_controller.dart';
import '../../../state/session_controller.dart';
import '../../components/common.dart';
import '../../components/intent_picker.dart';
import '../../components/note_field.dart';
import '../../components/radar_view.dart';
import '../../components/up_buttons.dart';
import '../../components/up_chip.dart';
import '../../components/up_nav_bar.dart';
import '../../navigation/routes.dart';
import '../demo_sheet.dart';
import '../people_viewer_screen.dart';
import '../main_shell.dart';
import 'quiet_reason.dart';
import '../../components/up_photo.dart';

/// The one screen the product lives or dies on.
///
/// Three questions, top to bottom: why are you out (meet people / date),
/// where (around me / at a place with a QR), and the button. While Live it
/// becomes the room: who is here, tap to see them, and how long is left.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[session, live, interactions]),
      builder: (BuildContext context, Widget? _) {
        final List<NearbyPerson> visible = live.visibleNearby(
          passedIds: interactions.passedIds,
          blockedIds: interactions.blockedIds,
        );
        final int incoming = <String>{
          ...interactions.incomingUpIds,
          for (final NearbyPerson person in visible)
            if (person.sentYouUp) person.id,
        }.length;
        final LiveSession? running = live.session;
        final bool atVenue = running?.isVenue ?? false;
        final String venueName = running == null
            ? ''
            : (running.venueName.isEmpty ? running.venueCode : running.venueName);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _StatusRow(isLive: live.isLive),
                      const SizedBox(height: Insets.md),
                      if (!live.isLive && live.endedVenue != null) ...<Widget>[
                        _EndedVenueBanner(
                          name: live.endedVenue!.venueName.isEmpty
                              ? live.endedVenue!.venueCode
                              : live.endedVenue!.venueName,
                          onScan: () => _scanAndJoin(context),
                          onDismiss: live.dismissEndedVenue,
                        ),
                        const SizedBox(height: Insets.md),
                      ],
                      IntentPicker(
                        selected: live.isLive ? live.intent : session.liveIntent,
                        onSelect: session.setLiveIntent,
                        strings: s,
                        enabled: !live.isLive,
                      ),
                      if (!live.isLive) ...<Widget>[
                        const SizedBox(height: Insets.md),
                        _PlacePicker(
                          venueMode: session.venueMode,
                          onSelect: session.setVenueMode,
                        ),
                      ],
                      if (incoming > 0) ...<Widget>[
                        const SizedBox(height: Insets.md),
                        _IncomingBanner(
                          label: s.incomingUps(incoming),
                          onTap: () => _openViewer(context, visible, firstUp: true),
                        ),
                      ],
                      const SizedBox(height: Insets.lg),
                      RadarView(
                        isLive: live.isLive,
                        blipCount: visible.length,
                        child: _GoLiveButton(
                          isLive: live.isLive,
                          label: live.isLive
                              ? s.stopLive
                              : (session.venueMode
                                  ? s.scanQr.replaceAll(' ', '\n')
                                  : s.goLive),
                          onPressed: () => _toggleLive(context),
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      Text(
                        live.isLive
                            ? (atVenue ? s.venueLiveTitle(venueName) : s.areaLiveTitle)
                            : s.invisibleTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        live.isLive
                            ? s.visibleBody
                            : (session.venueMode ? s.modeVenueHint : s.invisibleBody),
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
                        if (atVenue && live.remaining.inMinutes < 10) ...<Widget>[
                          const SizedBox(height: Insets.sm),
                          UpButton(
                            label: s.stillHere,
                            icon: Icons.qr_code_scanner_rounded,
                            style: UpButtonStyle.ghost,
                            onPressed: () => _scanAndJoin(context),
                          ),
                        ],
                      ],
                      const SizedBox(height: Insets.md),
                      NoteField(
                        value: live.isLive ? live.session?.note ?? '' : session.liveNote,
                        onChanged: session.setLiveNote,
                        strings: s,
                        enabled: !live.isLive,
                      ),
                      const Spacer(),
                      if (live.isLive)
                        _NearbySummary(
                          people: visible,
                          localeCode: session.localeCode,
                          label: '${s.peopleNearby(visible.length)} · ${s.seePeople}',
                          hint: quietReason(
                            strings: s,
                            live: live,
                            hasServer: context.backend.isConfigured,
                            anyoneVisible: visible.isNotEmpty,
                          ),
                          onTap: () {
                            if (visible.isEmpty) {
                              MainShell.of(context)?.select(UpTab.nearby);
                            } else {
                              _openViewer(context, visible);
                            }
                          },
                        )
                      else if (!session.venueMode)
                        _DurationPicker(
                          selected: session.liveDuration,
                          minutesShort: s.minutesShort,
                          caption: s.durationLabel,
                          onSelect: session.setLiveDuration,
                        ),
                      const SizedBox(height: Insets.lg),
                    ],
                  ),
                ),
              ),
            );
          },
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

/// Opens the full-screen people viewer on [people], starting with the first
/// person who sent an UP when [firstUp] is set.
void _openViewer(
  BuildContext context,
  List<NearbyPerson> people, {
  bool firstUp = false,
  int index = 0,
}) {
  if (people.isEmpty) {
    return;
  }
  int start = index;
  if (firstUp) {
    final int found = people.indexWhere((NearbyPerson p) => p.sentYouUp);
    start = found < 0 ? 0 : found;
  }
  Navigator.of(context).pushNamed(
    Routes.people,
    arguments: PeopleViewerArgs(
      ids: people.map((NearbyPerson p) => p.id).toList(growable: false),
      initialIndex: start,
    ),
  );
}

/// Scans a place's QR and joins it. Shared by the button, "still here?" and
/// the banner after the hour ran out.
Future<void> _scanAndJoin(BuildContext context) async {
  final NavigatorState navigator = Navigator.of(context);
  final Object? code = await navigator.pushNamed(Routes.scan);
  if (code is String && code.isNotEmpty) {
    await navigator.pushNamed(Routes.venueJoin, arguments: code);
  }
}

/// Goes Live (around me, or by scanning a place), or stops.
Future<void> _toggleLive(BuildContext context) async {
  final LiveController live = context.live;
  final SessionController session = context.session;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final NavigatorState navigator = Navigator.of(context);
  final AppStrings s = context.strings;

  if (live.isLive) {
    await live.stop();
    return;
  }
  if (session.venueMode) {
    await _scanAndJoin(context);
    return;
  }

  GeoFix? fix;
  if (context.backend.isConfigured) {
    try {
      fix = await context.location.currentFix();
    } on LocationException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(s, error.code))));
      return;
    }
  }
  if (!context.mounted) {
    return;
  }
  // A new visit: whoever was hidden last time is back.
  context.interactions.forgetHidden();
  await live.start(
    session.liveDuration,
    intent: session.liveIntent,
    note: session.liveNote,
    fix: fix,
  );
  final String? code = live.lastErrorCode;
  if (code == 'verification_required') {
    messenger.showSnackBar(SnackBar(content: Text(errorText(s, code))));
    await navigator.pushNamed(Routes.verify);
  } else if (code != null) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(s, code))));
  }
}

/// Around me, or at a place.
class _PlacePicker extends StatelessWidget {
  const _PlacePicker({required this.venueMode, required this.onSelect});

  final bool venueMode;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;

    Widget option({
      required bool selected,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: selected ? p.cyan.withValues(alpha: 0.16) : p.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Insets.sm + 2,
                horizontal: Insets.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: selected ? p.cyan : p.line,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 18, color: selected ? p.cyan : p.muted),
                  const SizedBox(width: Insets.xs + 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? p.cyan : p.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          s.whereQuestion,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: p.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            option(
              selected: !venueMode,
              icon: Icons.near_me_rounded,
              label: s.modeArea,
              onTap: () => onSelect(false),
            ),
            const SizedBox(width: Insets.sm),
            option(
              selected: venueMode,
              icon: Icons.qr_code_scanner_rounded,
              label: s.modeVenue,
              onTap: () => onSelect(true),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Your hour at X is over" — with the way back in.
class _EndedVenueBanner extends StatelessWidget {
  const _EndedVenueBanner({
    required this.name,
    required this.onScan,
    required this.onDismiss,
  });

  final String name;
  final VoidCallback onScan;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    return UpCard(
      borderColor: p.amber,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_off_rounded, color: p.amber),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              s.venueEnded(name),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onScan, child: Text(s.scanAgain)),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: p.dim),
          ),
        ],
      ),
    );
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

/// The orb. Off: a lit pink sphere that breathes, asking to be pressed. On: it
/// turns to a mint ring — the signal colour — so "I am visible" is never
/// confused with "press me".
class _GoLiveButton extends StatefulWidget {
  const _GoLiveButton({
    required this.isLive,
    required this.label,
    required this.onPressed,
  });

  final bool isLive;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GoLiveButton> createState() => _GoLiveButtonState();
}

class _GoLiveButtonState extends State<_GoLiveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool isLive = widget.isLive;
    final Color glow = isLive ? p.cyan : p.amber;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    final Widget orb = Semantics(
      button: true,
      label: widget.label.replaceAll('\n', ' '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: glow.withValues(alpha: isLive ? 0.35 : 0.55),
              blurRadius: 60,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.circle,
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? p.background : null,
              border: isLive ? Border.all(color: p.cyan, width: 2) : null,
              gradient: isLive
                  ? null
                  : RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      radius: 0.95,
                      colors: <Color>[
                        Color.lerp(p.amber, Colors.white, 0.4)!,
                        p.amber,
                        Color.lerp(p.amber, Colors.black, 0.18)!,
                      ],
                      stops: const <double>[0, 0.55, 1],
                    ),
            ),
            child: InkWell(
              onTap: widget.onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: Sizes.goLiveDiameter,
                height: Sizes.goLiveDiameter,
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: isLive ? p.cyan : p.onAmber,
                          height: 1.1,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (isLive || reduceMotion) {
      return orb;
    }
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.045).animate(
        CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
      ),
      child: orb,
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
    required this.hint,
    required this.onTap,
  });

  final List<NearbyPerson> people;
  final String localeCode;
  final String label;

  /// Why nobody is showing, when nobody is. Null when people are.
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    const double overlapStep = 34;
    final int count = math.min(people.length, 5);

    return Column(
      children: <Widget>[
        if (count > 0)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(
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
                        child: UpPhoto.circle(
                          photoKey: people[i].mainPhotoKey,
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
          ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            hint!,
            textAlign: TextAlign.center,
            // The home column is fixed-height with a Spacer above; three lines
            // is what fits on the shortest phone this runs on. The full text is
            // one tap away on the nearby screen, which scrolls.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
