import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Where the app points, and the tokens it points there with.
///
/// One object rather than a settings library: there are four values here, they
/// all change together, and every screen that cares listens to the same
/// [ChangeNotifier].
///
/// **On persistence.** This writes a small JSON file into the app's own
/// temporary directory — the one place `dart:io` can reach on Android without
/// a plugin. That directory is private to the app but the OS may clear it, so
/// treat what is stored here as a convenience: losing it costs one sign-in and
/// one paste of the server address, never any data. When the app grows a real
/// keystore, the access and refresh tokens move there first and this file keeps
/// only the address.
class BackendConfig extends ChangeNotifier {
  BackendConfig({
    String baseUrl = '',
    String venueCode = '',
    Directory? storageDirectory,
  })  : _baseUrl = _normaliseBaseUrl(baseUrl),
        _venueCode = normaliseVenue(venueCode) ?? '',
        _storageDirectory = storageDirectory;

  /// Where the settings file lives. Injectable so tests get a directory of
  /// their own — sharing the process-wide temp directory means one test's
  /// saved server address is another test's surprise.
  final Directory? _storageDirectory;

  String _baseUrl;
  String _venueCode;
  String? _accessToken;
  String? _refreshToken;
  File? _file;

  /// Empty means "no server configured" — the app runs on mock data.
  String get baseUrl => _baseUrl;
  String get venueCode => _venueCode;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isConfigured => _baseUrl.isNotEmpty;
  bool get isSignedIn => _accessToken != null;

  static const String _fileName = 'up_backend.json';

  /// Strips what people actually paste: trailing slashes, stray spaces, and a
  /// missing scheme. A tunnel URL copied out of a terminal usually arrives with
  /// at least one of the three.
  static String _normaliseBaseUrl(String raw) {
    String value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// The same rule the server applies, so the app can show the key it will
  /// actually join rather than the characters that were typed. Kept in sync by
  /// hand with `normaliseVenue` in `server/src/domain/presence.js` — there is
  /// one test on each side and they assert the same examples.
  static String? normaliseVenue(String raw) {
    final String key =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (key.length < 3 || key.length > 12) {
      return null;
    }
    return key;
  }

  Future<void> load() async {
    try {
      final File file = await _resolveFile();
      if (!file.existsSync()) {
        return;
      }
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _baseUrl = _normaliseBaseUrl(decoded['baseUrl'] as String? ?? '');
      _venueCode = decoded['venueCode'] as String? ?? '';
      _accessToken = decoded['accessToken'] as String?;
      _refreshToken = decoded['refreshToken'] as String?;
      notifyListeners();
    } catch (_) {
      // A missing or corrupt settings file is a first run, not an error.
    }
  }

  Future<void> setServer({required String baseUrl}) async {
    final String next = _normaliseBaseUrl(baseUrl);
    if (next == _baseUrl) {
      return;
    }
    _baseUrl = next;
    // Tokens belong to one server. Keeping them across a change of address
    // would send the previous server's credentials to a new one.
    _accessToken = null;
    _refreshToken = null;
    await _persist();
    notifyListeners();
  }

  Future<void> setVenueCode(String raw) async {
    final String next = normaliseVenue(raw) ?? '';
    if (next == _venueCode) {
      return;
    }
    _venueCode = next;
    await _persist();
    notifyListeners();
  }

  Future<void> setTokens({String? accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _persist();
    notifyListeners();
  }

  Future<void> clearTokens() => setTokens();

  Future<File> _resolveFile() async {
    final File? cached = _file;
    if (cached != null) {
      return cached;
    }
    final Directory directory = _storageDirectory ?? Directory.systemTemp;
    final File file = File('${directory.path}/$_fileName');
    _file = file;
    return file;
  }

  Future<void> _persist() async {
    try {
      final File file = await _resolveFile();
      await file.writeAsString(jsonEncode(<String, dynamic>{
        'baseUrl': _baseUrl,
        'venueCode': _venueCode,
        'accessToken': _accessToken,
        'refreshToken': _refreshToken,
      }));
    } catch (_) {
      // Not being able to remember the address is survivable; failing to start
      // because of it is not.
    }
  }
}
