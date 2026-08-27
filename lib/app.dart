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
      builder: (BuildContext context) {
        final SessionController session = context.session;
        return ListenableBuilder(
          listenable: session,
          builder: (BuildContext context, Widget? _) {
            return MaterialApp(
              title: 'UP',
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
      },
    );
  }
}
