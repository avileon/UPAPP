import '../../domain/repositories/auth_repository.dart';
import 'api_client.dart';

/// Phone + OTP against the real server.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient client,
    required bool Function() acceptedTerms,
  })  : _client = client,
        _acceptedTerms = acceptedTerms;

  final ApiClient _client;
  final bool Function() _acceptedTerms;

  String? _devCode;

  /// The code the server hands back while `SMS_PROVIDER=mock`, so the OTP
  /// screen can show it instead of asking you to read the server log.
  ///
  /// This is null the moment a real SMS provider is configured, because the
  /// server stops sending it — the field cannot become a backdoor by accident.
  String? get devCode => _devCode;

  @override
  Future<void> requestOtp(String phoneNumber) async {
    final Map<String, dynamic> result = await _client.send(
      'POST',
      '/auth/request-otp',
      body: <String, dynamic>{'phone': phoneNumber},
      authenticated: false,
    );
    _devCode = result['devCode'] as String?;
  }

  @override
  Future<String> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final Map<String, dynamic> result = await _client.send(
      'POST',
      '/auth/verify-otp',
      body: <String, dynamic>{
        'phone': phoneNumber,
        'code': code,
        'acceptedTerms': _acceptedTerms(),
      },
      authenticated: false,
    );
    await _client.config.setTokens(
      accessToken: result['accessToken'] as String?,
      refreshToken: result['refreshToken'] as String?,
    );
    _devCode = null;

    // The verify response deliberately carries tokens and nothing else, so the
    // id comes from the profile call that every signed-in session makes anyway.
    final Map<String, dynamic> profile = await _client.get('/me/profile');
    return profile['id'] as String? ?? '';
  }

  @override
  Future<void> logOut() async {
    _devCode = null;
    await _client.config.clearTokens();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.delete('/me');
    } on ApiException catch (_) {
      // Whatever the server says, this device is done with the account.
    }
    await logOut();
  }
}
