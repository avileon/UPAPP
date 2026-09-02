import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../navigation/routes.dart';
import 'up_alert_banner.dart';
import 'up_photo.dart';

/// Listens for arriving messages and puts a name on screen.
///
/// This sits above the navigator rather than inside a tab, because the
/// complaint it answers is precisely about being *somewhere else* when a
/// message lands. A widget under the shell can only be seen from the shell.
class ArrivalAlerts extends StatefulWidget {
  const ArrivalAlerts({
    required this.navigator,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<ArrivalAlerts> createState() => _ArrivalAlertsState();
}

class _ArrivalAlertsState extends State<ArrivalAlerts> {
  InteractionController? _interactions;
  StreamSubscription<MatchThread>? _subscription;
  UpAlert? _alert;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The whole stack is rebuilt when the server changes, taking the
    // controller with it. Re-subscribe rather than hold a dead stream.
    final InteractionController interactions = context.interactions;
    if (identical(interactions, _interactions)) {
      return;
    }
    _interactions = interactions;
    _subscription?.cancel();
    _subscription = interactions.arrivals.listen(_onArrival);
  }

  void _onArrival(MatchThread thread) {
    if (!mounted) {
      return;
    }
    final AppStrings s = context.strings;
    final String localeCode = context.session.localeCode;
    final NearbyPerson? person = context.people.byId(thread.personId);
    final String name = person?.nameFor(localeCode) ?? s.newMessageLabel;

    setState(() {
      _alert = UpAlert(
        // Keyed on the thread: a burst from one person collapses into one
        // banner that keeps updating, instead of a stack of five.
        id: thread.id,
        title: name,
        body: thread.lastMessage?.body ?? s.chatOpener,
        avatar: person == null
            ? null
            : UpPhoto.circle(
                photoKey: person.mainPhotoKey,
                seed: person.auraSeed,
                initial: person.initialFor(localeCode),
                diameter: 38,
              ),
        onOpen: () => _open(thread.id),
      );
    });
  }

  void _open(String matchId) {
    _interactions?.markRead(matchId);
    widget.navigator.currentState?.pushNamed(
      Routes.chat,
      arguments: matchId,
    );
  }

  void _dismiss() {
    if (mounted) {
      setState(() => _alert = null);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: UpAlertBanner(
            alert: _alert,
            onDismiss: _dismiss,
            duration: const Duration(seconds: 6),
          ),
        ),
      ],
    );
  }
}

/// Formats "when" for a chat row, in the few words that fit beside a name.
///
/// Not `intl`'s relative formatter: this needs to be short enough to sit at
/// the end of a row without pushing the name out, and it has to read naturally
/// in Hebrew as well as English. Four cases cover everything a chat list ever
/// needs to say.
String shortRelativeTime(DateTime when, AppStrings s, {DateTime? now}) {
  final Duration age = (now ?? DateTime.now()).difference(when);
  if (age.inMinutes < 1) {
    return s.justNow;
  }
  if (age.inMinutes < 60) {
    return '${age.inMinutes} ${s.unitMinuteShort}';
  }
  if (age.inHours < 24) {
    return '${age.inHours} ${s.unitHourShort}';
  }
  return '${age.inDays} ${s.unitDayShort}';
}

/// A dot that says "there is something here" without shouting a number.
class UnreadDot extends StatelessWidget {
  const UnreadDot({this.size = 10, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color fill = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: fill.withValues(alpha: 0.45),
            blurRadius: Insets.sm,
          ),
        ],
      ),
    );
  }
}
