import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Chrome on Android has BarcodeDetector; Safari does not (yet).
bool get qrPhotoSupported => globalContext.has('BarcodeDetector');

/// Opens the phone's camera, waits for a photo, and returns what the first QR
/// in it says. `null` when the person backed out, `''` when the photo had no
/// readable QR.
Future<String?> qrFromPhoto() async {
  final web.HTMLInputElement input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  input.setAttribute('capture', 'environment');

  final Completer<web.File?> picked = Completer<web.File?>();
  input.addEventListener(
    'change',
    ((web.Event _) {
      if (!picked.isCompleted) {
        final web.FileList? files = input.files;
        picked.complete(files != null && files.length > 0 ? files.item(0) : null);
      }
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!picked.isCompleted) {
        picked.complete(null);
      }
    }).toJS,
  );
  input.click();

  final web.File? file = await picked.future;
  if (file == null) {
    return null;
  }

  final web.ImageBitmap bitmap = await web.window.createImageBitmap(file).toDart;
  final JSFunction ctor = globalContext['BarcodeDetector']! as JSFunction;
  final JSObject options = JSObject()
    ..['formats'] = <JSString>['qr_code'.toJS].toJS;
  final JSObject detector = ctor.callAsConstructor<JSObject>(options);
  final JSArray<JSObject> found = await detector
      .callMethod<JSPromise<JSArray<JSObject>>>('detect'.toJS, bitmap)
      .toDart;
  for (final JSObject code in found.toDart) {
    final JSAny? raw = code['rawValue'];
    if (raw != null && raw.isA<JSString>()) {
      return (raw as JSString).toDart;
    }
  }
  return '';
}
