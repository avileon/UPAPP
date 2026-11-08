import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/dating_strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/user_profile.dart';
import '../../state/app_scope.dart';
import '../components/common.dart';
import '../components/up_buttons.dart';
import '../components/up_chip.dart';
import '../components/up_scaffold.dart';
import '../navigation/routes.dart';

/// The smallest profile that still makes a person recognisable across a room.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  /// One box, typed: "15/03/1994". Slashes appear on their own.
  final TextEditingController _date = TextEditingController();
  Gender _gender = Gender.male;
  InterestedIn _interestedIn = InterestedIn.women;
  bool _loadedDraft = false;

  /// Set once the person picks "interested in" themselves; from then on
  /// choosing a gender no longer changes it for them.
  bool _interestTouched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets are only safe to read from here, not initState.
    if (_loadedDraft) {
      return;
    }
    _loadedDraft = true;
    final UserProfile draft = context.session.draftProfile;
    _name.text = draft.firstName;
    _bio.text = draft.bio;
    // A new profile starts with an empty date rather than a placeholder
    // birthday that has to be deleted first.
    if (draft.firstName.isNotEmpty) {
      _date.text = _BirthDateFormatter.format(draft.birthDate);
      _interestTouched = true;
    }
    _gender = draft.gender;
    _interestedIn = draft.interestedIn;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _date.dispose();
    super.dispose();
  }

  /// The typed date, or null while it is still nonsense.
  ///
  /// `DateTime(2007, 2, 30)` silently becomes the 2nd of March, so an
  /// out-of-range day would quietly turn into a different birthday. Round-trip
  /// the parts and reject anything that did not survive.
  DateTime? get _birthDate {
    final List<String> parts = _date.text.split('/');
    if (parts.length != 3) {
      return null;
    }
    final int? day = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? year = parts[2].length == 4 ? int.tryParse(parts[2]) : null;
    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final DateTime date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  int? get _age {
    final DateTime? date = _birthDate;
    if (date == null) {
      return null;
    }
    return UserProfile(
      id: 'draft',
      firstName: '',
      birthDate: date,
      gender: _gender,
      interestedIn: _interestedIn,
    ).ageAt(DateTime.now());
  }

  /// Missing and under-age are shown differently: an empty field is not a
  /// rejection, and telling someone they are too young because they have not
  /// finished typing is the fastest way to lose them.
  bool get _isOfAge => (_age ?? 0) >= UserProfile.minimumAge;
  bool get _showAgeGate => _birthDate != null && !_isOfAge;
  bool get _canContinue =>
      _name.text.trim().isNotEmpty && _birthDate != null && _isOfAge;

  /// A man looks for women and a woman for men, unless they say otherwise.
  void _pickGender(Gender gender) {
    setState(() {
      _gender = gender;
      if (_interestTouched) {
        return;
      }
      _interestedIn = switch (gender) {
        Gender.male => InterestedIn.women,
        Gender.female => InterestedIn.men,
        _ => _interestedIn,
      };
    });
  }

  void _pickInterest(InterestedIn value) {
    setState(() {
      _interestTouched = true;
      _interestedIn = value;
    });
  }

  Future<void> _save() async {
    final UserProfile updated = context.session.draftProfile.copyWith(
      firstName: _name.text.trim(),
      birthDate: _birthDate!,
      gender: _gender,
      interestedIn: _interestedIn,
      bio: _bio.text.trim(),
    );
    final bool saved = await context.session.saveProfile(updated);
    if (!mounted) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.session.errorMessage(context.strings))),
      );
      return;
    }
    await Navigator.of(context).pushNamed(Routes.photosSetup);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;

    return UpScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UpTopBar(onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              children: <Widget>[
                Text(s.profileTitle,
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: Insets.xl),
                SectionLabel(s.firstName),
                const SizedBox(height: Insets.xs + 2),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: s.localeCode == 'he' ? 'אבי' : 'Avi',
                  ),
                ),
                const SizedBox(height: Insets.lg),
                SectionLabel(
                  _age == null
                      ? s.birthDate
                      : '${s.birthDate} · ${s.ageYears(_age!)}',
                ),
                const SizedBox(height: Insets.xs + 2),
                // Typed, not picked: "15031994" becomes 15/03/1994. Always
                // day / month / year, LTR, in both languages.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _date,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: <TextInputFormatter>[
                      _BirthDateFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(hintText: s.birthDateTypeHint),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_showAgeGate) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Text(
                    s.errorUnderAge,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: Insets.lg),
                SectionLabel(s.iAm),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    UpChip(
                      label: s.genderMale,
                      selected: _gender == Gender.male,
                      onSelected: () => _pickGender(Gender.male),
                    ),
                    UpChip(
                      label: s.genderFemale,
                      selected: _gender == Gender.female,
                      onSelected: () => _pickGender(Gender.female),
                    ),
                    UpChip(
                      label: s.genderOther,
                      selected: _gender == Gender.other,
                      onSelected: () => _pickGender(Gender.other),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                SectionLabel(s.interestedIn),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    UpChip(
                      label: s.prefMen,
                      selected: _interestedIn == InterestedIn.men,
                      onSelected: () => _pickInterest(InterestedIn.men),
                    ),
                    UpChip(
                      label: s.prefWomen,
                      selected: _interestedIn == InterestedIn.women,
                      onSelected: () => _pickInterest(InterestedIn.women),
                    ),
                    UpChip(
                      label: s.prefEveryone,
                      selected: _interestedIn == InterestedIn.everyone,
                      onSelected: () =>
                          _pickInterest(InterestedIn.everyone),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                SectionLabel(s.bioLabel),
                const SizedBox(height: Insets.xs + 2),
                TextField(
                  controller: _bio,
                  maxLength: 120,
                  decoration: InputDecoration(
                    hintText: s.bioHint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Insets.xl),
                // At the end of the form, where the scroll ends — not pinned
                // under the keyboard where nobody found it.
                if (!_canContinue && !_showAgeGate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Text(
                      s.fillNameAndDate,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                UpButton(
                  label: s.saveAndContinue,
                  icon: Icons.check_rounded,
                  onPressed: _canContinue ? _save : null,
                ),
                const SizedBox(height: Insets.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Digits in, "DD/MM/YYYY" out — the slashes are typed for you.
class _BirthDateFormatter extends TextInputFormatter {
  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    // While deleting, no trailing slash is added back — so backspace on
    // "15/" leaves "15" instead of getting stuck.
    final bool deleting = newValue.text.length < oldValue.text.length;
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      out.write(digits[i]);
      final bool more = i < digits.length - 1;
      if ((i == 1 || i == 3) && (more || !deleting)) {
        out.write('/');
      }
    }
    final String text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
