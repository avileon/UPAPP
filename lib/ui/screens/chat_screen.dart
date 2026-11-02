import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/match_thread.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/nearby_person.dart';
import '../../state/app_scope.dart';
import '../../domain/entities/live_intent.dart';
import '../../state/interaction_controller.dart';
import '../components/intent_picker.dart';
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

  /// A chat in UP is two minutes long, counted from the first message. The
  /// server enforces it; this only keeps the countdown on screen moving.
  static const Duration chatWindow = Duration(minutes: 2);
  Timer? _ticker;

  /// The server said the time is up even if this phone's clock disagrees.
  bool _serverSaysTimeUp = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

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
    _ticker?.cancel();
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
    final InteractionController interactions = context.interactions;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;
    await interactions.sendMessage(widget.matchId, text);
    if (interactions.lastErrorCode == 'chat_time_up') {
      messenger.showSnackBar(SnackBar(content: Text(s.chatTimeUpBody)));
      if (mounted) {
        setState(() => _serverSaysTimeUp = true);
      }
      return;
    }
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

        final DateTime? firstAt =
            match.messages.isEmpty ? null : match.messages.first.sentAt;
        final Duration? left = firstAt == null
            ? null
            : firstAt.add(chatWindow).difference(DateTime.now());
        final bool timeUp = (left != null && left <= Duration.zero) ||
            _serverSaysTimeUp;

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
              _ChatClock(
                left: timeUp ? Duration.zero : left,
                window: chatWindow,
              ),
              Expanded(
                child: match.messages.isEmpty
                    ? _Openers(
                        strings: s,
                        intent: context.live.intent,
                        onPick: (String line) {
                          _input.text = line;
                          // Placed in the box, not sent. The whole value of an
                          // opener is that it survives being edited — a button
                          // that fires a canned line at a stranger is a worse
                          // first message than a blank field, not a better one.
                          _input.selection = TextSelection.collapsed(
                            offset: line.length,
                          );
                          setState(() {});
                        },
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
              if (timeUp)
                const _MeetNow()
              else
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
            topStart: const Radius.circular(20),
            topEnd: const Radius.circular(20),
            bottomStart: Radius.circular(mine ? 20.0 : 6.0),
            bottomEnd: Radius.circular(mine ? 6.0 : 20.0),
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


/// Three ways to say the first thing.
///
/// The blank field after a match is where most of them die: both people can
/// see that the other is right there, and neither wants to be the one who
/// wrote something forgettable. These are deliberately ordinary lines, and
/// they land in the input box rather than being sent — the point is to get
/// past the empty screen, not to outsource the message.
class _Openers extends StatelessWidget {
  const _Openers({
    required this.strings,
    required this.intent,
    required this.onPick,
  });

  final AppStrings strings;
  final LiveIntent intent;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                strings.chatOpener,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              strings.openersTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: p.dim, letterSpacing: 0.4),
            ),
            const SizedBox(height: Insets.sm),
            for (final String line in intent.openers(strings))
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Material(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onTap: () => onPick(line),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.lg,
                          vertical: Insets.md,
                        ),
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// The two-minute countdown under the top bar.
class _ChatClock extends StatelessWidget {
  const _ChatClock({required this.left, required this.window});

  /// Null before the first message; zero once the time is up.
  final Duration? left;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final Duration? remaining = left;
    if (remaining == null) {
      return Padding(
        padding: const EdgeInsets.only(top: Insets.sm),
        child: Text(
          s.chatTimerIdle,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: p.muted),
        ),
      );
    }
    if (remaining <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final int secs = remaining.inSeconds + 1;
    final String clock =
        '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final bool urgent = secs <= 30;
    final Color colour = urgent ? p.amber : p.cyan;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 16, color: colour),
              const SizedBox(width: Insets.xs),
              Text(
                s.chatTimeLeft(clock),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: (remaining.inMilliseconds / window.inMilliseconds)
                  .clamp(0.0, 1.0),
              minHeight: 3,
              color: colour,
              backgroundColor: p.line,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the composer was, once the two minutes are over.
class _MeetNow extends StatelessWidget {
  const _MeetNow();

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: p.cyan, width: 1.6),
          color: p.cyan.withValues(alpha: 0.10),
          boxShadow: <BoxShadow>[
            BoxShadow(color: p.cyan.withValues(alpha: 0.30), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.waving_hand_rounded, color: p.cyan, size: 30),
            const SizedBox(height: Insets.sm),
            Text(
              s.chatTimeUpTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: p.cyan, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              s.chatTimeUpBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
