import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../state/app_scope.dart';
import '../../../state/session_controller.dart';
import '../../components/up_photo.dart';
import '../../components/common.dart';
import '../../components/up_buttons.dart';
import '../../components/up_chip.dart';
import '../../navigation/routes.dart';

/// No like counts, no view counts, no score. The only badge here is about
/// photo honesty, and it is the same badge other people see.
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;

    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        final UserProfile profile = session.draftProfile;
        final String name = profile.firstName.isEmpty
            ? (s.localeCode == 'he' ? 'אבי' : 'Avi')
            : profile.firstName;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: ListView(
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(s.myProfile,
                      style: Theme.of(context).textTheme.headlineMedium),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Routes.settings),
                    child: SectionLabel(s.settingsTitle),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.lg),
                child: UpPhoto(
                  photoKey: profile.mainPhotoKey,
                  seed: 0,
                  initial: name.substring(0, 1),
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
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontSize: 25),
                  ),
                  Text(
                    '${profile.ageAt(DateTime.now())}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          color: context.palette.muted,
                        ),
                  ),
                  VerifiedBadge(label: s.verifiedBadge),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(
                profile.bio.isEmpty ? s.bioHint : profile.bio,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.xl),
              UpButton(
                label: s.editPhotos,
                style: UpButtonStyle.ghost,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.photosSetup),
              ),
              const SizedBox(height: Insets.sm),
              UpButton(
                label: s.editDetails,
                style: UpButtonStyle.ghost,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.profileSetup),
              ),
              const SizedBox(height: Insets.xl),
            ],
          ),
        );
      },
    );
  }
}
