import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/mock/mock_data.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../components/aura_photo.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// The emotional peak of the product, and the only screen allowed a flourish.
class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.personId, super.key});

  final String personId;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  )..forward();

  late final Animation<double> _bloom = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;
    final NearbyPerson? person = MockData.byId(widget.personId);

    if (person == null) {
      return const UpScaffold(child: SizedBox.shrink());
    }

    final String myInitial = () {
      final String name = context.session.draftProfile.firstName;
      return name.isEmpty ? 'A' : name.substring(0, 1);
    }();

    return UpScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  FadeTransition(
                    opacity: _bloom,
                    child: ScaleTransition(
                      scale: _bloom,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[p.glow, p.background],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Portrait(
                        seed: 0,
                        initial: myInitial,
                        borderColor: p.background,
                      ),
                      Transform.translate(
                        offset: const Offset(-22, 0),
                        child: _Portrait(
                          seed: person.auraSeed,
                          initial: person.initialFor(localeCode),
                          borderColor: p.background,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              s.matchTitle,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: Insets.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                s.matchBody(person.nameFor(localeCode)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: Insets.xxl),
            UpButton(
              label: s.sayHi,
              onPressed: () => _openChat(context, person.id),
            ),
            UpButton(
              label: s.keepLooking,
              style: UpButtonStyle.quiet,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String personId) {
    final MatchThread? match = context.interactions.matchForPerson(personId);
    if (match == null) {
      Navigator.of(context).pop();
      return;
    }
    context.interactions.markRead(match.id);
    Navigator.of(context)
        .pushReplacementNamed(Routes.chat, arguments: match.id);
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.seed,
    required this.initial,
    required this.borderColor,
  });

  final int seed;
  final String initial;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: AuraPhoto.circle(seed: seed, initial: initial, diameter: 96),
    );
  }
}
