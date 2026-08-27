import 'package:flutter/foundation.dart';

enum Gender { male, female, other }

enum InterestedIn { men, women, everyone }

/// The signed-in user.
///
/// Note we store [birthYear], never a computed age — age is derived at read
/// time so a stored profile cannot silently go stale, and so the backend never
/// has to run a birthday job. Milestone 2 upgrades this to a full birth date.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.birthYear,
    required this.gender,
    required this.interestedIn,
    this.bio = '',
    this.photoCount = 1,
    this.isPhotoVerified = false,
  });

  final String id;
  final String firstName;
  final int birthYear;
  final Gender gender;
  final InterestedIn interestedIn;
  final String bio;
  final int photoCount;
  final bool isPhotoVerified;

  static const int minimumAge = 18;
  static const int maxPhotos = 6;

  int ageAt(DateTime now) => now.year - birthYear;

  bool isOfAgeAt(DateTime now) => ageAt(now) >= minimumAge;

  UserProfile copyWith({
    String? firstName,
    int? birthYear,
    Gender? gender,
    InterestedIn? interestedIn,
    String? bio,
    int? photoCount,
    bool? isPhotoVerified,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      bio: bio ?? this.bio,
      photoCount: photoCount ?? this.photoCount,
      isPhotoVerified: isPhotoVerified ?? this.isPhotoVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.firstName == firstName &&
      other.birthYear == birthYear &&
      other.gender == gender &&
      other.interestedIn == interestedIn &&
      other.bio == bio &&
      other.photoCount == photoCount &&
      other.isPhotoVerified == isPhotoVerified;

  @override
  int get hashCode => Object.hash(
        id,
        firstName,
        birthYear,
        gender,
        interestedIn,
        bio,
        photoCount,
        isPhotoVerified,
      );
}
