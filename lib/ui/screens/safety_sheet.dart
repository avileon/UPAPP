import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../state/people_directory.dart';
import '../../state/interaction_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';

/// Block, report and unmatch, reachable in two taps from a profile or a chat.
///
/// Report and block are separate actions on purpose: a report should be cheap
/// enough that people actually file one, and blocking someone you reported is
/// a choice, not an automatic side effect.
class SafetySheet extends StatelessWidget {
  const SafetySheet({
    required this.personId,
    this.closeScreen = true,
    super.key,
  });

  final String personId;

  /// Whether blocking also closes the screen underneath. The people viewer
  /// says no: the blocked person drops out and the next one is already there.
  final bool closeScreen;

  static Future<void> show(
    BuildContext context,
    String personId, {
    bool closeScreen = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          SafetySheet(personId: personId, closeScreen: closeScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;
    final NearbyPerson? person = context.people.byId(personId);
    final MatchThread? match = interactions.matchForPerson(personId);
    final String name =
        person?.nameFor(context.session.localeCode) ?? '';

    return SafeArea(
      child: SingleChildScrollView(
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
            if (context.live.isLive && match == null) ...<Widget>[
              UpButton(
                label: s.hideForVisit,
                icon: Icons.visibility_off_rounded,
                style: UpButtonStyle.ghost,
                onPressed: () => _hide(context, s.hiddenDone(name)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs, bottom: Insets.sm),
                child: Text(
                  s.hideForVisitHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            UpButton(
              label: s.report,
              style: UpButtonStyle.ghost,
              onPressed: () => _report(context, s.reportSent),
            ),
            const SizedBox(height: Insets.sm),
            UpButton(
              label: s.block,
              icon: Icons.block_rounded,
              style: UpButtonStyle.danger,
              onPressed: () => _block(context, s.blockedDone(name)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                s.blockHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
      ),
    );
  }

  Future<void> _unmatch(BuildContext context, String matchId) async {
    final NavigatorState navigator = Navigator.of(context);
    await context.interactions.unmatch(matchId);
    navigator.pop();
    navigator.pop();
  }

  void _hide(BuildContext context, String confirmation) {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    context.interactions.pass(personId);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
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
    final PeopleDirectory people = context.people;
    await context.interactions.block(personId);
    // Nothing about someone the user has blocked should survive in the app's
    // memory either.
    people.forget(personId);
    navigator.pop();
    if (closeScreen && navigator.canPop()) {
      navigator.pop();
    }
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }
}
