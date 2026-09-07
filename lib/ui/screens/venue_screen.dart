import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/backend_config.dart';
import '../../domain/entities/live_intent.dart';
import '../../domain/repositories/presence_repository.dart';
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
    final AppStrings s = context.strings;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await context.backend.setVenueCode(_code.text);
    if (!mounted) {
      return;
    }
    final String saved = context.backend.venueCode;
    setState(() => _code.text = saved);
    if (saved.isEmpty) {
      return;
    }
    // Saying "saved" alone is what made this screen feel broken: the code was
    // stored and nothing else happened, because joining a room is what Live
    // does. Say which of the two just happened.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.live.isLive
              ? s.venueLiveJoined(saved)
              : '${s.venueSavedIn(saved)} ${s.venueThenGoLive}',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final BackendConfig config = context.backend;

    return UpScaffold(
      child: ListenableBuilder(
        // The live controller too: the join state below is a fact about the
        // session, and going Live from another screen must repaint it.
        listenable: Listenable.merge(<Listenable>[config, context.live]),
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
                // The standing answer to "am I in this room?", on the screen
                // that hands the room out. A QR that someone is about to share
                // while not Live themselves is the exact situation worth
                // catching here.
                _JoinState(code: code),
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
              // The other half of joining a room. Typing a code works when
              // somebody told you the code; a person standing in a bar has
              // nothing to type, and until this existed the answer to "where
              // is everyone" was "you had to already know".
              _RoomsNearby(
                intent: context.live.isLive
                    ? context.live.intent
                    : context.session.liveIntent,
                onPick: (String picked) {
                  setState(() => _code.text = picked);
                  unawaited(_save());
                },
              ),
              const SizedBox(height: Insets.xl),
            ],
          );
        },
      ),
    );
  }

  /// The link a QR encodes, or null when there is nothing to share yet.
  ///
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

/// Whether this phone is actually in the room shown above.
class _JoinState extends StatelessWidget {
  const _JoinState({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final bool joined = context.live.isLive && context.live.room.code == code;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          joined ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
          size: 18,
          color: joined ? p.cyan : p.dim,
        ),
        const SizedBox(width: Insets.xs + 2),
        Flexible(
          child: Text(
            joined ? s.venueLiveJoined(code) : s.venueThenGoLive,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: joined ? p.cyan : null,
                ),
          ),
        ),
      ],
    );
  }
}


/// Rooms that already have people in them, for the intent you are about to use.
///
/// Loaded once when the screen opens rather than polled: this is a list you
/// glance at and tap, and a list that reshuffles under a finger is worse than
/// one that is a minute stale. Counts only — a room key is a label people
/// agreed on, and a name attached to one would turn "who is in this bar" into
/// a question this app answers, which it must never be.
class _RoomsNearby extends StatefulWidget {
  const _RoomsNearby({required this.intent, required this.onPick});

  final LiveIntent intent;
  final ValueChanged<String> onPick;

  @override
  State<_RoomsNearby> createState() => _RoomsNearbyState();
}

class _RoomsNearbyState extends State<_RoomsNearby> {
  List<RoomSummary>? _rooms;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(_RoomsNearby old) {
    super.didUpdateWidget(old);
    if (widget.intent != old.intent) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final List<RoomSummary> rooms = await context.live.rooms(widget.intent);
    if (mounted) {
      setState(() => _rooms = rooms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final List<RoomSummary>? rooms = _rooms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: SectionLabel(s.roomsTitle)),
            IconButton(
              onPressed: _load,
              icon: Icon(Icons.refresh_rounded, size: 18, color: p.dim),
              tooltip: s.roomsTitle,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        if (rooms == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.md),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (rooms.isEmpty)
          UpCard(
            child: Text(
              s.roomsEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final RoomSummary room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: UpCard(
                onTap: () => widget.onPick(room.code),
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.meeting_room_rounded, size: 18, color: p.cyan),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          room.code,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(letterSpacing: 2),
                        ),
                      ),
                    ),
                    Text(
                      '${room.people} ${s.roomsBusy}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: p.muted),
                    ),
                    const SizedBox(width: Insets.xs),
                    Icon(Icons.chevron_right_rounded, size: 18, color: p.dim),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
