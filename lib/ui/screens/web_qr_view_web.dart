import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Chrome on Android (and desktop Chrome/Edge) has BarcodeDetector. Where it
/// is missing (Safari) the screen falls back to mobile_scanner.
bool get webQrSupported => globalContext.has('BarcodeDetector');

/// A live QR scanner built straight on the browser: getUserMedia into a
/// muted, inline <video>, and BarcodeDetector reading it a few times a second.
///
/// Why not mobile_scanner on the web: on a Galaxy S23 its start never
/// finished — the camera light came on and the box stayed on "opening"
/// forever. It tunes focus/exposure through `applyConstraints` and plays a
/// <video> that is not in the page yet, and either can wait forever on some
/// phones. This asks for the camera with nothing but "the back one", shows
/// the video as soon as it is in the page, and never waits on play().
class WebQrView extends StatefulWidget {
  const WebQrView({
    super.key,
    required this.onCode,
    required this.startingText,
    required this.stuckText,
    required this.retryText,
  });

  final void Function(String raw) onCode;
  final String startingText;
  final String stuckText;
  final String retryText;

  @override
  State<WebQrView> createState() => _WebQrViewState();
}

class _WebQrViewState extends State<WebQrView> {
  static int _seq = 0;
  final String _viewType = 'appdate-qr-${_seq++}';

  late final web.HTMLVideoElement _video;
  web.MediaStream? _stream;
  JSObject? _detector;
  Timer? _poll;
  Timer? _stuckTimer;
  bool _busy = false;
  bool _showing = false;
  bool _stuck = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.setAttribute('playsinline', '');
    _video.setAttribute('muted', '');
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..pointerEvents = 'none';
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _video);
    final JSFunction ctor = globalContext['BarcodeDetector']! as JSFunction;
    _detector = ctor.callAsConstructor<JSObject>(
      JSObject()..['formats'] = <JSString>['qr_code'.toJS].toJS,
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_showing) {
        setState(() => _stuck = true);
      }
    });
    try {
      final web.MediaStreamConstraints constraints = <String, Object>{
        'audio': false,
        'video': <String, Object>{
          'facingMode': <String, String>{'ideal': 'environment'},
        },
      }.jsify()! as web.MediaStreamConstraints;
      final web.MediaStream stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      _stream = stream;
      _video.srcObject = stream;
      _play();
      _poll?.cancel();
      _poll = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_tick()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  /// Fire and forget: on some phones the promise never settles, and nothing
  /// here waits for it. Whether a picture is showing is read off the video.
  void _play() {
    _video.play().toDart.then((_) {}, onError: (Object _) {});
  }

  Future<void> _tick() async {
    if (_busy || !mounted) {
      return;
    }
    final bool picture = _video.readyState >= 2 && _video.videoWidth > 0;
    if (picture != _showing) {
      setState(() {
        _showing = picture;
        if (picture) {
          _stuck = false;
        }
      });
    }
    if (!picture) {
      if (_video.paused) {
        _play();
      }
      return;
    }
    _busy = true;
    try {
      final JSArray<JSObject> found = await _detector!
          .callMethod<JSPromise<JSArray<JSObject>>>('detect'.toJS, _video)
          .toDart;
      for (final JSObject code in found.toDart) {
        final JSAny? raw = code['rawValue'];
        if (raw != null && raw.isA<JSString>() && mounted) {
          widget.onCode((raw as JSString).toDart);
          return;
        }
      }
    } catch (_) {
      // A frame that could not be read; the next tick tries again.
    } finally {
      _busy = false;
    }
  }

  Future<void> _retry() async {
    _poll?.cancel();
    final web.MediaStream? old = _stream;
    _stream = null;
    if (old != null) {
      _stopTracks(old);
    }
    setState(() {
      _stuck = false;
      _error = null;
      _showing = false;
    });
    await _start();
  }

  static void _stopTracks(web.MediaStream stream) {
    for (final web.MediaStreamTrack t in stream.getTracks().toDart) {
      t.stop();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stuckTimer?.cancel();
    final web.MediaStream? s = _stream;
    if (s != null) {
      _stopTracks(s);
    }
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool trouble = _stuck || _error != null;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        HtmlElementView(viewType: _viewType),
        if (!_showing)
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!trouble) ...<Widget>[
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      trouble
                          ? (_error == null
                              ? widget.stuckText
                              : '${widget.stuckText}\n($_error)')
                          : widget.startingText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (trouble) ...<Widget>[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _retry,
                        child: Text(widget.retryText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
