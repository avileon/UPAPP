import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData dark() => _build(UpPalette.dark, Brightness.dark);
  static ThemeData light() => _build(UpPalette.light, Brightness.light);

  static ThemeData _build(UpPalette p, Brightness brightness) {
    final TextTheme text = AppTypography.textTheme(
      foreground: p.foreground,
      muted: p.muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      // Built from a seed and then overridden role by role: this keeps the
      // scheme valid across Flutter versions without pinning every slot.
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.amber,
        brightness: brightness,
      ).copyWith(
        primary: p.amber,
        onPrimary: p.onAmber,
        secondary: p.cyan,
        onSecondary: p.onCyan,
        error: p.danger,
        onError: p.onAmber,
        surface: p.surface,
        onSurface: p.foreground,
        outline: p.line,
      ),
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: p.foreground, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: text.bodyLarge?.copyWith(color: p.dim),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.lg,
        ),
        border: _fieldBorder(p.line),
        enabledBorder: _fieldBorder(p.line),
        focusedBorder: _fieldBorder(p.amber),
        errorBorder: _fieldBorder(p.danger),
        focusedErrorBorder: _fieldBorder(p.danger),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: text.labelMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.lg),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.amber),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected) ? p.amber : p.surface;
        }),
        checkColor: WidgetStatePropertyAll<Color>(p.onAmber),
        side: BorderSide(color: p.line, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: color),
      );
}
