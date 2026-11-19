import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/backend_config.dart';
import '../../data/api/venue_api.dart';
import '../../data/qr/qr_photo.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Scans a venue's QR and returns its code (pops with a `String`).
///
/// The phone's own camera app works too — the sticker holds a link that opens
/// UP straight on the join screen. This is for when UP is already open. And
/// the code is printed under the QR, so typing it is always a way in.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  final TextEditingController _typed = TextEditingController();
  bool _done = false;
  String? _error;

  /// The camera did not come up in time: show why, and a way to retry.
  bool _stuck = false;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    _armWatchdog();
  }

  /// Phones sometimes grant the camera and still never start the preview
  /// (the indicator is on, the box stays black). Rather than a black square
  /// forever, after a few seconds say so and offer a restart from a tap —
  /// a start inside a user gesture is the one browsers never block.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 6), () {
      if (!mounted || _done) {
        return;
      }
      final MobileScannerState v = _scanner.value;
      if (!v.isRunning || v.size.isEmpty) {
        setState(() => _stuck = true);
      }
    });
  }

  Future<void> _restart() async {
    setState(() {
      _stuck = false;
      _error = null;
    });
    try {
      await _scanner.stop();
      await _scanner.start();
    } catch (_) {
      // Shown by the scanner's own error state, or by the watchdog.
    }
    _armWatchdog();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _scanner.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // The web scanner sends an empty capture when it starts (to clear old
    // results). Nothing was scanned — that is not an invalid code.
    if (_done || capture.barcodes.isEmpty) {
      return;
    }
    _handle(<String?>[
      for (final Barcode barcode in capture.barcodes) barcode.rawValue,
    ]);
  }

  /// What a scan said, from the live preview or from a photo.
  void _handle(List<String?> values) {
    if (_done) {
      return;
    }
    for (final String? raw in values) {
      if (raw == null || raw.isEmpty) {
        continue;
      }
      // Someone's business card rather than a place: answer it instead.
      final String? card = _cardFromScan(raw);
      if (card != null) {
        _done = true;
        Navigator.of(context)
            .pushReplacementNamed(Routes.cardAccept, arguments: card);
        return;
      }
      final String? code = VenueApi.codeFromScan(raw);
      if (code != null) {
        _finish(code);
        return;
      }
    }
    setState(() => _error = context.strings.scanInvalid);
  }

  /// The way in that does not need the live preview: the phone's own camera
  /// takes a photo, the browser reads the QR out of it.
  Future<void> _fromPhoto() async {
    setState(() => _error = null);
    String? raw;
    try {
      raw = await qrFromPhoto();
    } catch (_) {
      raw = '';
    }
    if (!mounted || raw == null) {
      return;
    }
    if (raw.isEmpty) {
      setState(() => _error = context.strings.scanPhotoNoCode);
      return;
    }
    _handle(<String?>[raw]);
  }

  /// The token of an UP card link (`…/c/<token>`), or null.
  static String? _cardFromScan(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    final List<String> parts = uri.pathSegments;
    if (parts.length != 2 || parts.first != 'c') {
      return null;
    }
    return BackendConfig.normaliseCardToken(parts[1]);
  }

  void _submitTyped() {
    final String? code = VenueApi.codeFromScan(_typed.text);
    if (code == null) {
      setState(() => _error = context.strings.scanInvalid);
      return;
    }
    _finish(code);
  }

  void _finish(String code) {
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;

    return UpScaffold(
      child: ListView(
        children: <Widget>[
          UpTopBar(
            title: s.scanQr,
            onBack: () => Navigator.of(context).pop(),
          ),
          Text(s.scanTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Insets.xs),
          Text(s.scanHint, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Insets.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: Colors.black,
                    child: MobileScanner(
                      controller: _scanner,
                      onDetect: _onDetect,
                      placeholderBuilder: (BuildContext context) =>
                          _CameraNote(text: s.scanStarting, busy: true),
                      errorBuilder: (BuildContext context,
                              MobileScannerException e) =>
                          _CameraNote(
                        text: e.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? s.scanCameraUnavailable
                            : '${s.scanStuck}\n(${e.errorDetails?.message ?? e.errorCode.name})',
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.65,
                        heightFactor: 0.65,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(color: p.cyan, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (qrPhotoSupported) ...<Widget>[
            const SizedBox(height: Insets.md),
            UpButton(
              label: s.scanPhoto,
              style: UpButtonStyle.ghost,
              onPressed: _fromPhoto,
            ),
          ],
          if (_stuck) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              s.scanStuck,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.sm),
            UpButton(
              label: s.scanRetry,
              style: UpButtonStyle.ghost,
              onPressed: _restart,
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: Insets.xl),
          Text(s.scanTypeCode, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _typed,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(letterSpacing: 3, fontSize: 20),
            decoration: InputDecoration(hintText: s.scanCodeHint),
            onSubmitted: (_) => _submitTyped(),
          ),
          const SizedBox(height: Insets.md),
          UpButton(label: s.cont, onPressed: _submitTyped),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

/// What sits in the camera box while there is no picture to show.
class _CameraNote extends StatelessWidget {
  const _CameraNote({required this.text, this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy) ...<Widget>[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: Insets.md),
              ],
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
