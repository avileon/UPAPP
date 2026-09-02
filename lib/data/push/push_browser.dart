/// The one import the rest of the app uses.
///
/// Splitting the types out of the implementation is what lets the Android
/// build resolve this file at all: `dart.library.js_interop` picks the web
/// implementation in a browser and the do-nothing one everywhere else, and
/// neither the types nor the callers know which they got.
export 'push_browser_stub.dart'
    if (dart.library.js_interop) 'push_browser_web.dart';
export 'push_types.dart';
