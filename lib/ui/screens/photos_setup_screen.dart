import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/user_profile.dart';
import '../../state/app_scope.dart';
import '../../state/session_controller.dart';
import '../components/aura_photo.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

class PhotosSetupScreen extends StatelessWidget {
  const PhotosSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;

    return UpScaffold(
      child: ListenableBuilder(
        listenable: session,
        builder: (BuildContext context, Widget? _) {
          final UserProfile profile = session.draftProfile;
          final String initial = profile.firstName.isEmpty
              ? 'U'
              : profile.firstName.substring(0, 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UpTopBar(onBack: () => Navigator.of(context).pop()),
              Text(s.photosTitle,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: Insets.sm),
              Text(s.photosBody,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Insets.xl),
              Expanded(
                child: GridView.builder(
                  itemCount: UserProfile.maxPhotos,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: Insets.md,
                    mainAxisSpacing: Insets.md,
                    childAspectRatio: 3 / 4,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    if (index < profile.photoCount) {
                      return _FilledSlot(
                        seed: index,
                        initial: initial,
                        isMain: index == 0,
                        mainLabel: s.mainPhoto,
                      );
                    }
                    return _EmptySlot(
                      label: s.addPhoto,
                      onTap: session.addPhoto,
                    );
                  },
                ),
              ),
              const SizedBox(height: Insets.lg),
              UpButton(
                label: s.cont,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.permissions),
              ),
              const SizedBox(height: Insets.lg),
            ],
          );
        },
      ),
    );
  }
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({
    required this.seed,
    required this.initial,
    required this.isMain,
    required this.mainLabel,
  });

  final int seed;
  final String initial;
  final bool isMain;
  final String mainLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AuraPhoto(seed: seed, initial: initial),
        ),
        if (isMain)
          PositionedDirectional(
            top: Insets.sm,
            start: Insets.sm,
            child: UpTag(label: mainLabel, emphasized: true),
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: DottedBorderBox(
        color: p.line,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, color: p.dim, size: 22),
              const SizedBox(height: Insets.xs),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.dim, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed outline without pulling in a package for it.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    required this.color,
    required this.child,
    super.key,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(Radii.md),
    );
    final Path path = Path()..addRRect(rect);

    const double dash = 6;
    const double gap = 5;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
