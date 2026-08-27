import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/aura_photo.dart';
import '../components/common.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';
import 'safety_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _realityOffered = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _input.text;
    if (text.trim().isEmpty) {
      return;
    }
    _input.clear();
    await context.interactions.sendMessage(widget.matchId, text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.fast,
        curve: Curves.easeOut,
      );
    });
  }

  /// Reality Check arrives on its own, once a match has actually turned into a
  /// conversation. Nobody goes looking for a feedback form.
  void _maybeOfferRealityCheck(MatchThread match) {
    if (_realityOffered || !match.isEligibleForRealityCheck) {
      return;
    }
    _realityOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }
      await Navigator.of(context)
          .pushNamed(Routes.realityCheck, arguments: match.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final InteractionController interactions = context.interactions;
    final String localeCode = context.session.localeCode;

    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        final MatchThread? match = interactions.matchById(widget.matchId);
        if (match == null) {
          return UpScaffold(
            child: Column(
              children: <Widget>[
                UpTopBar(onBack: () => Navigator.of(context).pop()),
                const Spacer(),
              ],
            ),
          );
        }
        final NearbyPerson? person = context.people.byId(match.personId);
        _maybeOfferRealityCheck(match);
        _scrollToEnd();

        return UpScaffold(
          child: Column(
            children: <Widget>[
              UpTopBar(
                onBack: () => Navigator.of(context).pop(),
                leading: person == null
                    ? null
                    : AuraPhoto.circle(
                        seed: person.auraSeed,
                        initial: person.initialFor(localeCode),
                        diameter: 38,
                      ),
                title: person?.nameFor(localeCode),
                trailing: person == null
                    ? null
                    : UpIconButton(
                        icon: Icons.more_horiz_rounded,
                        semanticLabel: s.more,
                        onPressed: () =>
                            SafetySheet.show(context, person.id),
                      ),
              ),
              Expanded(
                child: match.messages.isEmpty
                    ? Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 240),
                          child: Text(
                            s.chatOpener,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          vertical: Insets.md,
                        ),
                        itemCount: match.messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _Bubble(message: match.messages[index]);
                        },
                      ),
              ),
              _Composer(
                controller: _input,
                hint: s.messageHint,
                onSend: _send,
                borderColor: p.line,
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final bool mine = message.isMine;

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md - 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        decoration: BoxDecoration(
          color: mine ? p.amber : p.surfaceHigh,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 18.0 : 6.0),
            bottomEnd: Radius.circular(mine ? 6.0 : 18.0),
          ),
        ),
        child: Text(
          message.body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: mine ? p.onAmber : p.foreground,
                fontSize: 14.5,
              ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.borderColor,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLength: Message.maxLength,
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: p.amber),
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Material(
            color: p.amber,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSend,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.send_rounded, size: 19, color: p.onAmber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
