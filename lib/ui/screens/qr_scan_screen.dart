import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/venue_api.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';

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

  @override
  void dispose() {
    _scanner.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null) {
        continue;
      }
      final String? code = VenueApi.codeFromScan(raw);
      if (code != null) {
        _finish(code);
        return;
      }
    }
    setState(() => _error = context.strings.scanInvalid);
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
