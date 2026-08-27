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
  int _birthYear = 1994;
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
    _birthYear = draft.birthYear;
    _gender = draft.gender;
    _interestedIn = draft.interestedIn;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  int get _age => DateTime.now().year - _birthYear;
  bool get _isOfAge => _age >= UserProfile.minimumAge;
  bool get _canContinue => _name.text.trim().isNotEmpty && _isOfAge;

  Future<void> _save() async {
    final UserProfile updated = context.session.draftProfile.copyWith(
      firstName: _name.text.trim(),
      birthYear: _birthYear,
      gender: _gender,
      interestedIn: _interestedIn,
      bio: _bio.text.trim(),
    );
    await context.session.saveProfile(updated);
    if (!mounted) {
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
                SectionLabel('${s.birthYear} · ${s.ageYears(_age)}'),
                const SizedBox(height: Insets.xs + 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    initialValue: '$_birthYear',
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (String value) {
                      final int? year = int.tryParse(value);
                      if (year != null) {
                        setState(() => _birthYear = year);
                      }
                    },
                  ),
                ),
                if (!_isOfAge) ...<Widget>[
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
