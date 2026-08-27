import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../data/mock/mock_data.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';

/// Block, report and unmatch, reachable in two taps from a profile or a chat.
///
/// Report and block are separate actions on purpose: a report should be cheap
/// enough that people actually file one, and blocking someone you reported is
/// a choice, not an automatic side effect.
class SafetySheet extends StatelessWidget {
  const SafetySheet({required this.personId, super.key});

  final String personId;

  static Future<void> show(BuildContext context, String personId) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafetySheet(personId: personId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;
    final NearbyPerson? person = MockData.byId(personId);
    final MatchThread? match = interactions.matchForPerson(personId);
    final String name =
        person?.nameFor(context.session.localeCode) ?? '';

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
            SectionLabel(name),
            const SizedBox(height: Insets.md),
            if (match != null) ...<Widget>[
              UpButton(
                label: s.unmatch,
                style: UpButtonStyle.ghost,
                onPressed: () => _unmatch(context, match.id),
              ),
              const SizedBox(height: Insets.sm),
            ],
            UpButton(
              label: s.report,
              style: UpButtonStyle.ghost,
              onPressed: () => _report(context, s.reportSent),
            ),
            const SizedBox(height: Insets.sm),
            UpButton(
              label: s.block,
              style: UpButtonStyle.danger,
              onPressed: () => _block(context, s.blockedDone(name)),
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
  }

  Future<void> _unmatch(BuildContext context, String matchId) async {
    final NavigatorState navigator = Navigator.of(context);
    await context.interactions.unmatch(matchId);
    navigator.pop();
    navigator.pop();
  }

  Future<void> _report(BuildContext context, String confirmation) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await context.interactions.report(personId);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  Future<void> _block(BuildContext context, String confirmation) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await context.interactions.block(personId);
    navigator.pop();
    if (navigator.canPop()) {
      navigator.pop();
    }
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }
}
