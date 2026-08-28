import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'backend_config.dart';

/// A failure the server described. [code] is the machine-readable string the
/// server sends (`not_live`, `under_minimum_age`, …); the UI switches on that,
/// never on the message.
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.message = '']);

  final int status;
  final String code;
  final String message;

  bool get isUnauthorized => status == 401;
  bool get isRateLimited => status == 429;

  /// True when the phone could not reach the server at all — a dead tunnel, no
  /// signal, a laptop that went to sleep. Worth telling the user apart from a
  /// refusal, because the fix is completely different.
  bool get isOffline => status == 0;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// The whole HTTP surface, in one file.
///
/// `package:http` rather than `dart:io`'s own client, and that is what lets
/// this app run in a browser at all: `dart:io` does not exist on the web, so a
/// single import of it anywhere in the tree makes `flutter build web` fail.
/// The package is maintained by the Dart team and picks the right transport per
/// platform — sockets on a phone, `fetch` in a browser — behind one API.
///
/// The two things that could go wrong here are still visible in full: sending a
/// stale token, and hiding a network failure behind a parse error.
class ApiClient {
  ApiClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final BackendConfig config;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  /// A photo over a phone uplink is not a twenty-second request.
  static const Duration _mediaTimeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> get(String path) => send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      send('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, [Object? body]) =>
      send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => send('DELETE', path);

  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    if (!config.isConfigured) {
      throw const ApiException(0, 'no_server');
    }

    try {
      return await _once(
        method,
        path,
        body: body,
        authenticated: authenticated,
      );
    } on ApiException catch (error) {
      final String? refresh = config.refreshToken;
      // Exactly one refresh attempt, and only when there is something to
      // refresh with. A loop here would turn an expired session into a storm
      // of requests against a server that has already said no.
      if (!error.isUnauthorized ||
          !allowRefresh ||
          !authenticated ||
          refresh == null) {
        rethrow;
      }
      if (!await _refresh(refresh)) {
        rethrow;
      }
      return _once(method, path, body: body, authenticated: authenticated);
    }
  }

  Future<bool> _refresh(String refreshToken) async {
    try {
      final Map<String, dynamic> result = await _once(
        'POST',
        '/auth/refresh',
        body: <String, dynamic>{'refreshToken': refreshToken},
        authenticated: false,
      );
      await config.setTokens(
        accessToken: result['accessToken'] as String?,
        refreshToken: result['refreshToken'] as String?,
      );
      return true;
    } on ApiException {
      // The refresh token is single use and may already have been spent. Drop
      // it rather than keeping a credential that cannot work.
      await config.clearTokens();
      return false;
    }
  }

  Map<String, String> _headers({
    required bool authenticated,
    String? contentType,
  }) {
    final Map<String, String> headers = <String, String>{};
    if (contentType != null) {
      headers['content-type'] = contentType;
    }
    final String? token = config.accessToken;
    if (authenticated && token != null) {
      headers['authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _once(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
  }) async {
    final http.Request request =
        http.Request(method, Uri.parse('${config.baseUrl}$path'))
          ..headers.addAll(
            _headers(
              authenticated: authenticated,
              contentType: 'application/json',
            ),
          );
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _decode(await _perform(request, _timeout));
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded = const <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final Object? value = jsonDecode(response.body);
        if (value is Map<String, dynamic>) {
          decoded = value;
        }
      } on FormatException {
        // A tunnel that has expired answers with an HTML error page. Say the
        // response was bad rather than reporting a JSON parse failure the user
        // cannot act on.
        throw ApiException(response.statusCode, 'bad_response');
      }
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        decoded['error'] as String? ?? 'http_${response.statusCode}',
        decoded['message'] as String? ?? '',
      );
    }
    return decoded;
  }

  /// Sends a prepared request and turns transport failures into [ApiException].
  ///
  /// One place, so that "the server refused" and "the server was never reached"
  /// cannot be confused anywhere above this line.
  Future<http.Response> _perform(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(0, 'timeout');
    } on http.ClientException {
      throw const ApiException(0, 'unreachable');
    } on Exception {
      // `IOClient` wraps SocketException and HttpException as ClientException
      // but lets TLS failures through untouched — an expired tunnel
      // certificate, or `https://` typed at a plain-HTTP host. Those must not
      // escape past every `on ApiException` handler above this line, `ping()`
      // included. Nothing inside this method throws ApiException, so this
      // cannot swallow one.
      throw const ApiException(0, 'tls_failed');
    }
  }

  /// Uploads raw bytes — a photo, and nothing else so far.
  ///
  /// The body is the image itself rather than JSON or a multipart form. There
  /// is one file, and base64 in an envelope would cost a third more bytes over
  /// a phone connection to say the same thing.
  Future<Map<String, dynamic>> postBytes(
    String path,
    Uint8List body,
    String contentType, {
    bool allowRefresh = true,
  }) async {
    if (!config.isConfigured) {
      throw const ApiException(0, 'no_server');
    }
    try {
      final http.Request request =
          http.Request('POST', Uri.parse('${config.baseUrl}$path'))
            ..headers.addAll(
              _headers(authenticated: true, contentType: contentType),
            )
            ..bodyBytes = body;
      return _decode(await _perform(request, _mediaTimeout));
    } on ApiException catch (error) {
      final String? refresh = config.refreshToken;
      if (!error.isUnauthorized || !allowRefresh || refresh == null) {
        rethrow;
      }
      if (!await _refresh(refresh)) {
        rethrow;
      }
      return postBytes(path, body, contentType, allowRefresh: false);
    }
  }

  /// Downloads raw bytes.
  ///
  /// Null means the server answered and does not have this file. A transport
  /// failure — timeout, dead tunnel, no signal — throws instead, because the
  /// caller has to tell those apart: one is permanent and the other is worth
  /// trying again in a minute.
  Future<Uint8List?> getBytes(String path, {bool allowRefresh = true}) async {
    if (!config.isConfigured) {
      throw const ApiException(0, 'no_server');
    }
    final http.Request request =
        http.Request('GET', Uri.parse('${config.baseUrl}$path'))
          ..headers.addAll(_headers(authenticated: true));
    // The media timeout, not the API one: a photo coming down a phone uplink
    // is not a twenty-second request either.
    final http.Response response = await _perform(request, _mediaTimeout);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    // 401 is worth exactly one refresh: a photo request can easily be the first
    // call after an access token quietly expired. One, not a loop.
    final String? refresh = config.refreshToken;
    if (response.statusCode == 401 && allowRefresh && refresh != null) {
      if (await _refresh(refresh)) {
        return getBytes(path, allowRefresh: false);
      }
    }
    return null;
  }

  /// A cheap round trip for the settings screen. Never throws.
  Future<bool> ping() async {
    try {
      final Map<String, dynamic> result =
          await send('GET', '/health', authenticated: false);
      return result['ok'] == true;
    } on ApiException {
      return false;
    }
  }

  void dispose() => _http.close();
}
