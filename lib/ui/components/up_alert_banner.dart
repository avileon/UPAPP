import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// What one arriving message looks like to the banner.
///
/// Deliberately not a [MatchThread]: the banner has no business knowing what a
/// match is, and passing it one would make it impossible to reuse the same
/// strip for the other things worth interrupting for later — a new match, a
/// venue emptying out.
@immutable
class UpAlert {
  const UpAlert({
    required this.id,
    required this.title,
    required this.body,
    this.avatar,
    this.onOpen,
  });

  /// Distinguishes one alert from the next. A second alert with the same id
  /// replaces the first rather than queueing behind it, so ten messages from
  /// the same person are one banner, not ten.
  final String id;
  final String title;
  final String body;
  final Widget? avatar;
  final VoidCallback? onOpen;
}

/// A strip that drops in from the top, names the person, and gets out.
///
/// The badge on the tab bar was the whole answer before this, and a badge can
/// only say *something*. It cannot say who, it cannot be seen from a tab you
/// are not looking at without looking down at the bar, and after a day of
/// being permanently lit it stops being read at all. This says the name and
/// the first line, and one tap goes straight there.
///
/// It is not a [SnackBar]: those sit at the bottom, under the thumb and under
/// the tab bar this exists to compensate for, and Material's queueing would
/// play a backlog of five stale banners one after another.
class UpAlertBanner extends StatefulWidget {
  const UpAlertBanner({
    required this.alert,
    required this.onDismiss,
    this.duration = const Duration(seconds: 5),
    super.key,
  });

  final UpAlert? alert;
  final VoidCallback onDismiss;
  final Duration duration;

  @override
  State<UpAlertBanner> createState() => _UpAlertBannerState();
}

class _UpAlertBannerState extends State<UpAlertBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(UpAlertBanner old) {
    super.didUpdateWidget(old);
    if (widget.alert?.id != old.alert?.id) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.alert == null) {
      return;
    }
    _timer = Timer(widget.duration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpAlert? alert = widget.alert;
    return IgnorePointer(
      // Nothing here may sit between a finger and the app when there is no
      // banner: an invisible strip that eats taps at the top of every screen
      // is the classic way this pattern goes wrong.
      ignoring: alert == null,
      child: AnimatedSlide(
        offset: alert == null ? const Offset(0, -1.2) : Offset.zero,
        duration: Motion.normal,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: alert == null ? 0 : 1,
          duration: Motion.fast,
          child: alert == null
              ? const SizedBox.shrink()
              : _Strip(alert: alert, onDismiss: widget.onDismiss),
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.alert, required this.onDismiss});

  final UpAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.sm,
          Insets.md,
          0,
        ),
        child: Dismissible(
          key: ValueKey<String>(alert.id),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: Material(
            color: p.surfaceHigh,
            borderRadius: BorderRadius.circular(Radii.md),
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.45),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () {
                onDismiss();
                alert.onOpen?.call();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: p.amber.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.md,
                ),
                child: Row(
                  children: <Widget>[
                    if (alert.avatar != null) ...<Widget>[
                      alert.avatar!,
                      const SizedBox(width: Insets.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            alert.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: p.amber,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
