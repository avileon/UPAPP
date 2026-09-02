import 'package:flutter/foundation.dart';

/// What a browser will tell us about being allowed to interrupt someone.
enum PushPermission {
  /// Nobody has been asked. The only state in which asking is reasonable.
  ask,
  granted,

  /// Asked and refused. Asking again does nothing — browsers remember, and
  /// the prompt never reappears. The app has to say so rather than show a
  /// button that silently fails.
  denied,

  /// No push here at all: an unsupported browser, or a page that is not on a
  /// secure origin. Not an error, just a deployment where notifications are
  /// not on offer.
  unsupported,
}

/// One device's registration, in the shape the server stores.
@immutable
class PushRegistration {
  const PushRegistration({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  /// The URL the push service will accept messages at. Effectively a secret:
  /// anyone holding it can queue a notification to this browser.
  final String endpoint;

  /// The browser's half of the end-to-end encryption.
  final String p256dh;
  final String auth;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'endpoint': endpoint,
        'p256dh': p256dh,
        'auth': auth,
      };
}

/// The browser-side half of notifications.
///
/// Behind an interface with a do-nothing implementation because the Android
/// build must not so much as see `dart:js_interop`, and because every screen
/// that offers the toggle should be testable without a browser.
abstract interface class PushBrowser {
  Future<PushPermission> permission();

  /// Asks, registers the worker, subscribes, and returns what the server needs.
  ///
  /// Null when the person said no, or when the browser refused for any other
  /// reason. Never throws: this is called from a switch someone flipped, and
  /// the worst outcome is that the switch goes back.
  Future<PushRegistration?> enable(String vapidPublicKey);

  /// The current registration, if this browser already has one.
  Future<PushRegistration?> current();

  /// Returns the endpoint that was cancelled, so the server can forget it.
  Future<String?> disable();
}
