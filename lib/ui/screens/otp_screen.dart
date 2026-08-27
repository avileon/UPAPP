import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  static const int codeLength = 4;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final List<TextEditingController> _controllers = List<
      TextEditingController>.generate(
    OtpScreen.codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _nodes =
      List<FocusNode>.generate(OtpScreen.codeLength, (_) => FocusNode());

  bool _verifying = false;

  String get _code => _controllers.map((TextEditingController c) => c.text).join();
  bool get _isComplete => _code.length == OtpScreen.codeLength;

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    for (final FocusNode n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onDigit(int index, String value) {
    if (value.isNotEmpty && index < OtpScreen.codeLength - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final bool ok = await context.session.verifyOtp(_code);
    if (!mounted) {
      return;
    }
    setState(() => _verifying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.session.errorMessage(context.strings))),
      );
      return;
    }
    // A returning user already has a profile; sending them back through setup
    // would ask them to retype what the server just handed back.
    await Navigator.of(context).pushNamed(
      context.session.profile?.firstName.isNotEmpty ?? false
          ? Routes.main
          : Routes.profileSetup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final String phone = context.session.phoneNumber;

    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UpTopBar(onBack: () => Navigator.of(context).pop()),
          Text(s.otpTitle, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Insets.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Insets.xs,
            children: <Widget>[
              Text(s.otpSentTo,
                  style: Theme.of(context).textTheme.bodyMedium),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  phone.isEmpty ? s.phoneHint : phone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.foreground,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(OtpScreen.codeLength, (int i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 1),
                  child: SizedBox(
                    width: 54,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _nodes[i],
                      autofocus: i == 0,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 24),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding:
                            EdgeInsets.symmetric(vertical: Insets.lg),
                      ),
                      onChanged: (String v) => _onDigit(i, v),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: Insets.md),
          Center(
            child: Builder(
              builder: (BuildContext context) {
                // While the server runs on the mock SMS provider it hands the
                // code straight back, so the screen shows it. The moment a real
                // provider is configured the server stops sending it and this
                // falls back to the demo hint on its own.
                final String? dev = context.session.devCode;
                if (dev == null || dev.isEmpty) {
                  return Text(
                    s.otpDemoHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Text(
                  '${s.devCodeLabel}: $dev',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.foreground,
                      ),
                );
              },
            ),
          ),
          const Spacer(),
          UpButton(
            label: s.verify,
            onPressed: _isComplete && !_verifying ? _verify : null,
          ),
          UpButton(
            label: s.resend,
            style: UpButtonStyle.quiet,
            onPressed: () {},
          ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    );
  }
}
