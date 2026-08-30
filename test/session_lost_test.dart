import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up/data/mock/mock_auth_repository.dart';
import 'package:up/data/mock/mock_profile_repository.dart';
import 'package:up/state/session_controller.dart';

/// Losing a session that nobody asked to end.
///
/// The credentials can be dropped from underneath the app — a refresh the
/// server refuses, a revoked session. Before this existed the app kept the
/// profile it had loaded, went on believing it was signed in, and answered
/// every tap with "something went wrong" forever, because nothing needing the
/// server could succeed again and the one screen that would fix it was
/// unreachable.
void main() {
  SessionController controller({VoidCallback? onSignedOut}) {
    return SessionController(
      auth: MockAuthRepository(),
      profiles: MockProfileRepository(),
      onSignedOut: onSignedOut,
    );
  }

  Future<void> signIn(SessionController session) async {
    session.setAcceptedTerms(true);
    await session.requestOtp('0500000000');
    await session.verifyOtp('000000');
  }

  test('a lost session is a signed-out app, not a signed-in broken one', () async {
    bool signedOut = false;
    final SessionController session =
        controller(onSignedOut: () => signedOut = true);
    addTearDown(session.dispose);

    await signIn(session);
    expect(session.isSignedIn, isTrue);

    session.sessionLost();

    expect(session.isSignedIn, isFalse);
    expect(signedOut, isTrue, reason: 'cached photos must not survive it');
  });

  test('losing a session you never had changes nothing', () async {
    bool signedOut = false;
    final SessionController session =
        controller(onSignedOut: () => signedOut = true);
    addTearDown(session.dispose);

    int notifications = 0;
    session.addListener(() => notifications++);

    session.sessionLost();

    expect(session.isSignedIn, isFalse);
    expect(signedOut, isFalse);
    expect(notifications, 0, reason: 'no spurious rebuild of the whole app');
  });
}
