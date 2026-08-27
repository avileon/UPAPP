import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

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

  @override
  Future<UserProfile> addPhoto() async {
    final UserProfile current = _profile ??
        const UserProfile(
          id: 'me',
          firstName: '',
          birthYear: 1994,
          gender: Gender.male,
          interestedIn: InterestedIn.women,
        );
    final int next =
        (current.photoCount + 1).clamp(1, UserProfile.maxPhotos).toInt();
    _profile = current.copyWith(photoCount: next);
    return _profile!;
  }

  void clear() => _profile = null;
}
