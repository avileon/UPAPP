import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app points, and the tokens it points there with.
///
/// One object rather than a settings library: there are four values here, they
/// all change together, and every screen that cares listens to the same
/// [ChangeNotifier].
///
/// **On persistence.** `shared_preferences` because it is the one store that
/// exists on every platform this app runs on — Android's own preferences in the
/// app, `localStorage` in a browser. It is not a keystore, so treat what is
/// here as a convenience: losing it costs one sign-in and one paste of the
/// server address, never any data. When the app grows a real secure store, the
/// access and refresh tokens move there first and this keeps only the address.
class BackendConfig extends ChangeNotifier {
  BackendConfig({String baseUrl = '', String venueCode = ''})
      : _baseUrl = _normaliseBaseUrl(baseUrl),
        _venueCode = normaliseVenue(venueCode) ?? '';

  String _baseUrl;
  String _venueCode;
  String? _accessToken;
  String? _refreshToken;

  /// Empty means "no server configured" — the app runs on mock data.
  String get baseUrl => _baseUrl;
  String get venueCode => _venueCode;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isConfigured => _baseUrl.isNotEmpty;
  bool get isSignedIn => _accessToken != null;

  static const String _keyBaseUrl = 'up.baseUrl';
  static const String _keyVenue = 'up.venueCode';
  static const String _keyAccess = 'up.accessToken';
  static const String _keyRefresh = 'up.refreshToken';

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
    final String key = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (key.length < 3 || key.length > 12) {
      return null;
    }
    return key;
  }

  /// Loads what was stored, then lets the page's own URL override it.
  ///
  /// The override is what makes a link worth sharing. Opening
  /// `https://…/?venue=BAR12` puts you in that room without typing anything,
  /// and served from the same origin the app already knows its own address —
  /// so a person who scans a QR code at a table is signed in to the right
  /// server, in the right room, having typed nothing at all.
  Future<void> load({Uri? url}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _baseUrl = _normaliseBaseUrl(prefs.getString(_keyBaseUrl) ?? '');
      _venueCode = prefs.getString(_keyVenue) ?? '';
      _accessToken = prefs.getString(_keyAccess);
      _refreshToken = prefs.getString(_keyRefresh);
    } catch (_) {
      // A store that will not open is a first run, not an error.
    }
    await applyUrl(url ?? Uri.base);
    notifyListeners();
  }

  /// Reads `?venue=` and `?server=` out of a URL. Does nothing on a phone,
  /// where `Uri.base` is a file path.
  Future<void> applyUrl(Uri url) async {
    if (!url.hasScheme || (!url.isScheme('http') && !url.isScheme('https'))) {
      return;
    }
    // Served from the server itself, so the page's own origin is the address —
    // no pasting, and it cannot be pointed at the wrong place by a stale
    // setting.
    final String origin = _normaliseBaseUrl('${url.scheme}://${url.authority}');
    if (origin.isNotEmpty && origin != _baseUrl) {
      _baseUrl = origin;
      _accessToken = null;
      _refreshToken = null;
    }
    final String? venue = normaliseVenue(url.queryParameters['venue'] ?? '');
    if (venue != null) {
      _venueCode = venue;
    }
    await _persist();
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

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBaseUrl, _baseUrl);
      await prefs.setString(_keyVenue, _venueCode);
      await _write(prefs, _keyAccess, _accessToken);
      await _write(prefs, _keyRefresh, _refreshToken);
    } catch (_) {
      // Not being able to remember the address is survivable; failing to start
      // because of it is not.
    }
  }

  Future<void> _write(SharedPreferences prefs, String key, String? value) {
    return value == null ? prefs.remove(key) : prefs.setString(key, value);
  }
}
