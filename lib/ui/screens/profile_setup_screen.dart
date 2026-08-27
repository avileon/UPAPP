import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
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
  final TextEditingController _day = TextEditingController();
  final TextEditingController _month = TextEditingController();
  final TextEditingController _year = TextEditingController();
  Gender _gender = Gender.male;
  InterestedIn _interestedIn = InterestedIn.women;
  bool _loadedDraft = false;

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
    _day.text = '${draft.birthDate.day}';
    _month.text = '${draft.birthDate.month}';
    _year.text = '${draft.birthDate.year}';
    _gender = draft.gender;
    _interestedIn = draft.interestedIn;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  /// The typed date, or null while it is still nonsense.
  ///
  /// `DateTime(2007, 2, 30)` silently becomes the 2nd of March, so an
  /// out-of-range day would quietly turn into a different birthday. Round-trip
  /// the parts and reject anything that did not survive.
  DateTime? get _birthDate {
    final int? day = int.tryParse(_day.text);
    final int? month = int.tryParse(_month.text);
    final int? year = int.tryParse(_year.text);
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
                // Always day / month / year in that order, LTR, in both
                // languages: a date typed into boxes is read positionally, and
                // mirroring it in Hebrew would silently swap day and month.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _DatePart(
                          controller: _day,
                          hint: s.birthDayHint,
                          maxLength: 2,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: _DatePart(
                          controller: _month,
                          hint: s.birthMonthHint,
                          maxLength: 2,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        flex: 2,
                        child: _DatePart(
                          controller: _year,
                          hint: s.birthYearHint,
                          maxLength: 4,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAgeGate) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Text(
                    s.ageGate,
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
                      onSelected: () =>
                          setState(() => _gender = Gender.male),
                    ),
                    UpChip(
                      label: s.genderFemale,
                      selected: _gender == Gender.female,
                      onSelected: () =>
                          setState(() => _gender = Gender.female),
                    ),
                    UpChip(
                      label: s.genderOther,
                      selected: _gender == Gender.other,
                      onSelected: () =>
                          setState(() => _gender = Gender.other),
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
                      onSelected: () =>
                          setState(() => _interestedIn = InterestedIn.men),
                    ),
                    UpChip(
                      label: s.prefWomen,
                      selected: _interestedIn == InterestedIn.women,
                      onSelected: () =>
                          setState(() => _interestedIn = InterestedIn.women),
                    ),
                    UpChip(
                      label: s.prefEveryone,
                      selected: _interestedIn == InterestedIn.everyone,
                      onSelected: () => setState(
                        () => _interestedIn = InterestedIn.everyone,
                      ),
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
              ],
            ),
          ),
          UpButton(
            label: s.cont,
            onPressed: _canContinue ? _save : null,
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}

/// One box of a date. Digits only, centred, and capped at its own width.
class _DatePart extends StatelessWidget {
  const _DatePart({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLength,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(hintText: hint, counterText: ''),
      onChanged: (_) => onChanged(),
    );
  }
}
