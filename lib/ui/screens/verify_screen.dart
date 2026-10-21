import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/l10n/error_text.dart';
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

  /// The old route — a pose selfie a person looks at. For anyone who says no
  /// to keeping a face template, and for when the face service is down.
  bool _manual = false;

  /// Shown under the live check after an attempt that did not pass.
  String? _liveMessage;

  Future<void> _runLive(VerificationController verification) async {
    final NavigatorState navigator = Navigator.of(context);
    final AppStrings s = context.strings;
    setState(() => _liveMessage = null);

    if (!verification.consent && !await verification.giveConsent()) {
      setState(() => _liveMessage = errorText(s, verification.lastErrorCode));
      return;
    }
    if (!await verification.startLive()) {
      if (mounted) {
        setState(() => _liveMessage = errorText(s, verification.lastErrorCode));
      }
      return;
    }
    final List<String> steps = verification.liveSteps ?? const <String>[];
    final List<Uint8List>? frames = await navigator.push<List<Uint8List>>(
      MaterialPageRoute<List<Uint8List>>(
        builder: (BuildContext context) => LiveCaptureScreen(steps: steps),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) {
      return;
    }
    if (frames == null || frames.length != steps.length) {
      verification.cancelLive();
      setState(() => _liveMessage = frames == null ? null : s.faceReason(null));
      return;
    }
    final VerificationStatus? result = await verification.submitFrames(frames);
    if (!mounted) {
      return;
    }
    if (result == null) {
      setState(() => _liveMessage = errorText(s, verification.lastErrorCode));
    } else if (result == VerificationStatus.rejected) {
      setState(() => _liveMessage = s.faceReason(verification.reason));
    } else {
      // Approved or pending: the photos may have just been re-checked.
      unawaited(context.session.reloadProfile());
    }
  }

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
            title: s.faceTitle,
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
              builder: (BuildContext context, Widget? _) {
                final bool decided =
                    verification.status == VerificationStatus.approved ||
                        verification.status == VerificationStatus.pending;
                if (_manual && !decided) {
                  return _Body(verification: verification, onCapture: _capture);
                }
                return _LiveBody(
                  verification: verification,
                  message: _liveMessage,
                  onStart: () => _runLive(verification),
                  onManual: () => setState(() => _manual = true),
                );
              },
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

/// The automatic face check: what it does, the consent, and the button.
class _LiveBody extends StatelessWidget {
  const _LiveBody({
    required this.verification,
    required this.message,
    required this.onStart,
    required this.onManual,
  });

  final VerificationController verification;
  final String? message;
  final VoidCallback onStart;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;

    if (verification.status == VerificationStatus.approved) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Result(
            icon: Icons.verified_rounded,
            colour: p.cyan,
            title: s.faceApproved,
            body: s.faceApprovedBody,
          ),
          if (verification.method == 'live')
            UpButton(
              label: s.deleteFace,
              style: UpButtonStyle.quiet,
              onPressed: () async {
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                await verification.deleteBiometrics();
                messenger.showSnackBar(SnackBar(content: Text(s.deleteFaceDone)));
              },
            ),
        ],
      );
    }
    if (verification.status == VerificationStatus.pending) {
      return _Result(
        icon: Icons.hourglass_top_rounded,
        colour: p.amber,
        title: s.facePending,
        body: s.facePendingBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Insets.md),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.cyan, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: p.cyan.withValues(alpha: 0.35), blurRadius: 30),
              ],
            ),
            child: Icon(Icons.face_rounded, size: 48, color: p.cyan),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          s.faceHeadline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          s.faceBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        if (!verification.consent)
          UpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.consentTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Insets.xs),
                Text(
                  s.consentBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
        if (message != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          UpCard(
            borderColor: p.danger,
            child: Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: Insets.xl),
        UpButton(
          label: verification.busy
              ? s.checkingFace
              : (verification.consent ? s.startCheck : s.consentAgree),
          icon: Icons.photo_camera_rounded,
          onPressed: verification.busy ? null : onStart,
        ),
        const SizedBox(height: Insets.sm),
        UpButton(
          label: s.manualFallback,
          style: UpButtonStyle.quiet,
          onPressed: verification.busy ? null : onManual,
        ),
      ],
    );
  }
}

/// The camera, the oval, and one instruction at a time.
///
/// Pops with one frame per step, in order, or null if the camera never came
/// up. The frames are not mirrored or edited here; the server works out which
/// way round the device holds its pictures.
class LiveCaptureScreen extends StatefulWidget {
  const LiveCaptureScreen({required this.steps, super.key});

  final List<String> steps;

  @override
  State<LiveCaptureScreen> createState() => _LiveCaptureScreenState();
}

class _LiveCaptureScreenState extends State<LiveCaptureScreen> {
  CameraController? _camera;
  String? _error;
  int _step = 0;
  int _count = 3;
  bool _shooting = false;
  final List<Uint8List> _frames = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('no camera');
      }
      final CameraDescription front = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      // A beat to find the oval before the first countdown.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _run();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.strings.cameraDenied);
      }
    }
  }

  Future<void> _run() async {
    final CameraController? camera = _camera;
    if (camera == null) {
      return;
    }
    for (int i = 0; i < widget.steps.length; i++) {
      if (!mounted) {
        return;
      }
      setState(() {
        _step = i;
        _count = 3;
      });
      for (int c = 3; c > 0; c--) {
        if (!mounted) {
          return;
        }
        setState(() => _count = c);
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
      if (!mounted) {
        return;
      }
      setState(() => _shooting = true);
      final XFile shot = await camera.takePicture();
      _frames.add(await shot.readAsBytes());
      if (mounted) {
        setState(() => _shooting = false);
      }
    }
    if (mounted) {
      Navigator.of(context).pop(List<Uint8List>.unmodifiable(_frames));
    }
  }

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    super.dispose();
  }

  String _instruction(AppStrings s, String step) => switch (step) {
        'left' => s.stepLeft,
        'right' => s.stepRight,
        _ => s.stepCenter,
      };

  IconData? _arrow(String step) => switch (step) {
        'left' => Icons.west_rounded,
        'right' => Icons.east_rounded,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final CameraController? camera = _camera;
    final String step =
        widget.steps.isEmpty ? 'center' : widget.steps[_step];
    final IconData? arrow = _arrow(step);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < widget.steps.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < _frames.length
                              ? p.cyan
                              : (i == _step ? p.amber : Colors.white24),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              _error ?? _instruction(s, step),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: Center(
                child: camera == null || !camera.value.isInitialized
                    ? (_error == null
                        ? const CircularProgressIndicator()
                        : Icon(Icons.videocam_off_rounded,
                            color: p.danger, size: 56))
                    : AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ClipOval(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: 300,
                                  height: 300 * camera.value.aspectRatio,
                                  child: CameraPreview(camera),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: OvalBorder(
                                    side: BorderSide(
                                      color: _shooting ? p.cyan : p.amber,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (arrow != null)
                              Center(
                                child: Icon(arrow,
                                    size: 96,
                                    color: Colors.white.withValues(alpha: 0.85)),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Text(
              _error != null ? '' : (_shooting ? '📸' : '$_count'),
              style: TextStyle(
                color: p.amber,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
