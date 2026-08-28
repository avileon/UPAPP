import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
/// `dart:io`'s own client rather than the `http` package, for the same reason
/// the server has no dependencies: this is sixty lines of behaviour, and the
/// two things that could go wrong — sending a stale token, and hiding a network
/// failure behind a parse error — are both visible here in full.
class ApiClient {
  ApiClient(this.config);

  final BackendConfig config;

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  static const Duration _responseTimeout = Duration(seconds: 20);

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
      final Map<String, dynamic> result = await _once(
        method,
        path,
        body: body,
        authenticated: authenticated,
      );
      return result;
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
      final bool refreshed = await _refresh(refresh);
      if (!refreshed) {
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

  Future<Map<String, dynamic>> _once(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
  }) async {
    final Uri uri = Uri.parse('${config.baseUrl}$path');
    HttpClientResponse response;
    String text;
    try {
      final HttpClientRequest request = await _http.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final String? token = config.accessToken;
      if (authenticated && token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }
      response = await request.close().timeout(_responseTimeout);
      text = await response.transform(utf8.decoder).join();
    } on TimeoutException {
      throw const ApiException(0, 'timeout');
    } on SocketException {
      throw const ApiException(0, 'unreachable');
    } on HandshakeException {
      throw const ApiException(0, 'tls_failed');
    } on HttpException {
      throw const ApiException(0, 'unreachable');
    }

    Map<String, dynamic> decoded = const <String, dynamic>{};
    if (text.isNotEmpty) {
      try {
        final Object? value = jsonDecode(text);
        if (value is Map<String, dynamic>) {
          decoded = value;
        }
      } on FormatException {
        // A tunnel that has expired answers with an HTML error page. Say the
        // server is unreachable rather than reporting a JSON parse failure the
        // user cannot act on.
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

  /// Uploads raw bytes — a photo, and nothing else so far.
  ///
  /// The body is the image itself rather than JSON or a multipart form. There
  /// is one file, and base64 in an envelope would cost a third more bytes over
  /// a phone connection to say the same thing.
  Future<Map<String, dynamic>> postBytes(
    String path,
    Uint8List body,
    String contentType,
  ) async {
    if (!config.isConfigured) {
      throw const ApiException(0, 'no_server');
    }
    try {
      return await _sendBytes(path, body, contentType);
    } on ApiException catch (error) {
      final String? refresh = config.refreshToken;
      if (!error.isUnauthorized || refresh == null) {
        rethrow;
      }
      if (!await _refresh(refresh)) {
        rethrow;
      }
      return _sendBytes(path, body, contentType);
    }
  }

  Future<Map<String, dynamic>> _sendBytes(
    String path,
    Uint8List body,
    String contentType,
  ) async {
    final Uri uri = Uri.parse('${config.baseUrl}$path');
    try {
      final HttpClientRequest request = await _http.openUrl('POST', uri);
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      final String? token = config.accessToken;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.add(body);
      // A photo over a phone uplink is not a 20-second request.
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 90));
      final String text = await response.transform(utf8.decoder).join();
      final Object? decoded = text.isEmpty ? null : jsonDecode(text);
      final Map<String, dynamic> map =
          decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          map['error'] as String? ?? 'http_${response.statusCode}',
          map['message'] as String? ?? '',
        );
      }
      return map;
    } on TimeoutException {
      throw const ApiException(0, 'timeout');
    } on SocketException {
      throw const ApiException(0, 'unreachable');
    } on FormatException {
      throw const ApiException(0, 'bad_response');
    }
  }

  /// Downloads raw bytes. Returns null when the server has no such file.
  Future<Uint8List?> getBytes(String path) async {
    if (!config.isConfigured) {
      return null;
    }
    final Uri uri = Uri.parse('${config.baseUrl}$path');
    try {
      final HttpClientRequest request = await _http.openUrl('GET', uri);
      final String? token = config.accessToken;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        await response.drain<void>();
        // 401 is worth one refresh: a photo request can easily be the first
        // call after an access token quietly expired.
        final String? refresh = config.refreshToken;
        if (response.statusCode == 401 && refresh != null) {
          if (await _refresh(refresh)) {
            return getBytes(path);
          }
        }
        return null;
      }
      final List<int> bytes = <int>[];
      await for (final List<int> chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    }
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

  void dispose() => _http.close(force: true);
}
