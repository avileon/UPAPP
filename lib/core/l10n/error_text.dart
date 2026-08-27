import 'app_strings.dart';

/// Turns a server error code into something a person can act on.
///
/// One function rather than a `switch` per screen, because the mapping is a
/// product decision and it has to be the same everywhere. Only the codes worth
/// distinguishing get their own sentence: "you are not old enough" and "the
/// server is unreachable" lead somewhere different, and everything else is
/// noise a user cannot do anything with.
String errorText(AppStrings strings, String? code) {
  switch (code) {
    case null:
      return '';
    case 'no_server':
    case 'timeout':
    case 'unreachable':
    case 'tls_failed':
    case 'bad_response':
      return strings.errorOffline;
    case 'under_minimum_age':
      return strings.errorUnderAge;
    case 'otp_incorrect':
    case 'otp_expired':
    case 'otp_not_requested':
      return strings.errorOtpWrong;
    case 'otp_rate_limited':
    case 'otp_attempts_exhausted':
    case 'like_rate_limited':
      return strings.errorRateLimited;
    default:
      return strings.errorGeneric;
  }
}
