import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/card_strings.dart';
import '../../../core/l10n/dating_strings.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../state/app_scope.dart';
import '../../../state/session_controller.dart';
import '../../../state/verification_controller.dart';
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
              const _GraceBanner(),
              const SizedBox(height: Insets.xl),
              UpButton(
                label: s.myCard,
                icon: Icons.qr_code_2_rounded,
                onPressed: () => Navigator.of(context).pushNamed(Routes.myCard),
              ),
              const SizedBox(height: Insets.sm),
              UpButton(
                label: s.editPhotos,
                style: UpButtonStyle.ghost,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.photosSetup),
              ),
              const SizedBox(height: Insets.sm),
              UpButton(
                label: s.verifyToGoLive,
                icon: Icons.face_rounded,
                style: UpButtonStyle.ghost,
                onPressed: () => Navigator.of(context).pushNamed(Routes.verify),
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

/// "New account: you can use everything for N more hours" — until the
/// verification is approved. Nothing when approved or when there is no grace.
class _GraceBanner extends StatefulWidget {
  const _GraceBanner();

  @override
  State<_GraceBanner> createState() => _GraceBannerState();
}

class _GraceBannerState extends State<_GraceBanner> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_asked) {
      _asked = true;
      context.verification?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final VerificationController? verification = context.verification;
    if (verification == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: verification,
      builder: (BuildContext context, Widget? _) {
        final DateTime? ends = verification.graceEndsAt;
        if (ends == null || verification.status == VerificationStatus.approved) {
          return const SizedBox.shrink();
        }
        final Duration left = ends.difference(DateTime.now());
        if (left.isNegative) {
          return const SizedBox.shrink();
        }
        final UpPalette p = context.palette;
        return Padding(
          padding: const EdgeInsets.only(top: Insets.lg),
          child: UpCard(
            borderColor: p.amber,
            onTap: () => Navigator.of(context).pushNamed(Routes.verify),
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.hourglass_top_rounded, color: p.amber),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    context.strings.graceBanner(left.inHours + 1),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
