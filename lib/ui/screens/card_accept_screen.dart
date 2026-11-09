import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/card_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/api_client.dart';
import '../../data/api/backend_config.dart';
import '../../data/api/card_api.dart';
import '../../domain/entities/match_thread.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/common.dart';
import '../components/confetti.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Someone handed you their card (`/app?card=TOKEN`), and you are signed in.
///
/// One question: UP or not now. An UP here is always a match — giving the card
/// was their UP — so the next screen is the chat.
///
/// The pending token is cleared only once this is settled (answered, declined,
/// or the card is gone). Leaving for the face check and coming back, even
/// after closing the app, lands here again.
class CardAcceptScreen extends StatefulWidget {
  const CardAcceptScreen({required this.token, super.key});

  final String token;

  @override
  State<CardAcceptScreen> createState() => _CardAcceptScreenState();
}

enum _Phase { loading, ready, sending, matched, gone }

class _CardAcceptScreenState extends State<CardAcceptScreen> {
  _Phase _phase = _Phase.loading;
  CardInfo? _card;
  String? _error;
  bool _needsVerification = false;
  String? _matchId;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _backend = context.backend;
    _lookup();
  }

  late BackendConfig _backend;

  Future<void> _settle() => _backend.setCardToken('');

  Future<void> _lookup() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    final CardApi? api = context.cards;
    final AppStrings s = context.strings;
    if (api == null) {
      setState(() => _phase = _Phase.gone);
      return;
    }
    try {
      final CardInfo card = await api.lookup(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _card = card;
        _phase = _Phase.ready;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.status == 410) {
        await _settle();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _error = errorText(s, error.code);
        _phase = _Phase.gone;
      });
    }
  }

  Future<void> _sendUp() async {
    final CardApi? api = context.cards;
    final InteractionController interactions = context.interactions;
    final AppStrings s = context.strings;
    if (api == null) {
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
      _needsVerification = false;
    });
    try {
      final CardAnswer answer = await api.answer(widget.token);
      // Celebrated right here; the poll must not celebrate it again.
      interactions.claimMatch(answer.matchId);
      await _settle();
      if (!mounted) {
        return;
      }
      setState(() {
        _matchId = answer.matchId;
        _phase = _Phase.matched;
      });
    } on ApiException catch (error) {
      if (error.status == 410) {
        await _settle();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _needsVerification = error.code == 'verification_required';
        _error = _needsVerification ? s.cardVerifyFirst : errorText(s, error.code);
        _phase = error.status == 410 ? _Phase.gone : _Phase.ready;
      });
    }
  }

  Future<void> _notNow() async {
    final NavigatorState navigator = Navigator.of(context);
    await _settle();
    navigator.pop();
  }

  Future<void> _verify() async {
    await Navigator.of(context).pushNamed(Routes.verify);
    if (mounted) {
      setState(() {
        _needsVerification = false;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final CardInfo? card = _card;
    final String name = card?.firstName.isNotEmpty ?? false ? card!.firstName : 'AppDate';

    return UpScaffold(
      child: Stack(
        children: <Widget>[
          ListView(
            children: <Widget>[
              UpTopBar(onBack: () => Navigator.of(context).pop()),
              if (_phase == _Phase.loading)
                const Padding(
                  padding: EdgeInsets.all(Insets.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_phase == _Phase.gone || card == null)
                UpCard(
                  child: Text(
                    _error ?? s.cardError('card_unknown')!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: card.hasPhoto
                        ? Image.network(
                            context.cards!.photoUrl(widget.token),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _Initial(name: name, palette: p),
                          )
                        : _Initial(name: name, palette: p),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Wrap(
                  spacing: Insets.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _phase == _Phase.matched ? s.cardMatched : s.cardFrom(name),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (card.verified && _phase != _Phase.matched)
                      VerifiedBadge(label: s.verifiedBadge),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (_phase != _Phase.matched)
                  Text(s.cardLead, style: Theme.of(context).textTheme.bodyMedium),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  UpCard(
                    borderColor: _needsVerification ? p.cyan : p.danger,
                    child: Text(_error!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
                const SizedBox(height: Insets.xl),
                if (_phase == _Phase.matched)
                  _ToChat(matchId: _matchId!)
                else if (_needsVerification)
                  UpButton(
                    label: s.cardVerifyAction,
                    icon: Icons.face_rounded,
                    onPressed: _verify,
                  )
                else
                  UpButton(
                    label: s.cardSendUp,
                    icon: Icons.arrow_upward_rounded,
                    onPressed: _phase == _Phase.sending ? null : _sendUp,
                  ),
                if (_phase != _Phase.matched) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  UpButton(
                    label: s.cardNotNow,
                    style: UpButtonStyle.quiet,
                    onPressed: _notNow,
                  ),
                ],
                const SizedBox(height: Insets.xl),
              ],
            ],
          ),
          if (_phase == _Phase.matched)
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiBurst()),
            ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.palette});

  final String name;
  final UpPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.surfaceHigh,
      child: Center(
        child: Text(
          name.substring(0, 1),
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(fontSize: 96, color: palette.amber),
        ),
      ),
    );
  }
}

/// Waits for the poll to bring the new thread in, then opens it.
class _ToChat extends StatelessWidget {
  const _ToChat({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;
    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        final MatchThread? thread = interactions.matchById(matchId);
        return UpButton(
          label: thread == null ? s.cardOpeningChat : s.cardToChat,
          icon: Icons.chat_bubble_rounded,
          onPressed: thread == null
              ? null
              : () {
                  interactions.markRead(matchId);
                  Navigator.of(context)
                      .pushReplacementNamed(Routes.chat, arguments: matchId);
                },
        );
      },
    );
  }
}
