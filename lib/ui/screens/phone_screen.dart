import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_scope.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  bool get _isValid => _controller.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    await context.session.requestOtp(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    await Navigator.of(context).pushNamed(Routes.otp);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UpTopBar(onBack: () => Navigator.of(context).pop()),
          Text(s.phoneTitle,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Insets.sm),
          Text(s.phoneBody, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Insets.xxl),
          // The number itself is always LTR, whatever the interface language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[\d\-\+ ]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(hintText: s.phoneHint),
            ),
          ),
          const Spacer(),
          UpButton(
            label: s.sendCode,
            onPressed: _isValid && !_sending ? _submit : null,
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}
