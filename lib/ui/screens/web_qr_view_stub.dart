import 'package:flutter/widgets.dart';

/// Not a browser: the native scanner is used instead.
bool get webQrSupported => false;

class WebQrView extends StatelessWidget {
  const WebQrView({
    super.key,
    required this.onCode,
    required this.startingText,
    required this.stuckText,
    required this.retryText,
  });

  final void Function(String raw) onCode;
  final String startingText;
  final String stuckText;
  final String retryText;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
