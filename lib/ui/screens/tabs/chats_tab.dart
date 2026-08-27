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
import '../../components/aura_photo.dart';
import '../../components/common.dart';
import '../../components/up_chip.dart';
import '../../navigation/routes.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;
    final String localeCode = context.session.localeCode;

    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        final List<MatchThread> matches = interactions.matches;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Text(s.chatsTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
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
                          color: context.palette.line,
                          height: 1,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          return _MatchRow(
                            match: matches[index],
                            localeCode: localeCode,
                            fallbackLine: s.chatOpener,
                            newTag: s.newTag,
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
    required this.fallbackLine,
    required this.newTag,
  });

  final MatchThread match;
  final String localeCode;
  final String fallbackLine;
  final String newTag;

  @override
  Widget build(BuildContext context) {
    final NearbyPerson? person = context.people.byId(match.personId);
    if (person == null) {
      return const SizedBox.shrink();
    }
    final Message? last = match.lastMessage;

    return InkWell(
      onTap: () {
        context.interactions.markRead(match.id);
        Navigator.of(context)
            .pushNamed(Routes.chat, arguments: match.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: <Widget>[
            AuraPhoto.circle(
              seed: person.auraSeed,
              initial: person.initialFor(localeCode),
              diameter: Sizes.avatarSm,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    person.nameFor(localeCode),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    last?.body ?? fallbackLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (match.isUnread) ...<Widget>[
              const SizedBox(width: Insets.sm),
              UpTag(label: newTag, emphasized: true),
            ],
          ],
        ),
      ),
    );
  }
}
