import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Photo bytes, fetched once and kept in memory.
///
/// Not `Image.network`: the photo endpoint needs the caller's bearer token,
/// and that is the whole point of it — a photo URL that works without one is a
/// URL that works forever once forwarded. So the bytes come down through the
/// same authenticated client as everything else, and this holds them so that
/// scrolling a list does not re-download a face every frame.
///
/// In memory only, and small on purpose. These are other people's photographs;
/// closing the app should forget them, and nothing here writes to disk.
class PhotoCache extends ChangeNotifier {
  PhotoCache({Future<Uint8List?> Function(String key)? fetch}) : _fetch = fetch;

  final Future<Uint8List?> Function(String key)? _fetch;

  final Map<String, Uint8List> _bytes = <String, Uint8List>{};
  final List<String> _order = <String>[];
  final Set<String> _inFlight = <String>{};

  /// Keys not worth asking about again, and until when.
  ///
  /// Two very different failures land here. A photo the server says it does
  /// not have will never appear, so it is parked for good. A photo that failed
  /// because the tunnel blinked will be there in a moment, so it is parked
  /// briefly — a two-second hiccup while scrolling must not blank someone's
  /// face for the rest of the session.
  final Map<String, DateTime> _quietUntil = <String, DateTime>{};
  bool _disposed = false;

  static final DateTime _forever = DateTime.utc(9999);
  static const Duration _afterTransientFailure = Duration(seconds: 15);

  /// Roughly a screen or two of faces. Past this the oldest are dropped and
  /// re-fetched if they come back into view.
  static const int _maxEntries = 60;

  /// The bytes for [key], or null while they are on their way.
  ///
  /// Calling this starts the fetch. A widget therefore asks for what it wants
  /// to draw and draws the placeholder until the answer arrives, which is also
  /// exactly what it should do on a slow connection.
  Uint8List? bytesFor(String? key) {
    if (key == null || key.isEmpty) {
      return null;
    }
    final Uint8List? cached = _bytes[key];
    if (cached != null) {
      return cached;
    }
    if (_fetch == null || _inFlight.contains(key) || _isQuiet(key)) {
      return null;
    }
    _inFlight.add(key);
    _fetch(key).then((Uint8List? value) {
      _inFlight.remove(key);
      if (value == null || value.isEmpty) {
        // The server answered and has nothing. Without parking the key, a
        // missing photo becomes a request on every rebuild — on a scrolling
        // list, a request per frame.
        _quietUntil[key] = _forever;
        return;
      }
      _quietUntil.remove(key);
      _put(key, value);
      _notify();
    }).catchError((Object _) {
      _inFlight.remove(key);
      _quietUntil[key] = DateTime.now().add(_afterTransientFailure);
    });
    return null;
  }

  bool _isQuiet(String key) {
    final DateTime? until = _quietUntil[key];
    if (until == null) {
      return false;
    }
    if (until.isAfter(DateTime.now())) {
      return true;
    }
    _quietUntil.remove(key);
    return false;
  }

  void _put(String key, Uint8List value) {
    if (!_bytes.containsKey(key)) {
      _order.add(key);
    }
    _bytes[key] = value;
    while (_order.length > _maxEntries) {
      _bytes.remove(_order.removeAt(0));
    }
  }

  /// Puts bytes in directly — the photo you just picked, before the upload has
  /// even finished, so your own grid fills the moment you choose the picture.
  void remember(String key, Uint8List value) {
    _put(key, value);
    _quietUntil.remove(key);
    _notify();
  }

  void forget(String key) {
    if (_bytes.remove(key) != null) {
      _order.remove(key);
      _notify();
    }
    _quietUntil.remove(key);
  }

  /// Lets every parked key be tried again — after a reconnect, say.
  void retryFailed() {
    if (_quietUntil.isEmpty) {
      return;
    }
    _quietUntil.clear();
    _notify();
  }

  void clear() {
    _bytes.clear();
    _order.clear();
    _quietUntil.clear();
    _notify();
  }

  /// A fetch can land after the cache has been thrown away — a change of
  /// server tears this down while requests are still in the air. Notifying a
  /// disposed [ChangeNotifier] throws, and it would throw from inside a
  /// callback nobody is awaiting.
  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _bytes.clear();
    _order.clear();
    super.dispose();
  }
}
