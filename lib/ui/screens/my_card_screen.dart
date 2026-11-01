import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/card_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/api_client.dart';
import '../../data/api/card_api.dart';
import '../../state/app_scope.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';

/// Your business card, as a QR to scan.
///
/// A fresh code every time the screen opens, and another on demand: each one
/// answers one person, so the next person gets the next code. NFC on Android
/// (phase 3) sends the very same link.
class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key});

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  CardShare? _card;
  String? _error;
  bool _loading = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _issue();
  }

  Future<void> _issue() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    final CardApi? api = context.cards;
    final AppStrings s = context.strings;
    if (api == null) {
      setState(() => _error = s.venueNoServer);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CardShare card = await api.issue();
      if (!mounted) {
        return;
      }
      setState(() {
        _card = card;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.code == 'profile_incomplete'
            ? s.myCardNeedsName
            : errorText(s, error.code);
      });
    }
  }

  Future<void> _revoke() async {
    final CardApi? api = context.cards;
    final AppStrings s = context.strings;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      return;
    }
    try {
      await api.revokeAll();
      messenger.showSnackBar(SnackBar(content: Text(s.myCardRevoked)));
      await _issue();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(s, error.code))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final CardShare? card = _card;

    return UpScaffold(
      child: ListView(
        children: <Widget>[
          UpTopBar(
            title: s.myCard,
            onBack: () => Navigator.of(context).pop(),
          ),
          Text(s.myCardTitle, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Insets.sm),
          Text(s.myCardHint, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Insets.xl),
          if (_error != null)
            UpCard(
              child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            Center(
              child: Container(
                width: 260,
                height: 260,
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  // A QR on a dark background does not scan.
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: card == null || _loading
                    ? const Center(child: CircularProgressIndicator())
                    : QrImageView(
                        data: card.url,
                        version: QrVersions.auto,
                        backgroundColor: const Color(0xFFFFFFFF),
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
              ),
            ),
          const SizedBox(height: Insets.md),
          Text(
            s.myCardOnePerson,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: p.muted),
          ),
          const SizedBox(height: Insets.xl),
          UpButton(
            label: s.myCardNew,
            icon: Icons.refresh_rounded,
            onPressed: _loading ? null : _issue,
          ),
          const SizedBox(height: Insets.sm),
          UpButton(
            label: s.myCardShare,
            style: UpButtonStyle.ghost,
            icon: Icons.link_rounded,
            onPressed: card == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: card.url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.myCardCopied)),
                      );
                    }
                  },
          ),
          const SizedBox(height: Insets.xl),
          UpButton(
            label: s.myCardRevoke,
            style: UpButtonStyle.quiet,
            onPressed: _revoke,
          ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}
