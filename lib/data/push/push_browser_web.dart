import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'push_types.dart';

/// Web Push, through the browser's own APIs.
///
/// The only file in the app that touches `dart:js_interop`, and it is kept
/// deliberately narrow: register a worker, subscribe, hand back three strings.
/// Everything about *when* to ask and what to do with the result lives in Dart
/// that a test can run.
class BrowserPush implements PushBrowser {
  const BrowserPush();

  /// Scope, and the reason it is not the site root.
  ///
  /// Flutter registers its own service worker at `/`, and two workers cannot
  /// control one scope — the second registration replaces the first, which
  /// would take the app's offline behaviour with it. Serving this one from
  /// `push/` gives it a scope of its own by default, with no server header
  /// needed. A push subscription belongs to the *registration*, not to the
  /// scope, so a worker that controls no pages still receives every message.
  static const String _workerPath = 'push/sw.js';

  /// Asked of the global object rather than of a typed binding.
  ///
  /// The typed bindings promise these exist; the browser is the authority on
  /// whether they do. Service workers are absent entirely outside a secure
  /// origin, which is the honest answer on a plain-http development server and
  /// would otherwise surface as a crash in the middle of a settings screen.
  bool get _available =>
      globalContext.has('PushManager') &&
      globalContext.has('Notification') &&
      globalContext.has('ServiceWorkerRegistration');

  @override
  Future<PushPermission> permission() async {
    if (!_available) {
      return PushPermission.unsupported;
    }
    return switch (web.Notification.permission) {
      'granted' => PushPermission.granted,
      'denied' => PushPermission.denied,
      _ => PushPermission.ask,
    };
  }

  @override
  Future<PushRegistration?> enable(String vapidPublicKey) async {
    if (!_available || vapidPublicKey.isEmpty) {
      return null;
    }
    try {
      // Asking is a one-shot: a browser that has been told no once will never
      // show the prompt again, so this must only ever be reached from an
      // explicit action by the person.
      final String outcome =
          (await web.Notification.requestPermission().toDart).toDart;
      if (outcome != 'granted') {
        return null;
      }

      final web.ServiceWorkerRegistration registration = await web
          .window.navigator.serviceWorker
          .register(_workerPath)
          .toDart;

      final web.PushSubscription subscription = await registration.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              // Required by every browser that implements this: a subscription
              // may not be used for anything the person cannot see. Which is
              // also the policy we would have chosen.
              userVisibleOnly: true,
              // The spec allows the key as a base64url string as well as a
              // buffer, and every engine that ships Push accepts it.
              applicationServerKey: vapidPublicKey.toJS,
            ),
          )
          .toDart;

      return _read(subscription);
    } catch (_) {
      // A refused prompt, a blocked worker, a push service that will not
      // answer. None of them is worth an error screen — the switch goes back
      // and the app keeps polling.
      return null;
    }
  }

  @override
  Future<PushRegistration?> current() async {
    if (!_available) {
      return null;
    }
    try {
      final web.ServiceWorkerRegistration? registration =
          await web.window.navigator.serviceWorker.getRegistration(_workerPath).toDart;
      if (registration == null) {
        return null;
      }
      final web.PushSubscription? subscription =
          await registration.pushManager.getSubscription().toDart;
      return subscription == null ? null : _read(subscription);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> disable() async {
    if (!_available) {
      return null;
    }
    try {
      final web.ServiceWorkerRegistration? registration =
          await web.window.navigator.serviceWorker.getRegistration(_workerPath).toDart;
      final web.PushSubscription? subscription =
          await registration?.pushManager.getSubscription().toDart;
      if (subscription == null) {
        return null;
      }
      final String endpoint = subscription.endpoint;
      await subscription.unsubscribe().toDart;
      // The endpoint goes back to the caller rather than being forgotten here,
      // because the server has a row for it and a row nobody deletes is a
      // notification sent into the void every time somebody writes.
      return endpoint;
    } catch (_) {
      return null;
    }
  }

  /// Pulls the two keys out, which the browser hands over as raw buffers.
  ///
  /// base64url without padding, because that is what the push protocol uses
  /// everywhere else and it survives a JSON round trip and a URL unchanged.
  PushRegistration? _read(web.PushSubscription subscription) {
    final JSArrayBuffer? p256dh = subscription.getKey('p256dh');
    final JSArrayBuffer? auth = subscription.getKey('auth');
    if (p256dh == null || auth == null) {
      return null;
    }
    return PushRegistration(
      endpoint: subscription.endpoint,
      p256dh: _encode(p256dh),
      auth: _encode(auth),
    );
  }

  String _encode(JSArrayBuffer buffer) =>
      base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
}

PushBrowser createPushBrowser() => const BrowserPush();
