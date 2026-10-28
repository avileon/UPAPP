import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/repositories/interaction_repository.dart';
import '../../domain/entities/room_status.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../../state/live_controller.dart';
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
/// Swipe sideways for the next person; swipe up and down for their other
/// photos. Tapping the photo is the UP — the one decision on this screen,
/// where the eye already is — with three seconds to take it back, because at a
/// place there are only four of them a night. There is no X: not sending an UP
/// is what happens when you swipe on. Hiding and blocking live behind the
/// three dots.
class PeopleViewerScreen extends StatefulWidget {
  const PeopleViewerScreen({required this.args, super.key});

  final PeopleViewerArgs args;

  @override
  State<PeopleViewerScreen> createState() => _PeopleViewerScreenState();
}

/// An UP that has been tapped but not sent yet — the undo window.
class _PendingUp {
  _PendingUp({
    required this.personId,
    required this.name,
    required this.costsSlot,
    required this.timer,
  });

  final String personId;
  final String name;

  /// False when answering someone who sent you one: that is free.
  final bool costsSlot;
  final Timer timer;
}

class _PeopleViewerScreenState extends State<PeopleViewerScreen> {
  static const Duration _undoWindow = Duration(seconds: 3);

  late final PageController _pages =
      PageController(initialPage: widget.args.initialIndex);

  _PendingUp? _pending;

  // Held directly so an UP still in its undo window can be sent from
  // dispose(), when there is no context left to look them up through.
  late InteractionController _interactions;
  late LiveController _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interactions = context.interactions;
    _live = context.live;
  }

  @override
  void dispose() {
    final _PendingUp? pending = _pending;
    _pending = null;
    if (pending != null) {
      // Closing the screen is not "undo". Send it; a match it makes is
      // celebrated wherever the person goes next.
      pending.timer.cancel();
      unawaited(_send(pending, onScreen: false));
    }
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

  bool _isPending(String personId) => _pending?.personId == personId;

  /// The tap on the photo (or the UP button). Queues the UP behind the undo
  /// window and moves on to the next person.
  void _queueUp(NearbyPerson person, {required bool hasNext}) {
    final AppStrings s = context.strings;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (_isPending(person.id) || _interactions.hasSentUpTo(person.id) || person.youSentUp) {
      return;
    }
    final bool isReply =
        person.sentYouUp || _interactions.incomingUpIds.contains(person.id);
    final UpQuota? quota = _live.upQuota;

    // One in the window at a time: a second tap sends the first for real.
    final _PendingUp? previous = _pending;
    if (previous != null) {
      previous.timer.cancel();
      _pending = null;
      unawaited(_send(previous, onScreen: true));
    }

    if (!isReply && quota != null && quota.isSpent) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(s.upsSpentHere)));
      return;
    }

    late final _PendingUp pending;
    pending = _PendingUp(
      personId: person.id,
      name: person.nameFor(context.session.localeCode),
      costsSlot: !isReply && quota != null,
      timer: Timer(_undoWindow, () {
        if (_pending == pending) {
          setState(() => _pending = null);
          unawaited(_send(pending, onScreen: true));
        }
      }),
    );
    if (pending.costsSlot && quota != null) {
      _live.applyUpQuota(quota.withRemaining(quota.remaining - 1));
    }
    setState(() => _pending = pending);

    if (hasNext) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          _next();
        }
      });
    }
  }

  void _undo() {
    final _PendingUp? pending = _pending;
    if (pending == null) {
      return;
    }
    pending.timer.cancel();
    if (pending.costsSlot) {
      final UpQuota? quota = _live.upQuota;
      if (quota != null) {
        _live.applyUpQuota(quota.withRemaining(quota.remaining + 1));
      }
    }
    setState(() => _pending = null);
  }

  Future<void> _send(_PendingUp pending, {required bool onScreen}) async {
    final UpResult result = await _interactions.sendUp(
      pending.personId,
      announceMatch: !onScreen || !mounted,
    );
    if (result.hasQuota) {
      _live.applyUpQuota(result.quota);
    } else if (pending.costsSlot &&
        (result.outcome == UpOutcome.failed ||
            result.outcome == UpOutcome.rateLimited)) {
      // Nothing was spent; give the slot back on screen.
      final UpQuota? quota = _live.upQuota;
      if (quota != null) {
        _live.applyUpQuota(quota.withRemaining(quota.remaining + 1));
      }
    }
    if (result.outcome == UpOutcome.quotaExhausted) {
      final UpQuota? quota = _live.upQuota;
      if (quota != null) {
        _live.applyUpQuota(quota.withRemaining(0));
      }
    }
    if (!mounted || !onScreen) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;
    switch (result.outcome) {
      case UpOutcome.matched:
        await navigator.pushNamed(Routes.match, arguments: pending.personId);
      case UpOutcome.recorded:
      case UpOutcome.duplicate:
        break;
      case UpOutcome.quotaExhausted:
        messenger.showSnackBar(SnackBar(content: Text(s.upsSpentHere)));
      case UpOutcome.rateLimited:
        messenger.showSnackBar(SnackBar(content: Text(s.errorRateLimited)));
      case UpOutcome.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(errorText(s, _interactions.lastErrorCode))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final InteractionController interactions = context.interactions;
    final LiveController live = context.live;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge(
          <Listenable>[interactions, context.people, live],
        ),
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
          final UpQuota? quota = live.upQuota;
          final _PendingUp? pending = _pending;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                controller: _pages,
                itemCount: people.length,
                itemBuilder: (BuildContext context, int index) {
                  final NearbyPerson person = people[index];
                  return _PersonPage(
                    key: ValueKey<String>(person.id),
                    person: person,
                    quota: quota,
                    pending: _isPending(person.id),
                    onUp: () => _queueUp(
                      person,
                      hasNext: index < people.length - 1,
                    ),
                  );
                },
              ),
              if (pending != null)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: _UndoPill(
                        key: ValueKey<String>(pending.personId),
                        label: context.strings.upPendingTo(pending.name),
                        undo: context.strings.upUndo,
                        window: _undoWindow,
                        onUndo: _undo,
                      ),
                    ),
                  ),
                ),
            ],
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

/// One person: their photos (swipe up/down), who they are, and the UP.
class _PersonPage extends StatefulWidget {
  const _PersonPage({
    required this.person,
    required this.quota,
    required this.pending,
    required this.onUp,
    super.key,
  });

  final NearbyPerson person;

  /// Tonight's allowance here; null = no limit.
  final UpQuota? quota;

  /// Tapped, inside the undo window.
  final bool pending;
  final VoidCallback onUp;

  @override
  State<_PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<_PersonPage> {
  final PageController _photos = PageController();
  int _photo = 0;
  int _bursts = 0;

  NearbyPerson get _person => widget.person;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  void _up({required bool sent, required bool locked}) {
    if (sent) {
      return;
    }
    if (!locked) {
      setState(() => _bursts += 1);
    }
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;
    final InteractionController interactions = context.interactions;
    final bool sent = widget.pending ||
        _person.youSentUp ||
        interactions.hasSentUpTo(_person.id);
    final bool sentYou =
        _person.sentYouUp || interactions.incomingUpIds.contains(_person.id);
    final UpQuota? quota = widget.quota;
    // Out of UPs here, and this would be a new one (answering is free).
    final bool locked = !sent && !sentYou && quota != null && quota.isSpent;
    final List<String?> keys = _person.photoKeys.isEmpty
        ? const <String?>[null]
        : _person.photoKeys;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              onTap: () => _up(sent: sent, locked: locked),
              child: PageView.builder(
                controller: _photos,
                scrollDirection: Axis.vertical,
                itemCount: keys.length,
                onPageChanged: (int i) => setState(() => _photo = i),
                itemBuilder: (BuildContext context, int i) => SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxWidth * 5 / 4,
                      child: UpPhoto(
                        photoKey: keys[i],
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
            if (keys.length > 1)
              PositionedDirectional(
                end: Insets.sm,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _PhotoDots(count: keys.length, current: _photo),
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
                    const SizedBox(height: Insets.xs),
                    Row(
                      children: <Widget>[
                        _GlassButton(
                          icon: Icons.close_rounded,
                          label: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (quota != null) _QuotaDots(quota: quota),
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
                          child: _Caption(
                            person: _person,
                            localeCode: localeCode,
                            hint: sent
                                ? null
                                : (locked ? s.upsSpentHere : s.upTapHint),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        _UpButton(
                          sent: sent,
                          locked: locked,
                          busy: false,
                          label: sent ? s.upSentShort : s.upAction,
                          onTap: sent
                              ? null
                              : () => _up(sent: sent, locked: locked),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                ),
              ),
            ),
            if (_bursts > 0)
              IgnorePointer(
                child: ConfettiBurst(
                  key: ValueKey<int>(_bursts),
                  particles: 60,
                  origin: const Alignment(0, 0.1),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "UP to Dana · Undo", with the window running out under it.
class _UndoPill extends StatelessWidget {
  const _UndoPill({
    required this.label,
    required this.undo,
    required this.window,
    required this.onUndo,
    super.key,
  });

  final String label;
  final String undo;
  final Duration window;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Material(
      color: const Color(0xCC000000),
      borderRadius: BorderRadius.circular(Radii.pill),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Insets.lg,
                end: Insets.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.arrow_upward_rounded, color: p.amber, size: 18),
                  const SizedBox(width: Insets.xs),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  TextButton(
                    onPressed: onUndo,
                    child: Text(
                      undo,
                      style: TextStyle(
                        color: p.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1, end: 0),
              duration: window,
              builder: (BuildContext context, double v, Widget? _) =>
                  LinearProgressIndicator(
                value: v,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: p.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tonight's UPs here, as dots: lit = still yours to send.
class _QuotaDots extends StatelessWidget {
  const _QuotaDots({required this.quota});

  final UpQuota quota;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Semantics(
      label: quota.isSpent
          ? context.strings.upsSpentHere
          : context.strings.upsLeftHere(quota.remaining, quota.limit),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs + 2,
        ),
        decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'UP',
              style: TextStyle(
                color: p.amber,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: Insets.xs + 2),
            for (int i = 0; i < quota.limit; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 4),
              AnimatedContainer(
                duration: Motion.fast,
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < quota.remaining ? p.amber : Colors.transparent,
                  border: Border.all(
                    color: i < quota.remaining ? p.amber : Colors.white54,
                    width: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.person,
    required this.localeCode,
    this.hint,
  });

  final NearbyPerson person;
  final String localeCode;

  /// "Tap the photo to send UP", or why you cannot.
  final String? hint;

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
        if (hint != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            hint!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xAAFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    required this.locked,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool sent;

  /// Out of UPs at this place tonight: shown, but dimmed with a lock.
  final bool locked;
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
    final bool locked = widget.locked;
    final Color fill = sent
        ? p.cyan
        : (locked ? const Color(0xFF5A5560) : p.amber);
    final Color ink = sent
        ? p.onCyan
        : (locked ? Colors.white70 : p.onAmber);

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
                    sent
                        ? Icons.check_rounded
                        : (locked
                            ? Icons.lock_rounded
                            : Icons.arrow_upward_rounded),
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

    if (sent || locked || MediaQuery.of(context).disableAnimations) {
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

/// Which photo, top to bottom — they scroll vertically.
class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 5),
          AnimatedContainer(
            duration: Motion.fast,
            width: 4,
            height: i == current ? 22 : 8,
            decoration: BoxDecoration(
              color: i == current
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(2),
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
