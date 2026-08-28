import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/backend_config.dart';
import '../../state/app_scope.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';

/// The room, and the code that opens it.
///
/// This screen is the product's answer to a question the radio cannot answer
/// well: *are we actually in the same place?* A short code two people agree on
/// is coarser than Bluetooth and more certain than it — it holds no
/// coordinates, it cannot be inferred from the air, and it dies with the
/// session. The QR is just the code without the typing: point a camera at the
/// table, land in the room.
class VenueScreen extends StatefulWidget {
  const VenueScreen({super.key});

  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen> {
  final TextEditingController _code = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    _code.text = context.backend.venueCode;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.backend.setVenueCode(_code.text);
    if (!mounted) {
      return;
    }
    setState(() => _code.text = context.backend.venueCode);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final BackendConfig config = context.backend;

    return UpScaffold(
      child: ListenableBuilder(
        listenable: config,
        builder: (BuildContext context, Widget? _) {
          final String code = config.venueCode;
          final String? link = _joinLink(config);

          return ListView(
            children: <Widget>[
              UpTopBar(
                title: s.venueLabel,
                onBack: () => Navigator.of(context).pop(),
              ),
              Text(s.venueTitle,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: Insets.sm),
              Text(s.venueBody, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Insets.xl),

              if (link != null) ...<Widget>[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(Insets.md),
                    decoration: BoxDecoration(
                      // The quiet zone and the light ground are not decoration:
                      // a QR on a dark background does not scan.
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: const Color(0xFFFFFFFF),
                      // A code people scan across a table, in a bar, at an
                      // angle: the highest error correction is worth the extra
                      // density.
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Center(
                  child: Text(
                    code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          color: p.foreground,
                        ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Center(
                  child: Text(
                    s.venueScanHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: Insets.md),
                UpButton(
                  label: s.copyLink,
                  style: UpButtonStyle.quiet,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.linkCopied)),
                      );
                    }
                  },
                ),
              ] else
                UpCard(
                  child: Text(
                    code.isEmpty ? s.venueNoCode : s.venueNoServer,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

              const SizedBox(height: Insets.xl),
              SectionLabel(s.venueLabel),
              const SizedBox(height: Insets.xs + 2),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(hintText: s.venueHint),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: Insets.md),
              UpButton(label: s.serverSave, onPressed: _save),
              const SizedBox(height: Insets.xl),
            ],
          );
        },
      ),
    );
  }

  /// The link a QR encodes, or null when there is nothing to share yet.
  ///
  /// Both halves matter. The address means whoever scans it reaches *this*
  /// server without pasting anything; the venue means they land in this room.
  static String? _joinLink(BackendConfig config) {
    if (!config.isConfigured || config.venueCode.isEmpty) {
      return null;
    }
    return '${config.baseUrl}/?venue=${config.venueCode}';
  }
}
