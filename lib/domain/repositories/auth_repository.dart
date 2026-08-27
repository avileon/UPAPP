/// Phone + OTP authentication.
///
/// The SMS provider sits behind this interface on purpose: Twilio, Vonage and
/// the Israeli gateways all get swapped without the app noticing.
abstract interface class AuthRepository {
  /// Maps to `POST /auth/request-otp`.
  Future<void> requestOtp(String phoneNumber);

  /// Maps to `POST /auth/verify-otp`. Returns the user id.
  Future<String> verifyOtp({
    required String phoneNumber,
    required String code,
  });

  Future<void> logOut();

  /// Maps to `DELETE /me`.
  Future<void> deleteAccount();
}
