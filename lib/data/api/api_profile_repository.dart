import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'api_client.dart';
import 'api_mappers.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<UserProfile?> load() async {
    try {
      return ApiMappers.profile(await _client.get('/me/profile'));
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    final Map<String, dynamic> result = await _client.put(
      '/me/profile',
      <String, dynamic>{
        'firstName': profile.firstName,
        // A full date, which the server re-checks against its own clock. If it
        // comes back `under_minimum_age` the save fails loudly rather than
        // saving a profile the server would not accept.
        'birthDate': profile.birthDateIso,
        'gender': ApiMappers.genderKey(profile.gender),
        'interestedIn': ApiMappers.interestedInKey(profile.interestedIn),
        'bio': profile.bio,
      },
    );
    return ApiMappers.profile(result) ?? profile;
  }

  @override
  Future<UserProfile> addPhoto() async {
    final Map<String, dynamic> result =
        await _client.post('/media/upload-url');
    final int photos = (result['photos'] as List?)?.length ?? 1;
    // Milestone 2's endpoint reserves a key and returns no upload URL — there
    // is no object storage behind it yet. The count is real; the picture is
    // still the generated placeholder.
    final UserProfile? current = await load();
    return (current ?? _placeholder()).copyWith(
      photoCount: photos < 1 ? 1 : photos,
    );
  }

  UserProfile _placeholder() => UserProfile(
        id: '',
        firstName: '',
        birthDate: DateTime(1994, 5, 1),
        gender: Gender.male,
        interestedIn: InterestedIn.women,
      );
}
