import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/user_profile.dart';
import '../../state/app_scope.dart';
import '../../state/photo_cache.dart';
import '../../state/session_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_photo.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

class PhotosSetupScreen extends StatefulWidget {
  const PhotosSetupScreen({super.key});

  @override
  State<PhotosSetupScreen> createState() => _PhotosSetupScreenState();
}

class _PhotosSetupScreenState extends State<PhotosSetupScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  /// Picks a photo and uploads it.
  ///
  /// The downscale happens in the picker rather than after: 1440px on the long
  /// edge at quality 85 is more than any screen in the app can show, and it
  /// turns a 6 MB camera JPEG into a few hundred kilobytes before it ever
  /// touches the uplink. On a phone tethered to a laptop over a tunnel, that
  /// is the difference between instant and a spinner.
  Future<void> _pick() async {
    final SessionController session = context.session;
    final PhotoCache cache = context.photos;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;

    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 85,
      );
    } on Exception {
      // A picker that will not open (no gallery app, permission withdrawn) is
      // not a crash — it is a photo that did not get added.
      file = null;
    }
    if (file == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final Uint8List bytes = await file.readAsBytes();
    final String? key = await session.addPhoto(bytes);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (key == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(session.errorMessage(s))),
      );
      return;
    }
    // Show it from the bytes already in hand rather than downloading back the
    // picture the person just chose.
    cache.remember(key, bytes);
  }

  Future<void> _remove(String key) async {
    final SessionController session = context.session;
    final PhotoCache cache = context.photos;
    setState(() => _busy = true);
    await session.removePhoto(key);
    cache.forget(key);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

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
          final List<String> keys = profile.photoKeys;

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
                    if (index < keys.length) {
                      return _FilledSlot(
                        photoKey: keys[index],
                        seed: index,
                        initial: initial,
                        isMain: index == 0,
                        mainLabel: s.mainPhoto,
                        removeLabel: s.removePhoto,
                        onRemove: _busy ? null : () => _remove(keys[index]),
                      );
                    }
                    if (index > keys.length) {
                      // Only one empty slot is offered at a time. A grid of six
                      // identical dashed boxes reads as six things to do.
                      return const SizedBox.shrink();
                    }
                    return _EmptySlot(
                      label: _busy ? s.uploading : s.addPhoto,
                      onTap: _busy ? null : _pick,
                    );
                  },
                ),
              ),
              const SizedBox(height: Insets.lg),
              if (keys.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Text(
                    s.photosNoneYet,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
    required this.photoKey,
    required this.seed,
    required this.initial,
    required this.isMain,
    required this.mainLabel,
    required this.removeLabel,
    required this.onRemove,
  });

  final String photoKey;
  final int seed;
  final String initial;
  final bool isMain;
  final String mainLabel;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: UpPhoto(photoKey: photoKey, seed: seed, initial: initial),
        ),
        if (isMain)
          PositionedDirectional(
            top: Insets.sm,
            start: Insets.sm,
            child: UpTag(label: mainLabel, emphasized: true),
          ),
        PositionedDirectional(
          top: Insets.xs,
          end: Insets.xs,
          child: Semantics(
            label: removeLabel,
            button: true,
            child: IconButton(
              onPressed: onRemove,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0x99000000),
                foregroundColor: const Color(0xFFFFFFFF),
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

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
                textAlign: TextAlign.center,
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
