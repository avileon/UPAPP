import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Pre-prompt.
///
/// The OS dialog is one-shot: once someone denies it, the only way back is the
/// Settings app, and most people never go. So UP explains first, in its own
/// words, and only then asks. The location paragraph is here because Android
/// may demand a location permission purely to allow a BLE scan, and a dating
/// app asking for location with no explanation is a review rejection waiting to
/// happen.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;

    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Text(s.permsTitle,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Insets.xl),
          _PermissionCard(
            icon: Icons.bluetooth_rounded,
            accent: p.cyan,
            title: s.permBluetoothTitle,
            body: s.permBluetoothBody,
          ),
          const SizedBox(height: Insets.md),
          _PermissionCard(
            icon: Icons.notifications_none_rounded,
            accent: p.amber,
            title: s.permNotifTitle,
            body: s.permNotifBody,
          ),
          const SizedBox(height: Insets.xl),
          Container(
            padding: const EdgeInsetsDirectional.only(start: Insets.md),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: p.line, width: 2),
              ),
            ),
            child: Text(
              s.permLocationNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          UpButton(
            label: s.allowAndContinue,
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil(Routes.main, (Route<dynamic> r) => false),
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return UpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.surfaceHigh,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(body,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
