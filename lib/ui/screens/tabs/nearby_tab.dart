import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/nearby_person.dart';
import '../../../state/app_scope.dart';
import '../../../state/interaction_controller.dart';
import '../../../state/live_controller.dart';
import '../../../state/session_controller.dart';
import '../../components/common.dart';
import '../../components/person_card.dart';
import '../../components/up_buttons.dart';
import '../../components/up_nav_bar.dart';
import '../../navigation/routes.dart';
import '../main_shell.dart';
import 'quiet_reason.dart';

class NearbyTab extends StatelessWidget {
  const NearbyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;
    final LiveController live = context.live;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[live, interactions, session]),
      builder: (BuildContext context, Widget? _) {
        final List<NearbyPerson> people = live.visibleNearby(
          passedIds: interactions.passedIds,
          blockedIds: interactions.blockedIds,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Text(s.nearbyTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: Insets.xs),
              Text(s.nearbyBody,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Insets.lg),
              Expanded(
                child: _body(context, live: live, people: people),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context, {
    required LiveController live,
    required List<NearbyPerson> people,
  }) {
    final AppStrings s = context.strings;

    if (!live.isLive) {
      return EmptyState(
        icon: Icons.bluetooth_disabled_rounded,
        title: s.notLiveTitle,
        body: s.notLiveBody,
        action: UpButton(
          label: s.goLive.replaceAll('\n', ' '),
          expand: false,
          onPressed: () => MainShell.of(context)?.select(UpTab.home),
        ),
      );
    }

    if (people.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: s.nearbyQuietTitle,
        body: quietReason(
              strings: s,
              live: live,
              hasServer: context.backend.isConfigured,
              anyoneVisible: false,
            ) ??
            s.nearbyQuietBody,
      );
    }

    final Set<String> incoming = context.interactions.incomingUpIds;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      itemCount: people.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: Insets.md,
        mainAxisSpacing: Insets.md,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (BuildContext context, int index) {
        final NearbyPerson person = people[index];
        return PersonCard(
          person: person,
          localeCode: context.session.localeCode,
          // The server's answer first: it survives a reload, and on the mock
          // stack it is the controller that knows.
          hasSentYouAnUp: person.sentYouUp || incoming.contains(person.id),
          youSentAnUp:
              person.youSentUp || context.interactions.hasSentUpTo(person.id),
          sentLabel: s.upSentLabel,
          onTap: () => Navigator.of(context).pushNamed(
            Routes.profilePreview,
            arguments: person.id,
          ),
        );
      },
    );
  }
}
