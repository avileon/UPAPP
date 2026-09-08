import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up/data/api/api_client.dart';
import 'package:up/data/api/backend_config.dart';
import 'package:up/state/verification_controller.dart';

/// Photo verification, from the phone's side.
///
/// The order is the security property and it is easy to lose in a refactor:
/// the pose is asked for first and the camera opens second. Reversed, somebody
/// could take the photo and read the instruction afterwards, which is the one
/// thing the pose exists to prevent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<BackendConfig> configured() async {
    final BackendConfig config = BackendConfig(baseUrl: 'https://up.test');
    await config.setTokens(accessToken: 'access', refreshToken: 'refresh');
    return config;
  }

  Future<VerificationController> controllerWith(
    Future<http.Response> Function(http.Request request) handle,
  ) async {
    final BackendConfig config = await configured();
    final ApiClient client =
        ApiClient(config, httpClient: MockClient(handle));
    final VerificationController controller =
        VerificationController(client: client);
    addTearDown(controller.dispose);
    return controller;
  }

  http.Response json(Map<String, Object?> body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: <String, String>{
        'content-type': 'application/json',
      });

  test('nothing is uploaded before a pose has been asked for', () async {
    // The camera button does not exist until there is a challenge, and even
    // called directly this refuses.
    bool uploaded = false;
    final VerificationController controller = await controllerWith(
      (http.Request request) async {
        if (request.url.path.contains('selfie')) uploaded = true;
        return json(<String, Object?>{});
      },
    );

    final bool sent = await controller.submit(Uint8List.fromList(<int>[1]), 'image/png');

    expect(sent, isFalse);
    expect(uploaded, isFalse, reason: 'no challenge, no photograph');
  });

  test('the pose comes from the server and is shown in the right language',
      () async {
    final VerificationController controller = await controllerWith(
      (http.Request request) async => json(<String, Object?>{
        'challengeId': 'c-1',
        'pose': 'peace',
        'instructionHe': 'שתי אצבעות ליד הלחי',
        'instructionEn': 'Two fingers beside your cheek',
        'expiresAt':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      }),
    );

    expect(await controller.startChallenge(), isTrue);
    final PoseChallenge pose = controller.challenge!;
    expect(pose.id, 'c-1');
    expect(pose.instructionFor('he'), 'שתי אצבעות ליד הלחי');
    expect(pose.instructionFor('en'), 'Two fingers beside your cheek');
    expect(pose.isLiveAt(DateTime.now()), isTrue);
  });

  test('the selfie is posted against the challenge that was issued', () async {
    String? postedTo;
    final VerificationController controller = await controllerWith(
      (http.Request request) async {
        if (request.url.path.endsWith('/challenge')) {
          return json(<String, Object?>{
            'challengeId': 'c-42',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          });
        }
        postedTo = request.url.toString();
        return json(<String, Object?>{'status': 'pending'}, 201);
      },
    );

    await controller.startChallenge();
    final bool sent =
        await controller.submit(Uint8List.fromList(<int>[1, 2, 3]), 'image/jpeg');

    expect(sent, isTrue);
    expect(postedTo, contains('challenge=c-42'));
    expect(controller.status, VerificationStatus.pending);
    // Spent, so the screen cannot offer a retry that could not work.
    expect(controller.challenge, isNull);
  });

  test('an expired challenge is dropped rather than offered again', () async {
    final VerificationController controller = await controllerWith(
      (http.Request request) async {
        if (request.url.path.endsWith('/challenge')) {
          return json(<String, Object?>{
            'challengeId': 'c-old',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          });
        }
        return json(<String, Object?>{'error': 'challenge_expired'}, 400);
      },
    );

    await controller.startChallenge();
    final bool sent =
        await controller.submit(Uint8List.fromList(<int>[1]), 'image/png');

    expect(sent, isFalse);
    expect(controller.lastErrorCode, 'challenge_expired');
    expect(controller.challenge, isNull);
    expect(controller.status, VerificationStatus.none);
  });

  test('submitting never grants the badge — only a review does', () async {
    // The app must not be able to talk itself into a verified state.
    final VerificationController controller = await controllerWith(
      (http.Request request) async {
        if (request.url.path.endsWith('/challenge')) {
          return json(<String, Object?>{
            'challengeId': 'c-1',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          });
        }
        return json(<String, Object?>{'status': 'pending'}, 201);
      },
    );

    await controller.startChallenge();
    await controller.submit(Uint8List.fromList(<int>[1]), 'image/png');

    expect(controller.status, isNot(VerificationStatus.approved));
  });

  test('a status the server does not recognise reads as not started', () async {
    final VerificationController controller = await controllerWith(
      (http.Request request) async =>
          json(<String, Object?>{'status': 'something-new'}),
    );

    await controller.refresh();
    expect(controller.status, VerificationStatus.none);
  });

  test('a server that cannot be reached leaves the screen usable', () async {
    // Failing to read a status must not block somebody from starting one.
    final VerificationController controller = await controllerWith(
      (http.Request request) async =>
          json(<String, Object?>{'error': 'internal_error'}, 500),
    );

    await controller.refresh();
    expect(controller.status, VerificationStatus.none);
  });
}
