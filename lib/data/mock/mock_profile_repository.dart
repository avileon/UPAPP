import 'dart:typed_data';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// A plausible default so the setup screens open on something rather than an
/// empty date. Chosen once, at the top, instead of appearing inline twice.
final DateTime _defaultBirthDate = DateTime(1994, 5, 1);

class MockProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<UserProfile> save(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _profile = profile;
    return profile;
  }

  /// The mock has no storage, so it invents a key and forgets the bytes.
  ///
  /// That is not a shortcut: the mock stack exists to run the whole UI with no
  /// server, and a key that resolves to nothing is exactly the state the photo
  /// widget already has to handle — the aura placeholder.
  @override
  Future<UserProfile> addPhoto(Uint8List bytes) async {
    final UserProfile current = _profile ??
        UserProfile(
          id: 'me',
          firstName: '',
          birthDate: _defaultBirthDate,
          gender: Gender.male,
          interestedIn: InterestedIn.women,
        );
    if (current.photoKeys.length >= UserProfile.maxPhotos) {
      return current;
    }
    _profile = current.copyWith(
      photoKeys: <String>[
        ...current.photoKeys,
        'mock-${current.photoKeys.length}',
      ],
    );
    return _profile!;
  }

  @override
  Future<UserProfile> removePhoto(String key) async {
    final UserProfile current = _profile ??
        UserProfile(
          id: 'me',
          firstName: '',
          birthDate: _defaultBirthDate,
          gender: Gender.male,
          interestedIn: InterestedIn.women,
        );
    _profile = current.copyWith(
      photoKeys: current.photoKeys
          .where((String k) => k != key)
          .toList(growable: false),
    );
    return _profile!;
  }

  @override
  Future<Uint8List?> photoBytes(String key) async => null;

  void clear() => _profile = null;
}
