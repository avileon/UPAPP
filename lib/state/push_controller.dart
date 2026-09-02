import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/push/push_browser.dart';

/// Whether this device will be interrupted, and the one switch that decides.
///
/// Three facts have to agree before a notification can arrive: the deployment
/// has signing keys, the browser has permission, and the server has this
/// browser's subscription. Any one of them missing means silence, and each
/// fails in a different way — so they are gathered here rather than left for a
/// settings screen to reason about.
class PushController extends ChangeNotifier {
  PushController({required ApiClient client, PushBrowser? browser})
      : _client = client,
        _browser = browser ?? createPushBrowser();

  final ApiClient _client;
  final PushBrowser _browser;

  /// Empty until asked, and empty forever on a deployment with no keys — which
  /// is how the app knows not to offer the switch at all.
  String _vapidKey = '';
  PushPermission _permission = PushPermission.unsupported;
  bool _subscribed = false;
  bool _busy = false;

  /// Notifications are on offer here at all.
  bool get available =>
      _vapidKey.isNotEmpty && _permission != PushPermission.unsupported;

  /// This browser has been told no, and cannot be asked again.
  ///
  /// Worth its own state: the switch has to explain that it is now a browser
  /// setting rather than sit there doing nothing when tapped.
  bool get blocked => _permission == PushPermission.denied;

  bool get enabled => _subscribed && _permission == PushPermission.granted;
  bool get busy => _busy;

  /// Reads the three facts. Safe to call on every sign-in.
  Future<void> refresh() async {
    _permission = await _browser.permission();
    if (_permission == PushPermission.unsupported) {
      _set(vapidKey: '', subscribed: false);
      return;
    }
    _vapidKey = await _fetchKey();
    final PushRegistration? existing = await _browser.current();
    _subscribed = existing != null;
    // Re-send it. A subscription the browser still holds but the server has
    // forgotten — a restored database, a cleared table, an endpoint the push
    // service rotated — is the failure mode with no symptom: everything looks
    // enabled and nothing ever arrives.
    if (existing != null && _vapidKey.isNotEmpty) {
      await _sendToServer(existing);
    }
    notifyListeners();
  }

  /// Turns notifications on. Returns whether it worked.
  Future<bool> enable() async {
    if (_busy || _vapidKey.isEmpty) {
      return false;
    }
    _set(busy: true);
    try {
      final PushRegistration? registration = await _browser.enable(_vapidKey);
      _permission = await _browser.permission();
      if (registration == null) {
        _subscribed = false;
        return false;
      }
      _subscribed = await _sendToServer(registration);
      return _subscribed;
    } finally {
      _set(busy: false);
    }
  }

  Future<void> disable() async {
    if (_busy) {
      return;
    }
    _set(busy: true);
    try {
      final String? endpoint = await _browser.disable();
      _subscribed = false;
      if (endpoint != null) {
        // Told to the server too, or it keeps sending into an endpoint the
        // browser has already cancelled.
        try {
          await _client.post(
            '/push/unsubscribe',
            <String, dynamic>{'endpoint': endpoint},
          );
        } on ApiException {
          // The browser has already stopped listening; the row is stale, not
          // dangerous, and the push service will report it gone on the next
          // send.
        }
      }
    } finally {
      _set(busy: false);
    }
  }

  Future<String> _fetchKey() async {
    try {
      final Map<String, dynamic> result = await _client.get('/push/key');
      final Object? key = result['publicKey'];
      return key is String ? key : '';
    } on ApiException {
      return '';
    }
  }

  Future<bool> _sendToServer(PushRegistration registration) async {
    try {
      await _client.post('/push/subscribe', registration.toJson());
      return true;
    } on ApiException {
      return false;
    }
  }

  void _set({String? vapidKey, bool? subscribed, bool? busy}) {
    if (vapidKey != null) _vapidKey = vapidKey;
    if (subscribed != null) _subscribed = subscribed;
    if (busy != null) _busy = busy;
    notifyListeners();
  }
}
