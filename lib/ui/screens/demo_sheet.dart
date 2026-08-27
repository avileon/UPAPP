import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../../state/live_controller.dart';
import '../../state/session_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../navigation/routes.dart';

/// Demo controls.
///
/// UP cannot be evaluated alone — the whole product needs a second person in
/// the room. Until Milestone 3 puts two real phones in range, this sheet stands
/// in for the radio and the server so the flow can be judged on one device.
/// It is gated behind [kDemoControlsEnabled] and comes out with the mocks.
const bool kDemoControlsEnabled = true;

class DemoSheet extends StatelessWidget {
  const DemoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const DemoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[live, interactions]),
      builder: (BuildContext context, Widget? _) {
        final bool canAct = live.isLive;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.screen,
              Insets.lg,
              Insets.screen,
              Insets.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SectionLabel(s.demoTitle),
                const SizedBox(height: Insets.sm),
                Text(s.demoBody,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Insets.lg),
                UpButton(
                  label: s.demoDiscover,
                  style: UpButtonStyle.ghost,
                  onPressed: canAct ? live.discoverOneMore : null,
                ),
                const SizedBox(height: Insets.sm),
                UpButton(
                  label: s.demoIncomingUp,
                  style: UpButtonStyle.ghost,
                  onPressed:
                      canAct ? () => _incomingUp(context) : null,
                ),
                const SizedBox(height: Insets.sm),
                UpButton(
                  label: s.demoForceMatch,
                  style: UpButtonStyle.ghost,
                  onPressed: canAct ? () => _forceMatch(context) : null,
                ),
                const SizedBox(height: Insets.sm),
                UpButton(
                  label: s.demoReset,
                  style: UpButtonStyle.danger,
                  onPressed: () => _reset(context),
                ),
                const SizedBox(height: Insets.sm),
                UpButton(
                  label: s.cancel,
                  style: UpButtonStyle.quiet,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  NearbyPerson? _pickTarget(BuildContext context) {
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;
    final List<NearbyPerson> people = live.visibleNearby(
      passedIds: interactions.passedIds,
      blockedIds: interactions.blockedIds,
    );
    if (people.isEmpty) {
      live.discoverOneMore();
      return null;
    }
    for (final NearbyPerson person in people) {
      if (interactions.matchForPerson(person.id) == null &&
          !interactions.incomingUpIds.contains(person.id)) {
        return person;
      }
    }
    return people.first;
  }

  void _incomingUp(BuildContext context) {
    final NearbyPerson? target = _pickTarget(context);
    if (target == null) {
      return;
    }
    context.interactions.simulateIncomingUp(target.id);
    Navigator.of(context).pop();
  }

  Future<void> _forceMatch(BuildContext context) async {
    final NearbyPerson? target = _pickTarget(context);
    if (target == null) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final InteractionController interactions = context.interactions;
    interactions.simulateIncomingUp(target.id);
    await interactions.sendUp(target.id);
    navigator.pop();
    await navigator.pushNamed(Routes.match, arguments: target.id);
  }

  Future<void> _reset(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;
    final SessionController session = context.session;

    interactions.reset();
    await live.stop();
    session.resetForDemo();

    navigator.pushNamedAndRemoveUntil(
      Routes.splash,
      (Route<dynamic> route) => false,
    );
  }
}
