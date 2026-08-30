import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up/data/api/api_client.dart';
import 'package:up/data/api/backend_config.dart';

/// Refreshing an expired session, when several requests notice at once.
///
/// A refresh token is single use, and the app has several requests in flight at
/// any moment — the Live poll fires every five seconds. So the interesting case
/// is not "one request got a 401", it is "four did, simultaneously". Three of
/// them must not spend a token the fourth already spent, and none of them may
/// throw away the credentials the winner just stored.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<BackendConfig> configured() async {
    final BackendConfig config = BackendConfig(baseUrl: 'https://up.test');
    await config.setTokens(
      accessToken: 'old-access',
      refreshToken: 'refresh-1',
    );
    return config;
  }

  test('several requests hitting 401 together cause one refresh', () async {
    int refreshes = 0;
    int served = 0;

    final MockClient stub = MockClient((http.Request request) async {
      if (request.url.path == '/auth/refresh') {
        refreshes++;
        // The real server is slow enough for the other requests to arrive.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode(<String, String>{
            'accessToken': 'new-access',
            'refreshToken': 'refresh-2',
          }),
          200,
        );
      }
      if (request.headers['authorization'] == 'Bearer new-access') {
        served++;
        return http.Response(jsonEncode(<String, bool>{'ok': true}), 200);
      }
      return http.Response(jsonEncode(<String, String>{'error': 'unauthorized'}), 401);
    });

    final BackendConfig config = await configured();
    final ApiClient client = ApiClient(config, httpClient: stub);

    await Future.wait(<Future<Map<String, dynamic>>>[
      client.get('/a'),
      client.get('/b'),
      client.get('/c'),
      client.get('/d'),
    ]);

    expect(refreshes, 1, reason: 'the refresh token is single use');
    expect(served, 4, reason: 'every caller retried with the new token');
    expect(config.accessToken, 'new-access');
    expect(config.refreshToken, 'refresh-2');
  });

  test('a 401 that arrives after someone else refreshed just retries', () async {
    // This request was sent while the old token was still current and its
    // refusal came back after the refresh had already landed. Spending another
    // single-use token to rediscover that is what signs the phone out on the
    // request after it.
    int refreshes = 0;
    int served = 0;

    final MockClient stub = MockClient((http.Request request) async {
      if (request.url.path == '/auth/refresh') {
        refreshes++;
        return http.Response(
          jsonEncode(<String, String>{
            'accessToken': 'new-access',
            'refreshToken': 'refresh-2',
          }),
          200,
        );
      }
      if (request.headers['authorization'] == 'Bearer new-access') {
        served++;
        return http.Response(jsonEncode(<String, bool>{'ok': true}), 200);
      }
      // The slow one is refused long after the fast one has been sorted out.
      if (request.url.path == '/slow') {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      return http.Response(jsonEncode(<String, String>{'error': 'unauthorized'}), 401);
    });

    final BackendConfig config = await configured();
    final ApiClient client = ApiClient(config, httpClient: stub);

    await Future.wait(<Future<Map<String, dynamic>>>[
      client.get('/fast'),
      client.get('/slow'),
    ]);

    expect(refreshes, 1, reason: 'the second caller had nothing left to fix');
    expect(served, 2);
    expect(config.refreshToken, 'refresh-2');
  });

  test('a refresh the server rejects clears the session exactly once', () async {
    final MockClient stub = MockClient((http.Request request) async {
      if (request.url.path == '/auth/refresh') {
        return http.Response(
          jsonEncode(<String, String>{'error': 'refresh_invalid'}),
          401,
        );
      }
      return http.Response(jsonEncode(<String, String>{'error': 'unauthorized'}), 401);
    });

    final BackendConfig config = await configured();
    final ApiClient client = ApiClient(config, httpClient: stub);

    await expectLater(client.get('/a'), throwsA(isA<ApiException>()));

    expect(config.accessToken, isNull);
    expect(config.refreshToken, isNull);
    expect(config.isSignedIn, isFalse);
  });
}
