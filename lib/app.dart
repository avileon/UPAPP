import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'state/app_scope.dart';
import 'state/session_controller.dart';
import 'ui/navigation/routes.dart';

class UpApp extends StatelessWidget {
  const UpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScopeHost(
      builder: (BuildContext context) => const _UpMaterialApp(),
    );
  }
}

/// The app itself, plus the one thing that has to happen outside any screen.
///
/// A session can end without anybody pressing anything: the server refuses a
/// refresh, the credentials are dropped, and from that moment every request
/// fails. No screen can fix that, and every screen answering "something went
/// wrong" is the worst of both worlds — the app looks broken and the one action
/// that would repair it, signing in again, is not reachable. So the transition
/// from signed-in to signed-out is watched here, above the navigator, and takes
/// the person back to the start.
class _UpMaterialApp extends StatefulWidget {
  const _UpMaterialApp();

  @override
  State<_UpMaterialApp> createState() => _UpMaterialAppState();
}

class _UpMaterialAppState extends State<_UpMaterialApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  SessionController? _session;
  bool _wasSignedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SessionController session = context.session;
    if (identical(session, _session)) {
      return;
    }
    _session?.removeListener(_onSession);
    _session = session..addListener(_onSession);
    _wasSignedIn = session.isSignedIn;
  }

  void _onSession() {
    final SessionController session = _session!;
    final bool signedIn = session.isSignedIn;
    if (_wasSignedIn && !signedIn) {
      // After the frame: this fires from a notification that may itself be
      // happening during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The splash rather than the sign-in screen: it is the one place that
        // decides where a person belongs, and it is where the explicit sign-out
        // in settings goes too. Two ways of leaving a session should not land
        // in two different places.
        _navigator.currentState?.pushNamedAndRemoveUntil(
          Routes.splash,
          (Route<dynamic> route) => false,
        );
      });
    }
    _wasSignedIn = signedIn;
  }

  @override
  void dispose() {
    _session?.removeListener(_onSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.session;
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        return MaterialApp(
          title: 'UP',
          navigatorKey: _navigator,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: session.themeMode,
          locale: session.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: Routes.splash,
          onGenerateRoute: Routes.onGenerateRoute,
        );
      },
    );
  }
}
