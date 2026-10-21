import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../../state/blocks_controller.dart';
import '../components/common.dart';
import '../components/up_photo.dart';
import '../components/up_scaffold.dart';

/// Everyone this person blocked, and a way to let one of them back.
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    final BlocksController? blocks = context.blocks;
    if (blocks != null) {
      Future<void>.delayed(Duration.zero, blocks.load);
    }
  }

  Future<void> _unblock(BlocksController blocks, BlockedPerson person) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppStrings s = context.strings;
    final bool ok = await blocks.unblock(person.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? s.unblockedDone(person.firstName) : errorText(s, blocks.lastErrorCode),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final BlocksController? blocks = context.blocks;

    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UpTopBar(
            title: s.blockedTitle,
            onBack: () => Navigator.of(context).pop(),
          ),
          Text(s.blockedBody, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Insets.lg),
          Expanded(
            child: blocks == null
                ? EmptyState(
                    icon: Icons.block_rounded,
                    title: s.blockedEmpty,
                    body: '',
                  )
                : ListenableBuilder(
                    listenable: blocks,
                    builder: (BuildContext context, Widget? _) {
                      if (blocks.loading && blocks.people.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (blocks.people.isEmpty) {
                        return EmptyState(
                          icon: Icons.block_rounded,
                          title: s.blockedEmpty,
                          body: '',
                        );
                      }
                      return ListView.separated(
                        itemCount: blocks.people.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: Insets.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final BlockedPerson person = blocks.people[i];
                          return _Row(
                            person: person,
                            label: s.unblock,
                            onUnblock: () => _unblock(blocks, person),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.person,
    required this.label,
    required this.onUnblock,
  });

  final BlockedPerson person;
  final String label;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    final String name = person.firstName.isEmpty ? '?' : person.firstName;
    return UpCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          UpPhoto.circle(
            photoKey: person.photoKey,
            seed: person.id.hashCode.abs() % 360,
            initial: name.substring(0, 1),
            diameter: 44,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleMedium),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.cyan,
              side: BorderSide(color: p.cyan),
            ),
            onPressed: onUnblock,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
