import 'package:flutter/widgets.dart';

import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_interaction_repository.dart';
import '../data/mock/mock_presence_repository.dart';
import '../data/mock/mock_profile_repository.dart';
import 'interaction_controller.dart';
import 'live_controller.dart';
import 'session_controller.dart';

/// Dependency injection for Milestone 1.
///
/// One InheritedWidget holding three controllers. No third-party state library:
/// there is nothing here that `ChangeNotifier` plus `ListenableBuilder` does
/// not already do, and adding one now would only be a preference to defend
/// later. Swapping in Riverpod is a change to this file and to the two
/// extension getters below.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.session,
    required this.live,
    required this.interactions,
    required super.child,
    super.key,
  });

  final SessionController session;
  final LiveController live;
  final InteractionController interactions;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      session != oldWidget.session ||
      live != oldWidget.live ||
      interactions != oldWidget.interactions;
}

extension AppScopeAccess on BuildContext {
  SessionController get session => AppScope.of(this).session;
  LiveController get live => AppScope.of(this).live;
  InteractionController get interactions => AppScope.of(this).interactions;
}

/// Builds the mock stack and keeps it alive for the app's lifetime.
class AppScopeHost extends StatefulWidget {
  const AppScopeHost({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<AppScopeHost> {
  late final MockAuthRepository _auth;
  late final MockProfileRepository _profiles;
  late final MockPresenceRepository _presence;
  late final MockInteractionRepository _interactions;

  late final SessionController _session;
  late final LiveController _live;
  late final InteractionController _interactionController;

  @override
  void initState() {
    super.initState();
    _auth = MockAuthRepository();
    _profiles = MockProfileRepository();
    _presence = MockPresenceRepository();
    _session = SessionController(auth: _auth, profiles: _profiles);
    _interactions = MockInteractionRepository(
      localeCode: () => _session.localeCode,
    );
    _live = LiveController(presence: _presence);
    _interactionController =
        InteractionController(interactions: _interactions);
  }

  @override
  void dispose() {
    _live.dispose();
    _interactionController.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: _session,
      live: _live,
      interactions: _interactionController,
      child: Builder(builder: widget.builder),
    );
  }
}
