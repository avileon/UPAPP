import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
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
