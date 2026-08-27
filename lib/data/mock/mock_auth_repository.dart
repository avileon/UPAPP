import '../../domain/repositories/auth_repository.dart';

/// In-memory auth. Any 4-digit code verifies.
class MockAuthRepository implements AuthRepository {
  String? _pendingPhone;
  String? _userId;

  String? get signedInUserId => _userId;

  static const Duration _networkDelay = Duration(milliseconds: 450);

  @override
  Future<void> requestOtp(String phoneNumber) async {
    await Future<void>.delayed(_networkDelay);
    _pendingPhone = phoneNumber;
  }

  @override
  Future<String> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (code.trim().isEmpty) {
      throw const FormatException('Empty code');
    }
    _pendingPhone = phoneNumber;
    _userId = 'me';
    return _userId!;
  }

  @override
  Future<void> logOut() async {
    _userId = null;
    _pendingPhone = null;
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(_networkDelay);
    _userId = null;
    _pendingPhone = null;
  }

  String? get pendingPhone => _pendingPhone;
}
