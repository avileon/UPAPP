import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../domain/entities/match_thread.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../components/up_nav_bar.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';
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

  /// A conversation named by the URL, from a tapped notification.
  ///
  /// The worker opens `/?chat=<id>` when no tab is already open. The thread is
  /// usually not loaded yet at that moment — the app has to sign in and poll
  /// first — so this waits for it to appear rather than giving up on the first
  /// frame, and gives up for good after a few seconds so a stale link cannot
  /// hijack a later session.
  String? _pendingChat;
  Timer? _pendingTimer;

  /// A venue sticker's link (`/?venue=CODE`) opens the app; once signed in,
  /// this is where it lands: the join screen for that place. The code is
  /// cleared first so a cancelled join does not come back on every launch.
  Future<void> _openPendingVenue() async {
    if (!mounted) {
      return;
    }
    final String code = context.backend.venueCode;
    if (code.isEmpty) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    await context.backend.setVenueCode('');
    await navigator.pushNamed(Routes.venueJoin, arguments: code);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingVenue());
    final String? requested = Uri.base.queryParameters['chat'];
    if (requested == null || requested.isEmpty) {
      return;
    }
    _pendingChat = requested;
    _pendingTimer = Timer(const Duration(seconds: 20), () {
      _pendingChat = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingChat());
  }

  void _openPendingChat() {
    final String? matchId = _pendingChat;
    if (matchId == null || !mounted) {
      return;
    }
    final InteractionController interactions = context.interactions;
    final MatchThread? match = interactions.matchById(matchId);
    if (match == null) {
      return;
    }
    _pendingChat = null;
    _pendingTimer?.cancel();
    interactions.markRead(matchId);
    Navigator.of(context).pushNamed(Routes.chat, arguments: matchId);
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

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
        if (_pendingChat != null) {
          // Every rebuild is a fresh chance that the poll has now delivered
          // the thread the notification pointed at.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _openPendingChat());
        }
        // Back on the root screen used to close the app without a word. Now:
        // back on another tab goes home first, and back on home asks.
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop) {
              _onBack();
            }
          },
          child: UpScaffold(
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
        ),
        );
      },
    );
  }

  bool _asking = false;

  Future<void> _onBack() async {
    if (_tab != UpTab.home) {
      select(UpTab.home);
      return;
    }
    if (_asking) {
      return;
    }
    _asking = true;
    final AppStrings s = context.strings;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(s.exitTitle),
        content: Text(s.exitBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.exitStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.exitLeave),
          ),
        ],
      ),
    );
    _asking = false;
    if (leave ?? false) {
      // Android closes the app; on the web this leaves the page.
      await SystemNavigator.pop();
    }
  }
}
