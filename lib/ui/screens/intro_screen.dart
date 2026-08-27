import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../../state/session_controller.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Why UP is different, then the age gate.
///
/// The gate blocks. It is not a checkbox somewhere in settings, because both
/// stores treat an unenforced 18+ claim on a dating app as a rejection.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;

    return UpScaffold(
      child: ListenableBuilder(
        listenable: session,
        builder: (BuildContext context, Widget? _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.xl),
              Text(s.introTitle,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: Insets.sm),
              Text(s.introBody,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Insets.xxl),
              _Point(
                icon: Icons.visibility_outlined,
                title: s.introPoint1Title,
                body: s.introPoint1Body,
              ),
              const SizedBox(height: Insets.lg),
              _Point(
                icon: Icons.lock_outline_rounded,
                title: s.introPoint2Title,
                body: s.introPoint2Body,
              ),
              const SizedBox(height: Insets.lg),
              _Point(
                icon: Icons.bluetooth_rounded,
                title: s.introPoint3Title,
                body: s.introPoint3Body,
              ),
              const Spacer(),
              _AgeGate(
                accepted: session.acceptedTerms,
                label: s.ageGate,
                onChanged: session.setAcceptedTerms,
              ),
              const SizedBox(height: Insets.md),
              UpButton(
                label: s.cont,
                onPressed: session.acceptedTerms
                    ? () => Navigator.of(context).pushNamed(Routes.phone)
                    : null,
              ),
              const SizedBox(height: Insets.lg),
            ],
          );
        },
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.surfaceHigh,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Icon(icon, size: 17, color: p.amber),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgeGate extends StatelessWidget {
  const _AgeGate({
    required this.accepted,
    required this.label,
    required this.onChanged,
  });

  final bool accepted;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!accepted),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: accepted,
              onChanged: (bool? value) => onChanged(value ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
