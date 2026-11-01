import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the phone can do with its business card over NFC.
@immutable
class NfcCardStatus {
  const NfcCardStatus({
    required this.supported,
    required this.enabled,
    this.reads = 0,
  });

  static const NfcCardStatus none =
      NfcCardStatus(supported: false, enabled: false);

  /// The hardware can act as a tag (Android with NFC and HCE).
  final bool supported;

  /// NFC is switched on in the phone's settings.
  final bool enabled;

  /// How many times another phone has read the card since the app started.
  final int reads;
}

/// The Android side lives in `android_overlay/` (CardHceService). Everywhere
/// else — the browser, an iPhone — there is no channel and every call answers
/// "not supported" rather than throwing.
class NfcCard {
  const NfcCard();

  static const MethodChannel _channel = MethodChannel('up/nfc_card');

  bool get _possible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NfcCardStatus> status() async {
    if (!_possible) {
      return NfcCardStatus.none;
    }
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMapMethod<Object?, Object?>('status');
      final Object? reads = raw?['reads'];
      return NfcCardStatus(
        supported: raw?['supported'] == true,
        enabled: raw?['enabled'] == true,
        reads: reads is int ? reads : 0,
      );
    } on PlatformException {
      return NfcCardStatus.none;
    } on MissingPluginException {
      return NfcCardStatus.none;
    }
  }

  /// Starts answering as a tag that holds [url]. Until [stop].
  Future<void> start(String url) => _call('start', <String, Object?>{'url': url});

  Future<void> stop() => _call('stop');

  Future<void> openSettings() => _call('openSettings');

  Future<void> _call(String method, [Object? arguments]) async {
    if (!_possible) {
      return;
    }
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException {
      // A phone that cannot do it simply shows the QR.
    } on MissingPluginException {
      // Same.
    }
  }
}
