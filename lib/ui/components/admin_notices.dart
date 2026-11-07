import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../../state/verification_controller.dart';
import '../navigation/routes.dart';
import 'confetti.dart';

/// "You are approved", inside the app.
///
/// Push only reaches people who allowed it, and many never do. So a decision
/// the operator makes also waits on the server as a notice, and this asks for
/// it whenever the app is open: on start, on coming back to the foreground,
/// and every so often while it stays open. Shown once, then marked seen.
class AdminNotices extends StatefulWidget {
  const AdminNotices({
    required this.navigator,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<AdminNotices> createState() => _AdminNoticesState();
}

class _AdminNoticesState extends State<AdminNotices>
    with WidgetsBindingObserver {
  static const Duration _every = Duration(seconds: 45);

  Timer? _timer;
  AdminNotice? _current;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_every, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking || _current != null) {
      return;
    }
    final VerificationController? verification = context.verification;
    if (verification == null || !context.session.isSignedIn) {
      return;
    }
    _checking = true;
    try {
      final List<AdminNotice> notices = await verification.unseenNotices();
      if (mounted && notices.isNotEmpty && _current == null) {
        setState(() => _current = notices.last);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _close({bool retry = false}) async {
    final AdminNotice? notice = _current;
    final VerificationController? verification = context.verification;
    setState(() => _current = null);
    if (notice != null && verification != null) {
      await verification.markNoticeSeen(notice.id);
    }
    if (retry) {
      await widget.navigator.currentState?.pushNamed(Routes.verify);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminNotice? notice = _current;
    return Stack(
      children: <Widget>[
        widget.child,
        if (notice != null)
          Positioned.fill(
            child: _NoticeCard(
              key: ValueKey<String>(notice.id),
              approved: notice.approved,
              onClose: () => _close(),
              onRetry: () => _close(retry: true),
            ),
          ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.approved,
    required this.onClose,
    required this.onRetry,
    super.key,
  });

  final bool approved;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final Color accent = approved ? p.ok : p.amber;
    final Color onAccent = approved ? p.background : p.onAmber;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.7)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.screen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          approved
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          size: 72,
                          color: accent,
                        ),
                        const SizedBox(height: Insets.lg),
                        Text(
                          approved ? s.noticeApprovedTitle : s.noticeRejectedTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          approved ? s.noticeApprovedBody : s.noticeRejectedBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: Insets.xl),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: onAccent,
                              padding: const EdgeInsets.symmetric(
                                vertical: Insets.lg,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: approved ? onClose : onRetry,
                            child: Text(
                              approved ? s.noticeApprovedAction : s.noticeRetryAction,
                            ),
                          ),
                        ),
                        if (!approved)
                          TextButton(
                            onPressed: onClose,
                            child: Text(s.laterAction),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (approved) const IgnorePointer(child: ConfettiBurst(particles: 160)),
        ],
      ),
    );
  }
}
