import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/api_client.dart';
import '../../data/api/backend_config.dart';
import '../../state/app_scope.dart';
import '../../state/interaction_controller.dart';
import '../../state/live_controller.dart';
import '../../state/session_controller.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmingDelete = false;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final SessionController session = context.session;
    final InteractionController interactions = context.interactions;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[session, interactions]),
      builder: (BuildContext context, Widget? _) {
        return UpScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UpTopBar(
                title: s.settingsTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    _Section(
                      title: s.sectionApp,
                      rows: <Widget>[
                        _Row(
                          label: s.settingLanguage,
                          value: session.localeCode == 'he'
                              ? 'עברית'
                              : 'English',
                          onTap: session.toggleLocale,
                        ),
                        _Row(
                          label: s.settingAppearance,
                          value: session.themeMode == ThemeMode.dark
                              ? s.themeDark
                              : s.themeLight,
                          onTap: () => session.setThemeMode(
                            session.themeMode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark,
                          ),
                        ),
                        _Row(
                          label: s.settingLiveDuration,
                          value:
                              '${session.liveDuration.inMinutes} ${s.minutesShort}',
                          onTap: session.cycleLiveDuration,
                        ),
                      ],
                    ),
                    _Section(
                      title: s.sectionPrivacy,
                      rows: <Widget>[
                        _Row(
                          label: s.settingHideContacts,
                          value: session.hideFromContacts ? s.on : s.off,
                          onTap: () => session.setHideFromContacts(
                            !session.hideFromContacts,
                          ),
                        ),
                        _Row(label: s.privacyPolicy, onTap: () {}),
                        _Row(label: s.termsOfUse, onTap: () {}),
                      ],
                    ),
                    const _ServerSection(),
                    _Section(
                      title: s.sectionSafety,
                      rows: <Widget>[
                        _Row(
                          label: s.blockedList,
                          value: '${interactions.blockedIds.length}',
                          onTap: () {},
                        ),
                        _Row(label: s.reportAndHelp, onTap: () {}),
                      ],
                    ),
                    _Section(
                      title: s.sectionAccount,
                      rows: <Widget>[
                        _Row(
                          label: s.logOut,
                          onTap: () => _logOut(context),
                        ),
                      ],
                    ),
                    if (_confirmingDelete)
                      _DeleteConfirm(
                        title: s.deleteConfirmTitle,
                        body: s.deleteConfirmBody,
                        confirmLabel: s.deleteYes,
                        cancelLabel: s.cancel,
                        onConfirm: () => _deleteAccount(context),
                        onCancel: () =>
                            setState(() => _confirmingDelete = false),
                      )
                    else
                      UpButton(
                        label: s.deleteAccount,
                        style: UpButtonStyle.danger,
                        onPressed: () =>
                            setState(() => _confirmingDelete = true),
                      ),
                    const SizedBox(height: Insets.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logOut(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LiveController live = context.live;
    final SessionController session = context.session;
    await live.stop();
    await session.logOut();
    navigator.pushNamedAndRemoveUntil(
      Routes.splash,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LiveController live = context.live;
    final SessionController session = context.session;
    final InteractionController interactions = context.interactions;

    await live.stop();
    interactions.reset();
    await session.deleteAccount();

    navigator.pushNamedAndRemoveUntil(
      Routes.splash,
      (Route<dynamic> route) => false,
    );
  }
}

/// Where the app points, and which room it is in.
///
/// This lives in settings rather than in a hidden developer menu because in
/// Milestone 2 it is the whole difference between a demo and two phones talking
/// to each other. It disappears the day the app ships against a fixed address.
class _ServerSection extends StatefulWidget {
  const _ServerSection();

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

enum _Reachability { unknown, checking, ok, failed }

class _ServerSectionState extends State<_ServerSection> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _venue = TextEditingController();
  _Reachability _status = _Reachability.unknown;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    final BackendConfig config = context.backend;
    _url.text = config.baseUrl;
    _venue.text = config.venueCode;
  }

  @override
  void dispose() {
    _url.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final BackendConfig config = context.backend;
    setState(() => _status = _Reachability.checking);

    await config.setVenueCode(_venue.text);
    await config.setServer(baseUrl: _url.text);
    if (!mounted) {
      // Backed out of settings while the save was in flight; the controllers
      // below are already disposed.
      return;
    }
    _venue.text = config.venueCode;
    _url.text = config.baseUrl;

    if (!config.isConfigured) {
      setState(() => _status = _Reachability.unknown);
      return;
    }

    // A client of its own: the app's stack is rebuilt asynchronously when the
    // address changes, and this check should not depend on that having
    // happened yet.
    final ApiClient probe = ApiClient(config);
    final bool ok = await probe.ping();
    probe.dispose();
    if (!mounted) {
      return;
    }
    setState(() => _status = ok ? _Reachability.ok : _Reachability.failed);
  }

  String _statusLabel(AppStrings s, BackendConfig config) {
    switch (_status) {
      case _Reachability.checking:
        return s.serverStatusChecking;
      case _Reachability.ok:
        return s.serverStatusOk;
      case _Reachability.failed:
        return s.serverStatusFail;
      case _Reachability.unknown:
        return config.isConfigured ? '' : s.serverStatusMock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final UpPalette p = context.palette;
    final BackendConfig config = context.backend;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: SectionLabel(s.sectionServer)),
              Text(
                _statusLabel(s, config),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          UpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.serverUrlLabel,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: Insets.xs),
                // A URL is always LTR, whatever the interface language.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(hintText: s.serverUrlHint),
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(s.serverUrlBody,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Insets.lg),
                Text(s.venueLabel,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: Insets.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _venue,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    decoration: InputDecoration(hintText: s.venueHint),
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(s.venueBody,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Insets.md),
                UpButton(
                  label: s.serverSave,
                  style: UpButtonStyle.quiet,
                  onPressed:
                      _status == _Reachability.checking ? null : _apply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(title),
          const SizedBox(height: Insets.sm),
          UpCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap, this.value});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.touchTarget),
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return UpCard(
      borderColor: p.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Insets.xs),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: UpButton(
                  label: confirmLabel,
                  style: UpButtonStyle.danger,
                  onPressed: onConfirm,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: UpButton(
                  label: cancelLabel,
                  style: UpButtonStyle.ghost,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
