import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/error_text.dart';

import '../data/api/api_auth_repository.dart';
import '../data/api/api_client.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_profile_repository.dart';
import '../domain/entities/live_session.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/profile_repository.dart';

/// A plausible default so the setup screens open on something rather than an
/// empty date.
final DateTime _defaultBirthDate = DateTime(1994, 5, 1);

/// Identity, profile and app-level preferences.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository auth,
    required ProfileRepository profiles,
    VoidCallback? onSignedIn,
    VoidCallback? onSignedOut,
  })  : _auth = auth,
        _profiles = profiles,
        _onSignedIn = onSignedIn,
        _onSignedOut = onSignedOut;

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final VoidCallback? _onSignedIn;
  final VoidCallback? _onSignedOut;

  Locale _locale = const Locale('he');
  ThemeMode _themeMode = ThemeMode.dark;
  bool _acceptedTerms = false;
  String _phoneNumber = '';
  bool _isBusy = false;
  UserProfile? _profile;
  Duration _liveDuration = const Duration(minutes: 60);
  bool _hideFromContacts = true;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get acceptedTerms => _acceptedTerms;
  String get phoneNumber => _phoneNumber;
  bool get isBusy => _isBusy;
  UserProfile? get profile => _profile;
  Duration get liveDuration => _liveDuration;
  bool get hideFromContacts => _hideFromContacts;

  /// The last thing that went wrong, as the server's error code. Cleared by the
  /// next attempt. The screens turn it into a sentence; nothing switches on the
  /// message text.
  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;

  /// While the server runs with `SMS_PROVIDER=mock` it hands the code straight
  /// back, so the OTP screen can show it instead of asking you to go and read a
  /// terminal. Null against any real provider.
  String? get devCode {
    final AuthRepository auth = _auth;
    return auth is ApiAuthRepository ? auth.devCode : null;
  }

  String get localeCode => _locale.languageCode;
  bool get isSignedIn => _profile != null;

  /// A draft profile so the setup screens always have something to edit.
  UserProfile get draftProfile =>
      _profile ??
      UserProfile(
        id: 'me',
        firstName: '',
        birthDate: _defaultBirthDate,
        gender: Gender.male,
        interestedIn: InterestedIn.women,
      );

  /// Turns [lastErrorCode] into something a person can act on.
  String errorMessage(AppStrings strings) => errorText(strings, _lastErrorCode);

  void setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    setLocale(
      _locale.languageCode == 'he' ? const Locale('en') : const Locale('he'),
    );
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  void setAcceptedTerms(bool value) {
    _acceptedTerms = value;
    notifyListeners();
  }

  void setHideFromContacts(bool value) {
    _hideFromContacts = value;
    notifyListeners();
  }

  void setLiveDuration(Duration duration) {
    _liveDuration = duration;
    notifyListeners();
  }

  /// Cycles through the three offered durations. Used by the settings row.
  void cycleLiveDuration() {
    final int index =
        LiveSession.selectableDurations.indexOf(_liveDuration);
    final int next = (index + 1) % LiveSession.selectableDurations.length;
    setLiveDuration(LiveSession.selectableDurations[next]);
  }

  /// Signs back in from a stored refresh token, if there is one.
  ///
  /// Failure here is ordinary — an expired token, a server that has moved — and
  /// lands on the intro screen rather than an error.
  Future<void> restore() async {
    try {
      final UserProfile? stored = await _profiles.load();
      if (stored == null) {
        return;
      }
      _profile = stored;
      _acceptedTerms = true;
      _onSignedIn?.call();
      notifyListeners();
    } on ApiException catch (_) {
      // Not signed in. That is a normal first run.
    }
  }

  Future<bool> requestOtp(String phoneNumber) async {
    _phoneNumber = phoneNumber.trim();
    _lastErrorCode = null;
    _setBusy(true);
    try {
      await _auth.requestOtp(_phoneNumber);
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verifyOtp(String code) async {
    _lastErrorCode = null;
    _setBusy(true);
    try {
      await _auth.verifyOtp(phoneNumber: _phoneNumber, code: code);
      // Against the server this returns the profile that already exists, so a
      // returning user skips setup. Against the mocks it is null and the draft
      // takes over — the same code path either way.
      _profile = (await _profiles.load()) ?? draftProfile;
      _onSignedIn?.call();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      return false;
    } on FormatException {
      _lastErrorCode = 'otp_incorrect';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Returns false when the server refused the profile — under 18, above all.
  Future<bool> saveProfile(UserProfile profile) async {
    _lastErrorCode = null;
    _setBusy(true);
    try {
      _profile = await _profiles.save(profile);
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Uploads one photo and returns its key, or null if the upload failed.
  ///
  /// The key comes back so the caller can show the picture immediately from
  /// the bytes it already has, instead of waiting for a round trip to fetch
  /// back the image the person just chose.
  Future<String?> addPhoto(Uint8List bytes) async {
    _lastErrorCode = null;
    final List<String> before = _profile?.photoKeys ?? const <String>[];
    try {
      _profile = await _profiles.addPhoto(bytes);
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      notifyListeners();
      return null;
    }
    notifyListeners();
    final List<String> after = _profile?.photoKeys ?? const <String>[];
    for (final String key in after) {
      if (!before.contains(key)) {
        return key;
      }
    }
    return null;
  }

  Future<void> removePhoto(String key) async {
    _lastErrorCode = null;
    try {
      _profile = await _profiles.removePhoto(key);
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
    }
    notifyListeners();
  }

  Future<Uint8List?> photoBytes(String key) => _profiles.photoBytes(key);

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    _onSignedOut?.call();
    _profile = null;
    _acceptedTerms = false;
    _phoneNumber = '';
    notifyListeners();
  }

  Future<void> logOut() async {
    await _auth.logOut();
    _onSignedOut?.call();
    _profile = null;
    notifyListeners();
  }

  /// The credentials are gone and the server will not take this device back.
  ///
  /// Not a user action: the tokens were dropped underneath the app — a refresh
  /// the server refused, a session revoked. Without this the app keeps the
  /// profile it loaded at boot, still believes it is signed in, and answers
  /// every tap with "something went wrong" forever, because nothing that needs
  /// the server can ever succeed again. Showing the sign-in screen is the only
  /// honest state, and it is one SMS away from being fixed.
  void sessionLost() {
    if (_profile == null) {
      return;
    }
    _onSignedOut?.call();
    _profile = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  void resetForDemo() {
    _profile = null;
    _acceptedTerms = false;
    _phoneNumber = '';
    _liveDuration = const Duration(minutes: 60);
    if (_profiles is MockProfileRepository) {
      _profiles.clear();
    }
    if (_auth is MockAuthRepository) {
      _auth.logOut();
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
