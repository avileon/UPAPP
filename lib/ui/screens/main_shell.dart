import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/up_nav_bar.dart';
import '../components/up_scaffold.dart';
import 'tabs/chats_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/me_tab.dart';
import 'tabs/nearby_tab.dart';

/// The four-tab shell. Everything past a tab is pushed on the root navigator,
/// so a match or a chat can be opened from anywhere.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();

  /// Lets a child switch tabs — used by "see who's nearby" on Home.
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  UpTab _tab = UpTab.home;

  void select(UpTab tab) {
    if (_tab == tab) {
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: interactions,
      builder: (BuildContext context, Widget? _) {
        return UpScaffold(
          padded: false,
          bottomBar: UpNavBar(
            current: _tab,
            onSelect: select,
            unreadCount: interactions.unreadCount,
            labels: <UpTab, String>{
              UpTab.home: s.tabHome,
              UpTab.nearby: s.tabNearby,
              UpTab.chats: s.tabChats,
              UpTab.me: s.tabMe,
            },
          ),
          child: switch (_tab) {
            UpTab.home => const HomeTab(),
            UpTab.nearby => const NearbyTab(),
            UpTab.chats => const ChatsTab(),
            UpTab.me => const MeTab(),
          },
        );
      },
    );
  }
}
