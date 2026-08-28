import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/reality_answer.dart';
import '../../state/app_scope.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_scaffold.dart';
import '../components/up_photo.dart';

/// Reality Check.
///
/// The rules that keep this from becoming a rating system:
///   * the question is about photos, never about the person;
///   * the answer is anonymous and the count is never shown;
///   * only a match that produced a real conversation can answer, once;
///   * a single "no" does not remove anyone's badge — see [RealityBadgeRules].
class RealityCheckScreen extends StatelessWidget {
  const RealityCheckScreen({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;

    return ListenableBuilder(
      listenable: context.interactions,
      builder: (BuildContext context, Widget? _) {
        final MatchThread? match = context.interactions.matchById(matchId);
        final NearbyPerson? person =
            match == null ? null : context.people.byId(match.personId);
        if (match == null || person == null) {
          return const UpScaffold(child: SizedBox.shrink());
        }

        if (match.realityAnswer != null) {
          return UpScaffold(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: p.onCyan,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, color: p.cyan, size: 26),
                  ),
                  const SizedBox(height: Insets.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      s.realityThanks,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: Insets.xxl),
                  UpButton(
                    label: s.cont,
                    expand: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        }

        return UpScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                UpPhoto.circle(
                  photoKey: person.mainPhotoKey,
                  seed: person.auraSeed,
                  initial: person.initialFor(localeCode),
                  diameter: 72,
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  s.realityTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: Insets.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: Text(
                    s.realityBody(person.nameFor(localeCode)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: Insets.xxl),
                Wrap(
                  spacing: Insets.md,
                  runSpacing: Insets.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    UpChip(
                      label: s.realityYes,
                      selected: false,
                      onSelected: () =>
                          _answer(context, RealityAnswer.yes),
                    ),
                    UpChip(
                      label: s.realitySomewhat,
                      selected: false,
                      onSelected: () =>
                          _answer(context, RealityAnswer.somewhat),
                    ),
                    UpChip(
                      label: s.realityNo,
                      selected: false,
                      onSelected: () => _answer(context, RealityAnswer.no),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    s.realityNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                UpButton(
                  label: s.later,
                  style: UpButtonStyle.quiet,
                  expand: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _answer(BuildContext context, RealityAnswer answer) {
    return context.interactions.submitReality(matchId, answer);
  }
}
