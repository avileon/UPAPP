import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';

/// Where a person stands with photo verification.
enum VerificationStatus {
  /// Never submitted anything.
  none,

  /// Submitted, waiting for a human.
  pending,

  approved,

  /// Looked at and turned down. Trying again is the whole remedy.
  rejected,
}

/// The pose the server just asked for, and how long it stays answerable.
@immutable
class PoseChallenge {
  const PoseChallenge({
    required this.id,
    required this.instructionHe,
    required this.instructionEn,
    required this.expiresAt,
  });

  final String id;
  final String instructionHe;
  final String instructionEn;
  final DateTime expiresAt;

  String instructionFor(String localeCode) =>
      localeCode == 'he' ? instructionHe : instructionEn;

  bool isLiveAt(DateTime now) => now.isBefore(expiresAt);
}

/// Photo verification, and an honest account of what it proves.
///
/// It does not prove the photo was taken now — a browser cannot tell a server
/// that, and every signal it could send is produced by software the person
/// controls. What it does is raise the cost: the camera opens instead of a
/// file picker, and the server names a pose seconds beforehand out of five, so
/// reusing somebody else's face means finding a photo of that person, in that
/// pose, taken since the challenge was issued.
///
/// The badge is then granted by a person looking at it. Automatic approval
/// would be a claim this system cannot back, and a badge that cannot be backed
/// is worse than none — people trust it.
class VerificationController extends ChangeNotifier {
  VerificationController({required ApiClient client}) : _client = client;

  final ApiClient _client;

  VerificationStatus get status => _status;
  VerificationStatus _status = VerificationStatus.none;

  /// The live challenge, if one has been asked for and has not expired.
  PoseChallenge? get challenge => _challenge;
  PoseChallenge? _challenge;

  bool get busy => _busy;
  bool _busy = false;

  /// Why the last attempt failed, as the server's code. Cleared by the next.
  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;

  Future<void> refresh() async {
    try {
      final Map<String, dynamic> result = await _client.get('/me/verification');
      _status = _parse(result['status']);
    } on ApiException {
      // A status this screen could not read is not worth an error: the person
      // can still start a verification, and the answer arrives with it.
    }
    notifyListeners();
  }

  /// Asks for a pose. Nothing before this point involves the camera.
  Future<bool> startChallenge() async {
    if (_busy) {
      return false;
    }
    _set(busy: true, error: null);
    try {
      final Map<String, dynamic> result =
          await _client.post('/me/verification/challenge');
      final String id = _string(result['challengeId']);
      if (id.isEmpty) {
        return false;
      }
      _challenge = PoseChallenge(
        id: id,
        instructionHe: _string(result['instructionHe']),
        instructionEn: _string(result['instructionEn']),
        expiresAt: DateTime.tryParse(_string(result['expiresAt'])) ??
            DateTime.now().add(const Duration(minutes: 5)),
      );
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      return false;
    } finally {
      _set(busy: false);
    }
  }

  /// Sends the photo against the live challenge.
  ///
  /// The challenge is consumed by the server whether or not this succeeds, so
  /// it is dropped here too — leaving a spent one on screen would offer a
  /// retry that cannot work.
  Future<bool> submit(Uint8List bytes, String contentType) async {
    final PoseChallenge? live = _challenge;
    if (_busy || live == null || bytes.isEmpty) {
      return false;
    }
    _set(busy: true, error: null);
    try {
      await _client.postBytes(
        '/me/verification/selfie?challenge=${Uri.encodeComponent(live.id)}',
        bytes,
        contentType,
      );
      _status = VerificationStatus.pending;
      _challenge = null;
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      if (error.code == 'challenge_expired') {
        _challenge = null;
      }
      return false;
    } finally {
      _set(busy: false);
    }
  }

  /// Throws the current pose away without sending anything.
  void cancel() {
    _challenge = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  static VerificationStatus _parse(Object? raw) => switch (raw) {
        'pending' => VerificationStatus.pending,
        'approved' => VerificationStatus.approved,
        'rejected' => VerificationStatus.rejected,
        _ => VerificationStatus.none,
      };

  static String _string(Object? value) => value is String ? value : '';

  void _set({bool? busy, String? error}) {
    if (busy != null) _busy = busy;
    if (error != null || busy == true) _lastErrorCode = error;
    notifyListeners();
  }
}
