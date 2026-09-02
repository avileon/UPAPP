import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/match_thread.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/nearby_person.dart';
import '../../../state/app_scope.dart';
import '../../../state/interaction_controller.dart';
import '../../components/arrival_alerts.dart';
import '../../components/common.dart';
import '../../navigation/routes.dart';
import '../../components/up_photo.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final InteractionController interactions = context.interactions;
    final String localeCode = context.session.localeCode;

    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        final List<MatchThread> matches = interactions.matches;
        final int unread = interactions.unreadCount;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Row(
                children: <Widget>[
                  Text(s.chatsTitle,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: Insets.sm),
                  // The count next to the title, not only on the tab icon.
                  // Once you are on this screen the badge behind you is gone,
                  // and "3 waiting" is the thing that makes you scan the list
                  // rather than assume you have already seen it.
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.amber,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        '$unread',
                        style: TextStyle(
                          color: p.onAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Expanded(
                child: matches.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: s.noMatchesTitle,
                        body: s.noMatchesBody,
                      )
                    : ListView.separated(
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => Divider(
                          color: p.line,
                          height: 1,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          return _MatchRow(
                            match: matches[index],
                            localeCode: localeCode,
                            strings: s,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.localeCode,
    required this.strings,
  });

  final MatchThread match;
  final String localeCode;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final NearbyPerson? person = context.people.byId(match.personId);
    if (person == null) {
      return const SizedBox.shrink();
    }
    final UpPalette p = context.palette;
    final Message? last = match.lastMessage;
    final bool unread = match.isUnread;

    // An unread row is heavier in three ways at once — a dot, a bolder name,
    // a foreground-coloured preview — because any one of them alone is
    // something a person can scan straight past. The tinted background is the
    // fourth: it makes the row findable without reading it.
    return Material(
      color: unread ? p.amber.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: () {
          context.interactions.markRead(match.id);
          Navigator.of(context).pushNamed(Routes.chat, arguments: match.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Insets.md,
            horizontal: Insets.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  UpPhoto.circle(
                    photoKey: person.mainPhotoKey,
                    seed: person.auraSeed,
                    initial: person.initialFor(localeCode),
                    diameter: Sizes.avatarSm,
                  ),
                  if (unread)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: p.background,
                          shape: BoxShape.circle,
                        ),
                        child: UnreadDot(size: 11, color: p.amber),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            person.nameFor(localeCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Text(
                          shortRelativeTime(match.lastActivityAt, strings),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: unread ? p.amber : p.dim,
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        // Whose line it is. Without this the preview of your
                        // own last message reads exactly like a reply you
                        // have not answered.
                        if (last != null && last.isMine) ...<Widget>[
                          Icon(
                            Icons.subdirectory_arrow_left_rounded,
                            size: 13,
                            color: p.dim,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            last?.body ?? strings.chatOpener,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: unread ? p.foreground : p.muted,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
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
