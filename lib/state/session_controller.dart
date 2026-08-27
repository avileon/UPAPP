import 'package:flutter/material.dart';

import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_profile_repository.dart';
import '../domain/entities/live_session.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/profile_repository.dart';

/// Identity, profile and app-level preferences.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository auth,
    required ProfileRepository profiles,
  })  : _auth = auth,
        _profiles = profiles;

  final AuthRepository _auth;
  final ProfileRepository _profiles;

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

  String get localeCode => _locale.languageCode;
  bool get isSignedIn => _profile != null;

  /// A draft profile so the setup screens always have something to edit.
  UserProfile get draftProfile =>
      _profile ??
      const UserProfile(
        id: 'me',
        firstName: '',
        birthYear: 1994,
        gender: Gender.male,
        interestedIn: InterestedIn.women,
      );

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

  Future<void> requestOtp(String phoneNumber) async {
    _phoneNumber = phoneNumber.trim();
    _setBusy(true);
    try {
      await _auth.requestOtp(_phoneNumber);
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verifyOtp(String code) async {
    _setBusy(true);
    try {
      await _auth.verifyOtp(phoneNumber: _phoneNumber, code: code);
      _profile ??= draftProfile;
      notifyListeners();
      return true;
    } on FormatException {
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    _setBusy(true);
    try {
      _profile = await _profiles.save(profile);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> addPhoto() async {
    _profile = await _profiles.addPhoto();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    _profile = null;
    _acceptedTerms = false;
    _phoneNumber = '';
    notifyListeners();
  }

  Future<void> logOut() async {
    await _auth.logOut();
    _profile = null;
    notifyListeners();
  }

  void resetForDemo() {
    _profile = null;
    _acceptedTerms = false;
    _phoneNumber = '';
    _liveDuration = const Duration(minutes: 60);
    if (_profiles is MockProfileRepository) {
      (_profiles as MockProfileRepository).clear();
    }
    if (_auth is MockAuthRepository) {
      (_auth as MockAuthRepository).logOut();
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
