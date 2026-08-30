import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/nearby_person.dart';
import 'up_photo.dart';

/// One tile in the Nearby grid.
///
/// Shows a photo, a first name and an age. No distance, no "last seen", no
/// online dot — everyone in this grid is here now, which is the whole point.
class PersonCard extends StatelessWidget {
  const PersonCard({
    required this.person,
    required this.localeCode,
    required this.onTap,
    this.hasSentYouAnUp = false,
    this.youSentAnUp = false,
    this.sentLabel = '',
    super.key,
  });

  final NearbyPerson person;
  final String localeCode;
  final VoidCallback onTap;
  final bool hasSentYouAnUp;

  /// You already UP'd this person. Quieter than the incoming badge on purpose:
  /// one is news, the other is a reminder of something you did.
  final bool youSentAnUp;

  /// The wording for [youSentAnUp]. Passed in rather than read from context so
  /// this component stays a pure view.
  final String sentLabel;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final String name = person.nameFor(localeCode);

    return Semantics(
      button: true,
      label: '$name, ${person.age}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              UpPhoto(
                photoKey: person.mainPhotoKey,
                seed: person.auraSeed,
                initial: person.initialFor(localeCode),
                aspectRatio: 3 / 4,
                size: null,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00000000),
                        Color(0xD1000000),
                      ],
                    ),
                  ),
                ),
              ),
              if (person.isPhotoVerified)
                PositionedDirectional(
                  top: Insets.sm,
                  start: Insets.sm,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: p.cyan,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: p.onCyan,
                    ),
                  ),
                ),
              if (!hasSentYouAnUp && youSentAnUp && sentLabel.isNotEmpty)
                PositionedDirectional(
                  top: Insets.sm,
                  end: Insets.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: p.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 11,
                          color: p.dim,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          sentLabel,
                          style: TextStyle(
                            color: p.dim,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasSentYouAnUp)
                PositionedDirectional(
                  top: Insets.sm,
                  end: Insets.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: p.amber,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      'UP',
                      style: TextStyle(
                        color: p.onAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: Insets.md,
                end: Insets.md,
                bottom: Insets.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs + 2),
                    Text(
                      '${person.age}',
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
