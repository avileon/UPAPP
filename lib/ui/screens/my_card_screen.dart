import 'dart:async';

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
import '../../data/nfc/nfc_card.dart';
import '../../domain/entities/match_thread.dart';
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

  final NfcCard _nfc = const NfcCard();
  NfcCardStatus _nfcStatus = NfcCardStatus.none;
  Timer? _nfcTimer;
  StreamSubscription<MatchThread>? _matches;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // Someone answered the card: that code is spent, the next person gets a
    // new one without anybody pressing anything.
    _matches = context.interactions.newMatches.listen((_) => _issue());
    _issue();
    _refreshNfc();
    // Picks up NFC being switched on in settings, and every read.
    _nfcTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshNfc());
  }

  Future<void> _refreshNfc() async {
    final NfcCardStatus status = await _nfc.status();
    if (!mounted) {
      return;
    }
    if (status.supported != _nfcStatus.supported ||
        status.enabled != _nfcStatus.enabled ||
        status.reads != _nfcStatus.reads) {
      setState(() => _nfcStatus = status);
    }
  }

  @override
  void dispose() {
    _nfcTimer?.cancel();
    _matches?.cancel();
    // The phone stops being a tag the moment this screen closes.
    _nfc.stop();
    super.dispose();
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
    // The old code may already be spent; never send it while a new one loads.
    await _nfc.stop();
    try {
      final CardShare card = await api.issue();
      if (!mounted) {
        return;
      }
      await _nfc.start(card.url);
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
          if (_error == null && _nfcStatus.supported) ...<Widget>[
            _NfcPanel(
              status: _nfcStatus,
              onTurnOn: _nfc.openSettings,
            ),
            const SizedBox(height: Insets.lg),
          ],
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

/// "Hold the phones together" — or, with NFC off, the way to turn it on.
class _NfcPanel extends StatelessWidget {
  const _NfcPanel({required this.status, required this.onTurnOn});

  final NfcCardStatus status;
  final Future<void> Function() onTurnOn;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    if (!status.enabled) {
      return UpCard(
        borderColor: p.amber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(s.nfcOff, style: text.titleMedium),
            const SizedBox(height: Insets.xs),
            Text(s.nfcOffHint, style: text.bodyMedium),
            const SizedBox(height: Insets.md),
            UpButton(
              label: s.nfcTurnOn,
              icon: Icons.nfc_rounded,
              style: UpButtonStyle.ghost,
              onPressed: onTurnOn,
            ),
          ],
        ),
      );
    }
    return UpCard(
      borderColor: p.cyan,
      child: Row(
        children: <Widget>[
          Icon(Icons.nfc_rounded, size: 40, color: p.cyan),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  status.reads > 0 ? s.nfcSent(status.reads) : s.nfcReady,
                  style: text.titleMedium,
                ),
                const SizedBox(height: Insets.xs),
                Text(s.nfcReadyHint, style: text.bodySmall?.copyWith(color: p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
