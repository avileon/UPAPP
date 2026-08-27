import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  /// Maps to `GET /me/profile`.
  Future<UserProfile?> load();

  /// Maps to `PUT /me/profile`.
  Future<UserProfile> save(UserProfile profile);

  /// Maps to `POST /media/upload-url` followed by a direct upload to object
  /// storage. Milestone 1 just increments a counter.
  Future<UserProfile> addPhoto();
}
