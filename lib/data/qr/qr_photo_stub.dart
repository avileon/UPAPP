/// Not a browser: the native scanner has its own preview, no fallback needed.
bool get qrPhotoSupported => false;

/// Never called where [qrPhotoSupported] is false.
Future<String?> qrFromPhoto() async => null;
