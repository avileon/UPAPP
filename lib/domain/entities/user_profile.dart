import 'package:flutter/foundation.dart';

enum Gender { male, female, other }

enum InterestedIn { men, women, everyone }

/// The signed-in user.
///
/// We store [birthDate], never a computed age — age is derived at read time so
/// a stored profile cannot silently go stale, and so the backend never has to
/// run a birthday job.
///
/// A full date rather than a year, and that is a safety decision rather than a
/// cosmetic one: a year alone cannot answer "is this person 18 today", and an
/// age gate that has to round is an age gate that lets someone through. The
/// server re-derives the age from this date with its own clock and refuses the
/// profile if it comes out under eighteen — the client's opinion is a
/// courtesy, not the enforcement.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    this.bio = '',
    this.photoCount = 1,
    this.isPhotoVerified = false,
  });

  final String id;
  final String firstName;
  final DateTime birthDate;
  final Gender gender;
  final InterestedIn interestedIn;
  final String bio;
  final int photoCount;
  final bool isPhotoVerified;

  static const int minimumAge = 18;
  static const int maxPhotos = 6;

  int ageAt(DateTime now) {
    int age = now.year - birthDate.year;
    final bool birthdayPassed = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!birthdayPassed) {
      age -= 1;
    }
    return age;
  }

  bool isOfAgeAt(DateTime now) => ageAt(now) >= minimumAge;

  /// `YYYY-MM-DD`, which is what the server stores and re-derives the age from.
  String get birthDateIso {
    final String m = birthDate.month.toString().padLeft(2, '0');
    final String d = birthDate.day.toString().padLeft(2, '0');
    return '${birthDate.year}-$m-$d';
  }

  static DateTime? parseIsoDate(String? raw) {
    if (raw == null || raw.length < 10) {
      return null;
    }
    final int? year = int.tryParse(raw.substring(0, 4));
    final int? month = int.tryParse(raw.substring(5, 7));
    final int? day = int.tryParse(raw.substring(8, 10));
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  UserProfile copyWith({
    String? firstName,
    DateTime? birthDate,
    Gender? gender,
    InterestedIn? interestedIn,
    String? bio,
    int? photoCount,
    bool? isPhotoVerified,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      birthDate: birthDate ?? this.birthDate,
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
      other.birthDate == birthDate &&
      other.gender == gender &&
      other.interestedIn == interestedIn &&
      other.bio == bio &&
      other.photoCount == photoCount &&
      other.isPhotoVerified == isPhotoVerified;

  @override
  int get hashCode => Object.hash(
        id,
        firstName,
        birthDate,
        gender,
        interestedIn,
        bio,
        photoCount,
        isPhotoVerified,
      );
}
