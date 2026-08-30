import '../../domain/entities/match_thread.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/nearby_person.dart';
import '../../domain/entities/reality_answer.dart';
import '../../domain/entities/user_profile.dart';

/// JSON in one direction, entities out.
///
/// Every field is read defensively. The server is ours today, but the app on a
/// phone outlives the server it was built against: a response that gains,
/// loses or renames a field must produce a slightly emptier screen, never a
/// crash on a stranger's device.
abstract final class ApiMappers {
  static String string(Object? value) => value is String ? value : '';

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static DateTime dateTime(Object? value, DateTime fallback) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? fallback;
    }
    return fallback;
  }

  static Map<String, dynamic> map(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  static List<Map<String, dynamic>> list(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  // -- profile -------------------------------------------------------------

  /// The `photos` array as it comes off any profile payload.
  static List<String> photoKeys(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }

  static Gender gender(Object? value) {
    switch (value) {
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.male;
    }
  }

  static String genderKey(Gender value) => value.name;

  static InterestedIn interestedIn(Object? value) {
    switch (value) {
      case 'men':
        return InterestedIn.men;
      case 'everyone':
        return InterestedIn.everyone;
      default:
        return InterestedIn.women;
    }
  }

  static String interestedInKey(InterestedIn value) => value.name;

  static String realityAnswerKey(RealityAnswer answer) => answer.name;

  /// `GET /me/profile` and `PUT /me/profile`.
  ///
  /// Returns null when the account exists but the profile does not yet — a
  /// fresh sign-in, before the setup screens have run. The caller shows setup
  /// rather than an empty profile.
  static UserProfile? profile(Map<String, dynamic> json) {
    final String id = string(json['id']);
    final String firstName = string(json['firstName']);
    final DateTime? birthDate =
        UserProfile.parseIsoDate(json['birthDate'] as String?);
    if (id.isEmpty || firstName.isEmpty || birthDate == null) {
      return null;
    }
    return UserProfile(
      id: id,
      firstName: firstName,
      birthDate: birthDate,
      gender: gender(json['gender']),
      interestedIn: interestedIn(json['interestedIn']),
      bio: string(json['bio']),
      photoKeys: photoKeys(json['photos']),
      isPhotoVerified: json['photoVerified'] == true,
    );
  }

  // -- nearby --------------------------------------------------------------

  /// One entry of `POST /nearby/resolve`.
  ///
  /// The server sends one name, because it stores one name. Both language
  /// slots therefore get the same string: a person's name is not a translatable
  /// resource, and inventing a transliteration would be putting words in their
  /// mouth.
  static NearbyPerson nearbyPerson(Map<String, dynamic> json) {
    final String id = string(json['id']);
    final String name = string(json['firstName']);
    final String bio = string(json['bio']);
    return NearbyPerson(
      id: id,
      firstNameHe: name,
      firstNameEn: name,
      age: integer(json['age'], 0),
      bioHe: bio,
      bioEn: bio,
      isPhotoVerified: json['photoVerified'] == true,
      auraSeed: id.hashCode.abs() % 360,
      photoKeys: photoKeys(json['photos']),
      sentYouUp: json['sentYouUp'] == true,
      youSentUp: json['youSentUp'] == true,
    );
  }

  // -- matches -------------------------------------------------------------

  static Message message(Map<String, dynamic> json, DateTime fallbackTime) {
    return Message(
      id: string(json['id']),
      body: string(json['body']),
      isMine: json['mine'] == true,
      sentAt: dateTime(json['sentAt'], fallbackTime),
    );
  }

  /// One entry of `GET /matches`, with the messages fetched separately.
  static MatchThread matchThread(
    Map<String, dynamic> json, {
    required List<Message> messages,
    required bool isUnread,
    required DateTime fallbackTime,
  }) {
    return MatchThread(
      id: string(json['id']),
      personId: string(map(json['person'])['id']),
      matchedAt: dateTime(json['matchedAt'], fallbackTime),
      messages: messages,
      // The server never says which answer you gave, only that you gave one —
      // the tally is not the client's business. `somewhat` is the neutral
      // stand-in that closes the prompt without claiming anything.
      realityAnswer:
          json['realityAnswered'] == true ? RealityAnswer.somewhat : null,
      isUnread: isUnread,
    );
  }
}
