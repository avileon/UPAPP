import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../../state/verification_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';

/// Proving the photos are you.
///
/// The screen is deliberately in this order: ask for a pose, *then* open the
/// camera. Reversed, a person could take the photo first and read the
/// instruction after, and the whole point of the pose is that it was not known
/// in advance.
///
/// The copy says what this does and does not do. Overstating it would be worse
/// than not having it: a badge people over-trust is a way to get somebody hurt.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    context.verification?.refresh();
  }

  Future<void> _capture(VerificationController verification) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        // The camera, not the gallery. On a phone this opens the camera
        // directly; on a desktop browser the engine may still fall back to a
        // file dialog, which is exactly why a person reviews the result rather
        // than the app trusting it.
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
    } on Exception {
      // No camera, permission withdrawn, picker refused to open. None of them
      // is a crash — it is a photo that did not get taken.
      file = null;
    }
    if (file == null || !mounted) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    await verification.submit(bytes, _contentType(file));
  }

  /// What the picker says, or a safe guess from the name.
  ///
  /// The server sniffs the magic bytes and ignores this anyway; sending
  /// something plausible just keeps proxies from doing anything creative.
  static String _contentType(XFile file) {
    final String declared = file.mimeType ?? '';
    if (declared.startsWith('image/')) {
      return declared;
    }
    return file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final VerificationController? verification = context.verification;

    return UpScaffold(
      child: ListView(
        children: <Widget>[
          UpTopBar(
            title: s.verifyTitle,
            onBack: () => Navigator.of(context).pop(),
          ),
          if (verification == null)
            UpCard(
              child: Text(
                s.verifyNoServer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ListenableBuilder(
              listenable: verification,
              builder: (BuildContext context, Widget? _) =>
                  _Body(verification: verification, onCapture: _capture),
            ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.verification, required this.onCapture});

  final VerificationController verification;
  final Future<void> Function(VerificationController) onCapture;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final String localeCode = context.session.localeCode;
    final PoseChallenge? challenge = verification.challenge;

    if (verification.status == VerificationStatus.approved) {
      return _Result(
        icon: Icons.verified_rounded,
        colour: p.cyan,
        title: s.verifyApprovedTitle,
        body: s.verifyApprovedBody,
      );
    }
    if (verification.status == VerificationStatus.pending) {
      return _Result(
        icon: Icons.hourglass_top_rounded,
        colour: p.amber,
        title: s.verifyPendingTitle,
        body: s.verifyPendingBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (verification.status == VerificationStatus.rejected) ...<Widget>[
          UpCard(
            borderColor: p.danger,
            child: Text(
              s.verifyRejectedBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: Insets.lg),
        ],
        Text(s.verifyHeadline, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: Insets.sm),
        Text(s.verifyBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Insets.lg),

        // The honest paragraph. It is here rather than in a help page because
        // the moment somebody decides whether to trust this badge is the moment
        // they are looking at this screen.
        UpCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 18, color: p.dim),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  s.verifyHonesty,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),

        if (challenge == null)
          UpButton(
            label: s.verifyStart,
            onPressed: verification.busy
                ? null
                : () => verification.startChallenge(),
          )
        else ...<Widget>[
          // The pose, large, because it is the one thing that has to be read
          // and followed in the next few minutes.
          Container(
            padding: const EdgeInsets.all(Insets.xl),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.amber.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  s.verifyPoseLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: p.amber, letterSpacing: 0.4),
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  challenge.instructionFor(localeCode),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          UpButton(
            label: verification.busy ? s.uploading : s.verifyTakePhoto,
            onPressed:
                verification.busy ? null : () => onCapture(verification),
          ),
          const SizedBox(height: Insets.sm),
          UpButton(
            label: s.cancel,
            style: UpButtonStyle.quiet,
            onPressed: verification.busy ? null : verification.cancel,
          ),
        ],

        if (verification.lastErrorCode == 'challenge_expired') ...<Widget>[
          const SizedBox(height: Insets.md),
          Text(
            s.verifyExpired,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: p.danger),
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.colour,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xxl),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 48, color: colour),
          const SizedBox(height: Insets.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Insets.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
