import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../../state/photo_cache.dart';
import 'aura_photo.dart';

/// Someone's photo, with the aura as its resting state.
///
/// Every screen that shows a face goes through here. The placeholder is not a
/// separate "empty" widget: it is what this draws while the bytes are in
/// flight, when the person has not uploaded anything, and when the connection
/// is down — three situations that look the same to the person looking at the
/// screen and should therefore look the same on it.
class UpPhoto extends StatelessWidget {
  const UpPhoto({
    required this.photoKey,
    required this.seed,
    required this.initial,
    this.size,
    this.aspectRatio,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  const UpPhoto.circle({
    required this.photoKey,
    required this.seed,
    required this.initial,
    required double diameter,
    super.key,
  })  : size = diameter,
        aspectRatio = null,
        borderRadius = null,
        shape = BoxShape.circle;

  final String? photoKey;
  final int seed;
  final String initial;
  final double? size;
  final double? aspectRatio;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final PhotoCache cache = context.photos;

    return ListenableBuilder(
      listenable: cache,
      builder: (BuildContext context, Widget? _) {
        final Uint8List? bytes = cache.bytesFor(photoKey);
        final Widget aura = AuraPhoto(
          seed: seed,
          initial: initial,
          size: size,
          aspectRatio: aspectRatio,
          borderRadius: borderRadius,
          shape: shape,
        );
        if (bytes == null) {
          return aura;
        }

        Widget image = ClipPath(
          clipper: _ShapeClipper(
            shape: shape,
            // The same radius AuraPhoto falls back to. Different values here
            // make a tile's corners visibly tighten the moment bytes arrive.
            borderRadius: borderRadius ?? BorderRadius.circular(Radii.md),
          ),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
            // The bytes are already decoded and cached by us; letting Flutter
            // fade them in again on every rebuild makes a scrolling list
            // flicker.
            gaplessPlayback: true,
            errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
                aura,
          ),
        );

        if (aspectRatio != null) {
          image = AspectRatio(aspectRatio: aspectRatio!, child: image);
        }
        if (size != null) {
          image = SizedBox(width: size, height: size, child: image);
        }
        return ExcludeSemantics(child: image);
      },
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper({required this.shape, required this.borderRadius});

  final BoxShape shape;
  final BorderRadius borderRadius;

  @override
  Path getClip(Size size) {
    if (shape == BoxShape.circle) {
      return Path()
        ..addOval(Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.shortestSide / 2,
        ));
    }
    return Path()
      ..addRRect(borderRadius.toRRect(Offset.zero & size));
  }

  @override
  bool shouldReclip(_ShapeClipper old) =>
      old.shape != shape || old.borderRadius != borderRadius;
}
