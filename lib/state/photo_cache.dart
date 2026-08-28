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
  final Set<String> _failed = <String>{};
  bool _disposed = false;

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
    if (_fetch == null || _inFlight.contains(key) || _failed.contains(key)) {
      return null;
    }
    _inFlight.add(key);
    _fetch(key).then((Uint8List? value) {
      _inFlight.remove(key);
      if (value == null || value.isEmpty) {
        // Remember the failure. Without this a missing photo becomes a request
        // on every rebuild, which on a list is a request per frame.
        _failed.add(key);
        return;
      }
      _put(key, value);
      _notify();
    }).catchError((Object _) {
      _inFlight.remove(key);
      _failed.add(key);
    });
    return null;
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
    _failed.remove(key);
    _notify();
  }

  void forget(String key) {
    if (_bytes.remove(key) != null) {
      _order.remove(key);
      _notify();
    }
    _failed.remove(key);
  }

  /// Lets a key that failed be tried again — after a reconnect, say.
  void retryFailed() {
    if (_failed.isEmpty) {
      return;
    }
    _failed.clear();
    _notify();
  }

  void clear() {
    _bytes.clear();
    _order.clear();
    _failed.clear();
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
