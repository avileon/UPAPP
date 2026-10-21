import 'package:flutter/material.dart';

import '../screens/blocked_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/main_shell.dart';
import '../screens/match_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/people_viewer_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/phone_screen.dart';
import '../screens/photos_setup_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/qr_scan_screen.dart';
import '../screens/reality_check_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/venue_join_screen.dart';
import '../screens/venue_screen.dart';
import '../screens/verify_screen.dart';

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
  static const String venue = '/venue';
  static const String verify = '/verify';
  static const String people = '/people';
  static const String scan = '/scan';
  static const String venueJoin = '/venue-join';
  static const String blocked = '/blocked';

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
        // One person, in the same full-screen viewer as the room.
        page = PeopleViewerScreen(
          args: PeopleViewerArgs(ids: <String>[settings.arguments! as String]),
        );
      case people:
        page = PeopleViewerScreen(args: settings.arguments! as PeopleViewerArgs);
      case scan:
        page = const QrScanScreen();
      case venueJoin:
        page = VenueJoinScreen(code: settings.arguments! as String);
      case blocked:
        page = const BlockedScreen();
      case match:
        page = MatchScreen(personId: settings.arguments! as String);
      case chat:
        page = ChatScreen(matchId: settings.arguments! as String);
      case realityCheck:
        page = RealityCheckScreen(matchId: settings.arguments! as String);
      case Routes.settings:
        page = const SettingsScreen();
      case venue:
        page = const VenueScreen();
      case verify:
        page = const VerifyScreen();
      default:
        return null;
    }
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => page,
      settings: settings,
    );
  }
}
