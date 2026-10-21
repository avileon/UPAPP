import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/repositories/interaction_repository.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/confetti.dart';
import '../components/up_photo.dart';
import '../navigation/routes.dart';
import 'safety_sheet.dart';

/// What the viewer opens on: the people, in order, and where to start.
class PeopleViewerArgs {
  const PeopleViewerArgs({required this.ids, this.initialIndex = 0});

  final List<String> ids;
  final int initialIndex;
}

/// Everyone in the room, one at a time, full screen.
///
/// Swipe sideways for the next person; tap the sides of the photo for their
/// other photos. UP is on the photo itself — the one decision on this screen,
/// where the eye already is. There is no X: not sending an UP is what happens
/// when you swipe on. Hiding and blocking live behind the three dots.
class PeopleViewerScreen extends StatefulWidget {
  const PeopleViewerScreen({required this.args, super.key});

  final PeopleViewerArgs args;

  @override
  State<PeopleViewerScreen> createState() => _PeopleViewerScreenState();
}

class _PeopleViewerScreenState extends State<PeopleViewerScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.args.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (!_pages.hasClients) {
      return;
    }
    unawaited(
      _pages.nextPage(duration: Motion.normal, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final InteractionController interactions = context.interactions;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[interactions, context.people]),
        builder: (BuildContext context, Widget? _) {
          final Set<String> gone = <String>{
            ...interactions.passedIds,
            ...interactions.blockedIds,
          };
          final List<NearbyPerson> people = <NearbyPerson>[
            for (final String id in widget.args.ids)
              if (!gone.contains(id) && context.people.byId(id) != null)
                context.people.byId(id)!,
          ];

          if (people.isEmpty) {
            return _Empty(onClose: () => Navigator.of(context).pop());
          }

          return PageView.builder(
            controller: _pages,
            itemCount: people.length,
            itemBuilder: (BuildContext context, int index) => _PersonPage(
              key: ValueKey<String>(people[index].id),
              person: people[index],
              onSent: index < people.length - 1 ? _next : null,
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.people_outline_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: Insets.md),
            Text(
              s.noOneLeft,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: Insets.lg),
            TextButton(
              onPressed: onClose,
              child: Text(s.done),
            ),
          ],
        ),
      ),
    );
  }
}

/// One person: their photos, who they are, and the UP button.
class _PersonPage extends StatefulWidget {
  const _PersonPage({required this.person, this.onSent, super.key});

  final NearbyPerson person;

  /// Moves on to the next person after a one-way UP.
  final VoidCallback? onSent;

  @override
  State<_PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<_PersonPage> {
  int _photo = 0;
  bool _sending = false;
  int _bursts = 0;

  NearbyPerson get _person => widget.person;

  int get _photoCount =>
      _person.photoKeys.isEmpty ? 1 : _person.photoKeys.length;

  void _tapPhoto(TapUpDetails details, double width) {
    if (_photoCount < 2) {
      return;
    }
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final bool leftHalf = details.localPosition.dx < width / 2;
    // Forward is towards the reading direction's end.
    final bool forward = rtl ? leftHalf : !leftHalf;
    setState(() {
      _photo = math.max(
        0,
        math.min(_photoCount - 1, forward ? _photo + 1 : _photo - 1),
      );
    });
  }

  Future<void> _sendUp() async {
    if (_sending) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;
    final String name = _person.nameFor(context.session.localeCode);

    setState(() {
      _sending = true;
      _bursts += 1;
    });
    final UpResult result = await interactions.sendUp(_person.id);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);

    switch (result.outcome) {
      case UpOutcome.matched:
        await navigator.pushNamed(Routes.match, arguments: _person.id);
      case UpOutcome.recorded:
        messenger.showSnackBar(
          SnackBar(
            content: Text(s.upSentTo(name)),
            duration: const Duration(seconds: 2),
          ),
        );
        final VoidCallback? next = widget.onSent;
        if (next != null) {
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (mounted) {
              next();
            }
          });
        }
      case UpOutcome.duplicate:
        break;
      case UpOutcome.rateLimited:
        messenger.showSnackBar(SnackBar(content: Text(s.errorRateLimited)));
      case UpOutcome.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(errorText(s, interactions.lastErrorCode))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;
    final InteractionController interactions = context.interactions;
    final bool sent =
        _person.youSentUp || interactions.hasSentUpTo(_person.id);
    final bool sentYou =
        _person.sentYouUp || interactions.incomingUpIds.contains(_person.id);
    final String? key = _person.photoKeys.isEmpty
        ? null
        : _person.photoKeys[math.min(_photo, _person.photoKeys.length - 1)];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              onTapUp: (TapUpDetails d) => _tapPhoto(d, constraints.maxWidth),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: SizedBox.expand(
                  key: ValueKey<String>(key ?? 'aura'),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxWidth * 5 / 4,
                      child: UpPhoto(
                        photoKey: key,
                        seed: _person.auraSeed,
                        initial: _person.initialFor(localeCode),
                        aspectRatio: 4 / 5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Legibility for the text at the bottom and the bars at the top.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xE6000000),
                    ],
                    stops: <double>[0, 0.18, 0.55, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_photoCount > 1)
                      _PhotoBars(count: _photoCount, current: _photo),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        _GlassButton(
                          icon: Icons.close_rounded,
                          label: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        _GlassButton(
                          icon: Icons.more_vert_rounded,
                          label: s.more,
                          onTap: () => SafetySheet.show(
                            context,
                            _person.id,
                            closeScreen: false,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (sentYou && !sent)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: Insets.sm),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                            vertical: Insets.xs,
                          ),
                          decoration: BoxDecoration(
                            color: p.amber,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: p.amber.withValues(alpha: 0.6),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Text(
                            '⬆ ${s.sentYouUpBadge}',
                            style: TextStyle(
                              color: p.onAmber,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: _Caption(person: _person, localeCode: localeCode),
                        ),
                        const SizedBox(width: Insets.md),
                        _UpButton(
                          sent: sent,
                          busy: _sending,
                          label: sent ? s.upSentShort : s.upAction,
                          onTap: sent ? null : _sendUp,
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                ),
              ),
            ),
            if (_bursts > 0)
              ConfettiBurst(
                key: ValueKey<int>(_bursts),
                particles: 60,
                origin: const AlignmentDirectional(0.75, 0.75)
                    .resolve(Directionality.of(context)),
              ),
          ],
        );
      },
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.person, required this.localeCode});

  final NearbyPerson person;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    const List<Shadow> shadow = <Shadow>[
      Shadow(blurRadius: 8, color: Color(0xAA000000)),
    ];
    final String bio = person.bioFor(localeCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                person.nameFor(localeCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  shadows: shadow,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              person.age > 0 ? '${person.age}' : '',
              style: const TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 26,
                fontWeight: FontWeight.w500,
                shadows: shadow,
              ),
            ),
            if (person.isSelfieVerified) ...<Widget>[
              const SizedBox(width: Insets.sm),
              Icon(Icons.verified_rounded, color: p.cyan, size: 24),
            ],
          ],
        ),
        if (person.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          Text(
            person.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.cyan,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: shadow,
            ),
          ),
        ],
        if (bio.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xEEFFFFFF),
              fontSize: 14,
              height: 1.35,
              shadows: shadow,
            ),
          ),
        ],
      ],
    );
  }
}

/// The UP button, on the photo. Pink and glowing until pressed, then a quiet
/// mint "sent".
class _UpButton extends StatefulWidget {
  const _UpButton({
    required this.sent,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool sent;
  final bool busy;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_UpButton> createState() => _UpButtonState();
}

class _UpButtonState extends State<_UpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool sent = widget.sent;
    final Color fill = sent ? p.cyan : p.amber;
    final Color ink = sent ? p.onCyan : p.onAmber;

    final Widget button = Semantics(
      button: true,
      label: widget.label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: fill.withValues(alpha: 0.6), blurRadius: 26),
          ],
        ),
        child: Material(
          color: fill,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: widget.busy ? null : widget.onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 78,
              height: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    sent ? Icons.check_rounded : Icons.arrow_upward_rounded,
                    color: ink,
                    size: 30,
                  ),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (sent || MediaQuery.of(context).disableAnimations) {
      return button;
    }
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.07).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: button,
    );
  }
}

class _PhotoBars extends StatelessWidget {
  const _PhotoBars({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i == current
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: const Color(0x55000000),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
