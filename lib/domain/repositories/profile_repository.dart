import 'dart:typed_data';

import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  /// Maps to `GET /me/profile`.
  Future<UserProfile?> load();

  /// Maps to `PUT /me/profile`.
  Future<UserProfile> save(UserProfile profile);

  /// Maps to `POST /media/photo`. The body is the image itself.
  Future<UserProfile> addPhoto(Uint8List bytes);

  /// Maps to `DELETE /media/:key`.
  Future<UserProfile> removePhoto(String key);

  /// Fetches one photo's bytes, or null when it is gone or unreachable.
  ///
  /// On this interface rather than on a widget because it needs the caller's
  /// token: photos are not public URLs, and the whole point of that decision
  /// would be lost if the UI could reach them any other way.
  Future<Uint8List?> photoBytes(String key);
}
