import 'package:flutter/widgets.dart';

import '../data/api/api_auth_repository.dart';
import '../data/api/api_client.dart';
import '../data/api/api_interaction_repository.dart';
import '../data/api/api_presence_repository.dart';
import '../data/api/api_profile_repository.dart';
import '../data/api/backend_config.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_data.dart';
import '../data/mock/mock_interaction_repository.dart';
import '../data/mock/mock_presence_repository.dart';
import '../data/mock/mock_profile_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/interaction_repository.dart';
import '../domain/repositories/presence_repository.dart';
import '../domain/repositories/profile_repository.dart';
import 'interaction_controller.dart';
import 'live_controller.dart';
import 'people_directory.dart';
import 'photo_cache.dart';
import 'session_controller.dart';

/// Dependency injection.
///
/// One InheritedWidget holding the controllers. No third-party state library:
/// there is nothing here that `ChangeNotifier` plus `ListenableBuilder` does
/// not already do, and adding one now would only be a preference to defend
/// later.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.session,
    required this.live,
    required this.interactions,
    required this.people,
    required this.photos,
    required this.config,
    required super.child,
    super.key,
  });

  final SessionController session;
  final LiveController live;
  final InteractionController interactions;
  final PeopleDirectory people;
  final PhotoCache photos;
  final BackendConfig config;

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
      interactions != oldWidget.interactions ||
      people != oldWidget.people ||
      photos != oldWidget.photos ||
      config != oldWidget.config;
}

extension AppScopeAccess on BuildContext {
  SessionController get session => AppScope.of(this).session;
  LiveController get live => AppScope.of(this).live;
  InteractionController get interactions => AppScope.of(this).interactions;
  PeopleDirectory get people => AppScope.of(this).people;
  PhotoCache get photos => AppScope.of(this).photos;
  BackendConfig get backend => AppScope.of(this).config;
}

/// Builds one of two stacks and keeps it alive for the app's lifetime.
///
/// **This is the only file that knows both stacks exist.** With no server
/// address configured the app runs entirely on mock data, exactly as it did in
/// Milestone 1 — which is what makes the app installable and demoable on a
/// phone that cannot reach anything. Paste a server address into settings and
/// the same screens, driven by the same four interfaces, are talking to a real
/// backend.
class AppScopeHost extends StatefulWidget {
  const AppScopeHost({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<AppScopeHost> {
  final BackendConfig _config = BackendConfig();
  final PeopleDirectory _people = PeopleDirectory();

  /// Rebuilt with the stack: it holds other people's photographs, and those
  /// must not survive a change of server or a sign-out.
  PhotoCache _photoCache = PhotoCache();

  ApiClient? _client;
  late AuthRepository _auth;
  late ProfileRepository _profiles;
  late PresenceRepository _presence;
  late InteractionRepository _interactions;

  late SessionController _session;
  late LiveController _live;
  late InteractionController _interactionController;

  bool _usingApi = false;

  @override
  void initState() {
    super.initState();
    _buildStack();
    _config.addListener(_onConfigChanged);
    // The stored address and tokens arrive a frame or two later; the mock stack
    // is already up, so nothing is waiting on this.
    _config.load();
  }

  /// Rebuilds the stack when — and only when — the *server* changed.
  ///
  /// The venue code and the tokens live in the same object and change often;
  /// tearing down every controller because someone typed a venue code would
  /// sign them out mid-evening.
  void _onConfigChanged() {
    if (_config.isConfigured == _usingApi) {
      return;
    }
    final List<Object> retired = <Object>[
      _live,
      _interactionController,
      _session,
      if (_client != null) _client!,
    ];
    final PhotoCache retiredPhotos = _photoCache;
    setState(() {
      _people.clear();
      _buildStack();
    });
    retiredPhotos.dispose();
    // After the frame, so nothing still on screen is holding a controller that
    // has just been torn down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final Object old in retired) {
        if (old is LiveController) {
          old.dispose();
        } else if (old is InteractionController) {
          old.dispose();
        } else if (old is SessionController) {
          old.dispose();
        } else if (old is ApiClient) {
          old.dispose();
        }
      }
    });
  }

  void _buildStack() {
    _usingApi = _config.isConfigured;
    if (_usingApi) {
      _buildApiStack();
    } else {
      _buildMockStack();
    }
    _live = LiveController(presence: _presence);
    _interactionController =
        InteractionController(interactions: _interactions);
  }

  void _buildMockStack() {
    _client = null;
    // No fetcher: every key resolves to nothing and the aura placeholder
    // stands in, which is exactly what the mock stack is for.
    _photoCache = PhotoCache();
    _auth = MockAuthRepository();
    _profiles = MockProfileRepository();
    _presence = MockPresenceRepository();
    _session = SessionController(auth: _auth, profiles: _profiles);
    _interactions = MockInteractionRepository(
      localeCode: () => _session.localeCode,
    );
    // The mock people are known up front; the real ones arrive as the server
    // reveals them.
    _people.rememberAll(MockData.people);
  }

  void _buildApiStack() {
    final ApiClient client = ApiClient(_config);
    _client = client;
    _photoCache = PhotoCache(fetch: (String key) => client.getBytes('/media/$key'));
    _auth = ApiAuthRepository(
      client: client,
      acceptedTerms: () => _session.acceptedTerms,
    );
    _profiles = ApiProfileRepository(client: client);
    _presence = ApiPresenceRepository(
      client: client,
      venueCode: () => _config.venueCode,
      onPeople: _people.rememberAll,
    );
    final ApiInteractionRepository interactions = ApiInteractionRepository(
      client: client,
      onPeople: _people.rememberAll,
    );
    _interactions = interactions;
    _session = SessionController(
      auth: _auth,
      profiles: _profiles,
      onSignedIn: interactions.startPolling,
      onSignedOut: interactions.stopPolling,
    );
    // A stored refresh token means this phone was signed in last time.
    _session.restore();
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigChanged);
    _live.dispose();
    _interactionController.dispose();
    _session.dispose();
    _client?.dispose();
    _photoCache.dispose();
    _people.dispose();
    _config.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: _session,
      live: _live,
      interactions: _interactionController,
      people: _people,
      photos: _photoCache,
      config: _config,
      child: Builder(builder: widget.builder),
    );
  }
}
