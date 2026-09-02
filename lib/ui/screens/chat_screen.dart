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
import '../components/common.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';
import 'safety_sheet.dart';
import '../components/up_photo.dart';

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

  /// The id of the last message this screen has scrolled to, so a rebuild for
  /// any other reason — a keyboard, a theme change, a poll that changed
  /// nothing — does not yank the view back down.
  String? _scrolledTo;

  /// How many messages were already there when the thread was opened.
  ///
  /// Fixed at open time: the divider has to stay put while you read past it.
  /// Recomputing it would make it slide down to the bottom and mark nothing.
  int? _unreadFrom;

  InteractionController? _interactions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final InteractionController interactions = context.interactions;
    if (identical(interactions, _interactions)) {
      return;
    }
    _interactions?.closeThread(widget.matchId);
    _interactions = interactions;
    final MatchThread? match = interactions.matchById(widget.matchId);
    if (_unreadFrom == null && match != null && match.isUnread) {
      final int firstUnread = _firstUnreadIndex(match.messages);
      // Only worth a divider when there is something above it to separate it
      // from. A line at the very top of a conversation says nothing.
      _unreadFrom = firstUnread > 0 ? firstUnread : null;
    }
    // Telling the controller which thread is open is what stops a message
    // arriving here from raising a banner over itself, and what keeps the tab
    // badge from counting something you are looking straight at.
    //
    // After the frame: this runs inside the build phase, and marking a thread
    // read notifies listeners — one of which is the builder currently on the
    // stack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        interactions.openThread(widget.matchId);
      }
    });
  }

  /// Walks back over the messages you sent to find where their run begins.
  int _firstUnreadIndex(List<Message> messages) {
    int index = messages.length;
    while (index > 0 && !messages[index - 1].isMine) {
      index--;
    }
    return index;
  }

  @override
  void dispose() {
    _interactions?.closeThread(widget.matchId);
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
    _scrollToEnd(force: true);
  }

  /// Follows the conversation without hijacking it.
  ///
  /// Called on every build before this, which meant that scrolling up to read
  /// something older was undone by the next five-second poll. Now it moves
  /// only when there is genuinely a new last message, and even then only if
  /// you were already at the bottom — reading history is a deliberate act and
  /// the app has no business interrupting it. Your own message always wins:
  /// pressing send is a request to see it.
  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      final ScrollPosition position = _scroll.position;
      final bool atBottom =
          position.maxScrollExtent - position.pixels < 120;
      if (!force && !atBottom) {
        return;
      }
      _scroll.animateTo(
        position.maxScrollExtent,
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

        final String? newest = match.lastMessage?.id;
        if (newest != null && newest != _scrolledTo) {
          final bool mine = match.lastMessage!.isMine;
          _scrolledTo = newest;
          _scrollToEnd(force: mine);
        }

        return UpScaffold(
          child: Column(
            children: <Widget>[
              UpTopBar(
                onBack: () => Navigator.of(context).pop(),
                leading: person == null
                    ? null
                    : UpPhoto.circle(
                        photoKey: person.mainPhotoKey,
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (index == _unreadFrom)
                                _UnreadMarker(label: s.unreadDivider),
                              _Bubble(message: match.messages[index]),
                            ],
                          );
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

/// The line that says "you had not read past here".
///
/// Coming back to a conversation with eleven messages in it, the question is
/// never "what is the newest one" — it is "where do I start reading". Without
/// this the answer is a guess, and the usual guess is to give up and scroll to
/// the bottom, which is how a message goes permanently unread while the app
/// insists everything was seen.
class _UnreadMarker extends StatelessWidget {
  const _UnreadMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md, top: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: p.amber.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Text(
              label,
              style: TextStyle(
                color: p.amber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.amber.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
