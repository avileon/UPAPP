import 'dart:typed_data';

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
  Future<UserProfile> addPhoto(Uint8List bytes) async {
    // The declared type is a courtesy; the server reads the magic bytes and
    // decides for itself.
    final Map<String, dynamic> result =
        await _client.postBytes('/media/photo', bytes, 'image/jpeg');
    return _withKeys(result['photos']);
  }

  @override
  Future<UserProfile> removePhoto(String key) async {
    final Map<String, dynamic> result = await _client.delete('/media/$key');
    return _withKeys(result['photos']);
  }

  @override
  Future<Uint8List?> photoBytes(String key) =>
      _client.getBytes('/media/$key');

  /// The profile as the server now has it, with the keys it just returned.
  ///
  /// Re-reading the profile rather than patching the local copy: the upload
  /// response is authoritative about the photo list and about nothing else,
  /// and a stale name or bio sitting next to a fresh photo list is the kind of
  /// inconsistency that is very hard to see and very easy to ship.
  Future<UserProfile> _withKeys(Object? photos) async {
    final List<String> keys = photos is List
        ? photos.whereType<String>().toList(growable: false)
        : const <String>[];
    final UserProfile? current = await load();
    return (current ?? _placeholder()).copyWith(photoKeys: keys);
  }

  UserProfile _placeholder() => UserProfile(
        id: '',
        firstName: '',
        birthDate: DateTime(1994, 5, 1),
        gender: Gender.male,
        interestedIn: InterestedIn.women,
      );
}
