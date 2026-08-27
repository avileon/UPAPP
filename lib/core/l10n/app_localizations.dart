import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Thin Localizations wrapper around [AppStrings].
///
/// Deliberately hand-rolled instead of generated ARB files: Milestone 1 has one
/// author and two locales, and this keeps the copy readable in a single file.
/// Swapping to `flutter gen-l10n` later only changes this class — every call
/// site uses `context.strings`.
class AppLocalizations {
  const AppLocalizations(this.strings);

  final AppStrings strings;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('he'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? result =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'he' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(AppStrings.of(locale.languageCode));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension StringsAccess on BuildContext {
  AppStrings get strings => AppLocalizations.of(this).strings;

  /// True when the current locale lays out right-to-left.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
