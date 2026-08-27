import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/main_shell.dart';
import '../screens/match_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/phone_screen.dart';
import '../screens/photos_setup_screen.dart';
import '../screens/profile_preview_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/reality_check_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

abstract final class Routes {
  static const String splash = '/';
  static const String intro = '/intro';
  static const String phone = '/phone';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String photosSetup = '/photos-setup';
  static const String permissions = '/permissions';
  static const String main = '/main';
  static const String profilePreview = '/profile';
  static const String match = '/match';
  static const String chat = '/chat';
  static const String realityCheck = '/reality-check';
  static const String settings = '/settings';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case splash:
        page = const SplashScreen();
      case intro:
        page = const IntroScreen();
      case phone:
        page = const PhoneScreen();
      case otp:
        page = const OtpScreen();
      case profileSetup:
        page = const ProfileSetupScreen();
      case photosSetup:
        page = const PhotosSetupScreen();
      case permissions:
        page = const PermissionsScreen();
      case main:
        page = const MainShell();
      case profilePreview:
        page = ProfilePreviewScreen(personId: settings.arguments! as String);
      case match:
        page = MatchScreen(personId: settings.arguments! as String);
      case chat:
        page = ChatScreen(matchId: settings.arguments! as String);
      case realityCheck:
        page = RealityCheckScreen(matchId: settings.arguments! as String);
      case Routes.settings:
        page = const SettingsScreen();
      default:
        return null;
    }
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => page,
      settings: settings,
    );
  }
}
