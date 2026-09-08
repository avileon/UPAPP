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
              // Two different claims, and a card can carry both. The checked
              // selfie is the stronger one — somebody looked — so it sits
              // first and gets the filled badge; the peer one keeps the quiet
              // ring it always had.
              if (person.isSelfieVerified || person.isPhotoVerified)
                PositionedDirectional(
                  top: Insets.sm,
                  start: Insets.sm,
                  child: Row(
                    children: <Widget>[
                      if (person.isSelfieVerified)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: p.cyan,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: p.cyan.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: p.onCyan,
                          ),
                        ),
                      if (person.isSelfieVerified && person.isPhotoVerified)
                        const SizedBox(width: 3),
                      if (person.isPhotoVerified)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: person.isSelfieVerified
                                ? Colors.transparent
                                : p.cyan,
                            shape: BoxShape.circle,
                            border: person.isSelfieVerified
                                ? Border.all(color: p.cyan, width: 1.4)
                                : null,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: person.isSelfieVerified ? p.cyan : p.onCyan,
                          ),
                        ),
                    ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
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
                    // What they said they are doing, right now. This is the
                    // line that turns a face into somebody you have a reason
                    // to walk over to, and it is worth more space on this card
                    // than anything else that could go here.
                    if (person.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        person.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xF2FFFFFF),
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          shadows: <Shadow>[
                            Shadow(blurRadius: 6, color: Color(0x99000000)),
                          ],
                        ),
                      ),
                    ],
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
