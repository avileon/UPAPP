import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/repositories/interaction_repository.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../../state/live_controller.dart';
import '../navigation/routes.dart';
import 'confetti.dart';
import 'up_photo.dart';

/// The moments that turn the whole screen over.
///
/// Someone in the room sends you an UP, or UPs you back: wherever you are in
/// the app, the screen flips to their face, with confetti. Sits above the
/// navigator for the same reason [ArrivalAlerts] does — the point is to reach
/// you on whatever screen you happen to be looking at.
class Celebrations extends StatefulWidget {
  const Celebrations({
    required this.navigator,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<Celebrations> createState() => _CelebrationsState();
}

enum _Kind { incomingUp, match }

class _Moment {
  const _Moment(this.kind, this.person, {this.matchId});

  final _Kind kind;
  final NearbyPerson person;
  final String? matchId;
}

class _CelebrationsState extends State<Celebrations> {
  LiveController? _live;
  InteractionController? _interactions;
  StreamSubscription<NearbyPerson>? _upSubscription;
  StreamSubscription<MatchThread>? _matchSubscription;

  final List<_Moment> _queue = <_Moment>[];
  _Moment? _current;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LiveController live = context.live;
    if (!identical(live, _live)) {
      _live = live;
      _upSubscription?.cancel();
      _upSubscription = live.incomingUps.listen(_onIncomingUp);
    }
    final InteractionController interactions = context.interactions;
    if (!identical(interactions, _interactions)) {
      _interactions = interactions;
      _matchSubscription?.cancel();
      _matchSubscription = interactions.newMatches.listen(_onMatch);
    }
  }

  @override
  void dispose() {
    _upSubscription?.cancel();
    _matchSubscription?.cancel();
    super.dispose();
  }

  void _onIncomingUp(NearbyPerson person) {
    _enqueue(_Moment(_Kind.incomingUp, person));
  }

  void _onMatch(MatchThread thread) {
    final NearbyPerson? person = context.people.byId(thread.personId);
    if (person == null) {
      return;
    }
    // A match replaces a pending "they sent you an UP" for the same person:
    // it is the same story, one chapter on.
    _queue.removeWhere((_Moment m) => m.person.id == person.id);
    _enqueue(_Moment(_Kind.match, person, matchId: thread.id));
  }

  void _enqueue(_Moment moment) {
    if (!mounted) {
      return;
    }
    if (_current == null) {
      setState(() => _current = moment);
    } else {
      _queue.add(moment);
    }
  }

  void _dismiss() {
    setState(() {
      _current = _queue.isEmpty ? null : _queue.removeAt(0);
    });
  }

  Future<void> _upBack(NearbyPerson person) async {
    final InteractionController interactions = context.interactions;
    _dismiss();
    final UpResult result = await interactions.sendUp(person.id);
    if (result.outcome == UpOutcome.matched) {
      await widget.navigator.currentState
          ?.pushNamed(Routes.match, arguments: person.id);
    }
  }

  void _openChat(String? matchId) {
    _dismiss();
    if (matchId != null) {
      widget.navigator.currentState?.pushNamed(Routes.chat, arguments: matchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Moment? moment = _current;
    return Stack(
      children: <Widget>[
        widget.child,
        if (moment != null)
          Positioned.fill(
            child: _FlipCard(
              key: ValueKey<String>('${moment.kind.name}-${moment.person.id}'),
              moment: moment,
              onClose: _dismiss,
              onUpBack: () => _upBack(moment.person),
              onChat: () => _openChat(moment.matchId),
            ),
          ),
      ],
    );
  }
}

/// The screen turning over: a 3D flip from the app to their face.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    required this.moment,
    required this.onClose,
    required this.onUpBack,
    required this.onChat,
    super.key,
  });

  final _Moment moment;
  final VoidCallback onClose;
  final VoidCallback onUpBack;
  final VoidCallback onChat;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _flip.value = 1;
    } else if (!_flip.isAnimating && _flip.value == 0) {
      _flip.forward();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;
    final NearbyPerson person = widget.moment.person;
    final String name = person.nameFor(localeCode);
    final bool isMatch = widget.moment.kind == _Kind.match;

    final Widget card = Material(
      color: p.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.screen),
          child: Column(
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close_rounded, color: p.muted),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isMatch ? p.cyan : p.amber).withValues(alpha: 0.6),
                      blurRadius: 60,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: UpPhoto.circle(
                  photoKey: person.mainPhotoKey,
                  seed: person.auraSeed,
                  initial: person.initialFor(localeCode),
                  diameter: 190,
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(
                isMatch ? s.newMatchTitle(name) : s.incomingUpTitle(name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: isMatch ? p.cyan : p.amber,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: Insets.sm),
              if (!isMatch)
                Text(
                  s.incomingUpBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isMatch ? p.cyan : p.amber,
                    foregroundColor: isMatch ? p.onCyan : p.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: isMatch ? widget.onChat : widget.onUpBack,
                  icon: Icon(
                    isMatch
                        ? Icons.chat_bubble_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  label: Text(isMatch ? s.openChat : s.upBackAction),
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: widget.onClose,
                child: Text(s.laterAction),
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _flip,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutBack.transform(_flip.value);
        // From edge-on (90°) to flat — the app "turns over" to this.
        final double angle = (1 - t) * math.pi / 2;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: Colors.black.withValues(
                alpha: (0.6 * _flip.value).clamp(0.0, 1.0).toDouble(),
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: child,
            ),
            if (_flip.value > 0.35) const ConfettiBurst(particles: 160),
          ],
        );
      },
      child: card,
    );
  }
}
