import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// One line saying what you are doing, right now.
///
/// The highest-value field in the app and the cheapest to fill in. A profile
/// bio is a permanent claim and gets written like one — careful, general,
/// useless. "בפינה עם ספר" is only true for the next hour, which is exactly
/// what lets it be specific, and specificity is the whole thing a stranger in
/// the same room needs in order to walk over.
///
/// Sixty characters, enforced here as well as on the server, because a counter
/// that only appears after the text is silently truncated teaches nothing.
class NoteField extends StatefulWidget {
  const NoteField({
    required this.value,
    required this.onChanged,
    required this.strings,
    this.enabled = true,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final AppStrings strings;
  final bool enabled;

  static const int maxLength = 60;

  @override
  State<NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<NoteField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(NoteField old) {
    super.didUpdateWidget(old);
    // Only when it changed elsewhere — assigning on every rebuild would move
    // the caret to the end while somebody is typing in the middle.
    if (widget.value != _controller.text && widget.value != old.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;

    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLength: NoteField.maxLength,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.strings.noteLabel,
        hintText: widget.strings.noteHint,
        // The counter is noise until it matters. Flutter shows "0/60" from the
        // first frame otherwise, which reads as a form to fill in rather than
        // an optional line.
        counterText: '',
        prefixIcon: Icon(Icons.bolt_rounded, size: 18, color: p.dim),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.amber),
        ),
      ),
    );
  }
}
