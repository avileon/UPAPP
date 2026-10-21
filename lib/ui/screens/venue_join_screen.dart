import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/l10n/error_text.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/api_client.dart';
import '../../data/api/venue_api.dart';
import '../../data/location/location_service.dart';
import '../../domain/entities/geo_fix.dart';
import '../../state/app_scope.dart';
import '../../state/live_controller.dart';
import '../../state/session_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// Joining a registered place: its name, then one location check, then in.
///
/// Opened after a scan inside the app, or straight from the sticker's link
/// (`/?venue=CODE`). The QR says *which* place; the phone's location says you
/// are actually in it. One hour per scan.
class VenueJoinScreen extends StatefulWidget {
  const VenueJoinScreen({required this.code, super.key});

  final String code;

  @override
  State<VenueJoinScreen> createState() => _VenueJoinScreenState();
}

enum _Phase { loading, ready, locating, joining }

class _VenueJoinScreenState extends State<VenueJoinScreen> {
  _Phase _phase = _Phase.loading;
  VenueInfo? _venue;
  bool _unknown = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _lookup();
  }

  Future<void> _lookup() async {
    // After the first frame: this starts from didChangeDependencies.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    final VenueApi? api = context.venues;
    if (api == null) {
      // Mock stack: no server, so pretend the code is the name.
      setState(() {
        _venue = VenueInfo(code: widget.code, name: widget.code, sessionMinutes: 60);
        _phase = _Phase.ready;
      });
      return;
    }
    try {
      final VenueInfo? venue = await api.lookup(widget.code);
      if (!mounted) {
        return;
      }
      setState(() {
        _venue = venue;
        _unknown = venue == null;
        _phase = _Phase.ready;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = errorText(context.strings, error.code);
        _phase = _Phase.ready;
      });
    }
  }

  Future<void> _join() async {
    final LiveController live = context.live;
    final SessionController session = context.session;
    final LocationService location = context.location;
    final NavigatorState navigator = Navigator.of(context);
    final AppStrings s = context.strings;
    final VenueInfo? venue = _venue;
    if (venue == null) {
      return;
    }

    setState(() {
      _error = null;
      _phase = _Phase.locating;
    });
    GeoFix fix;
    try {
      fix = await location.currentFix();
    } on LocationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = errorText(s, error.code);
        _phase = _Phase.ready;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _phase = _Phase.joining);

    // A new visit: anyone hidden last time is visible again.
    context.interactions.forgetHidden();
    if (live.isLive) {
      await live.stop();
    }
    await live.start(
      const Duration(hours: 1),
      intent: session.liveIntent,
      note: session.liveNote,
      venue: venue.code,
      fix: fix,
    );
    if (!mounted) {
      return;
    }
    final String? code = live.lastErrorCode;
    if (code == 'verification_required') {
      setState(() => _phase = _Phase.ready);
      await navigator.pushNamed(Routes.verify);
      return;
    }
    if (code != null) {
      setState(() {
        _error = errorText(s, code);
        _phase = _Phase.ready;
      });
      return;
    }
    // In. The pending code from the link has done its job.
    await context.backend.setVenueCode('');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final VenueInfo? venue = _venue;
    final bool busy = _phase == _Phase.locating || _phase == _Phase.joining;

    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UpTopBar(onBack: () => Navigator.of(context).pop(false)),
          const Spacer(),
          Icon(Icons.storefront_rounded, size: 56, color: p.cyan),
          const SizedBox(height: Insets.lg),
          if (_phase == _Phase.loading)
            const Center(child: CircularProgressIndicator())
          else if (_unknown)
            Text(
              s.joinUnknown,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            )
          else if (venue != null) ...<Widget>[
            Text(
              venue.name,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: Insets.md),
            Text(
              s.joinBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              s.joinHour(venue.sessionMinutes),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: p.cyan, fontWeight: FontWeight.w600),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            UpCard(
              borderColor: p.danger,
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const Spacer(),
          if (venue != null && !_unknown)
            UpButton(
              label: switch (_phase) {
                _Phase.locating => s.locating,
                _Phase.joining => s.joining,
                _ => s.joinButton,
              },
              icon: Icons.my_location_rounded,
              onPressed: busy ? null : _join,
            ),
          const SizedBox(height: Insets.sm),
          UpButton(
            label: s.cancel,
            style: UpButtonStyle.quiet,
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}
