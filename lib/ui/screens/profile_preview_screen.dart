import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/repositories/interaction_repository.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/aura_photo.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';
import 'safety_sheet.dart';

/// One profile, two actions.
///
/// There is no swipe deck here. A gesture can be added later as a shortcut,
/// but it must never become the mechanism: UP is a decision about a specific
/// person you can see, not a rhythm you fall into.
class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final InteractionController interactions = context.interactions;
    final NearbyPerson? person = context.people.byId(personId);

    if (person == null) {
      return UpScaffold(
        child: Column(
          children: <Widget>[
            UpTopBar(onBack: () => Navigator.of(context).pop()),
            const Spacer(),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        final String localeCode = context.session.localeCode;
        final bool alreadySent = interactions.hasSentUpTo(person.id);
        final bool sentYouAnUp =
            interactions.incomingUpIds.contains(person.id);

        return UpScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UpTopBar(
                onBack: () => Navigator.of(context).pop(),
                trailing: UpIconButton(
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: s.more,
                  onPressed: () => SafetySheet.show(context, person.id),
                ),
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: AuraPhoto(
                        seed: person.auraSeed,
                        initial: person.initialFor(localeCode),
                        aspectRatio: 4 / 5,
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          person.nameFor(localeCode),
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(fontSize: 26),
                        ),
                        Text(
                          '${person.age}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                color: p.muted,
                              ),
                        ),
                        if (person.isPhotoVerified)
                          VerifiedBadge(label: s.verifiedBadge),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      person.bioFor(localeCode),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Insets.lg),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: UpTag(label: s.nearYouNow),
                    ),
                    if (sentYouAnUp) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      UpCard(
                        borderColor: p.amber,
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.arrow_upward_rounded,
                                color: p.amber, size: 20),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Text(
                                s.incomingUps(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.xl),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircleAction(
                    icon: Icons.close_rounded,
                    semanticLabel: s.pass,
                    onPressed: () => _pass(context, person.id),
                  ),
                  const SizedBox(width: Insets.md),
                  CircleAction(
                    icon: Icons.arrow_upward_rounded,
                    semanticLabel: 'UP',
                    emphasized: true,
                    onPressed:
                        alreadySent ? null : () => _sendUp(context, person),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              SizedBox(
                height: 20,
                child: Center(
                  child: Text(
                    alreadySent
                        ? s.upSentLabel
                        : (sentYouAnUp ? s.upBack : ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
          ),
        );
      },
    );
  }

  void _pass(BuildContext context, String id) {
    context.interactions.pass(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.passedAway)),
    );
    Navigator.of(context).pop();
  }

  Future<void> _sendUp(BuildContext context, NearbyPerson person) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;
    final String name = person.nameFor(context.session.localeCode);

    final UpResult result = await context.interactions.sendUp(person.id);

    switch (result.outcome) {
      case UpOutcome.matched:
        navigator.pop();
        await navigator.pushNamed(Routes.match, arguments: person.id);
      case UpOutcome.recorded:
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text(s.upSentTo(name))),
        );
      case UpOutcome.duplicate:
        navigator.pop();
      case UpOutcome.rateLimited:
        messenger.showSnackBar(
          SnackBar(content: Text(s.upSentLabel)),
        );
    }
  }
}
