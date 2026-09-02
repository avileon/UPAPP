import 'push_types.dart';

/// Notifications on a platform that has no Web Push.
///
/// The Android build lands here. It is not a gap being papered over: the
/// native app's answer is Firebase Cloud Messaging, which is a different
/// mechanism with a different token and a different consent flow, and
/// pretending one interface covers both would only make that day harder.
/// Until then this reports `unsupported`, the settings toggle does not appear,
/// and everything else in the app behaves identically.
class BrowserPush implements PushBrowser {
  const BrowserPush();

  @override
  Future<PushPermission> permission() async => PushPermission.unsupported;

  @override
  Future<PushRegistration?> enable(String vapidPublicKey) async => null;

  @override
  Future<PushRegistration?> current() async => null;

  @override
  Future<String?> disable() async => null;
}

PushBrowser createPushBrowser() => const BrowserPush();
