/// Read a QR from a photo the phone's own camera app takes.
///
/// The live preview inside the browser fails on some phones (the camera
/// turns on, the box stays black). Taking a photo with the system camera and
/// decoding it with the browser's BarcodeDetector does not depend on that
/// preview at all.
export 'qr_photo_stub.dart' if (dart.library.js_interop) 'qr_photo_web.dart';
