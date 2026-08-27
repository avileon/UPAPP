import '../../domain/entities/nearby_person.dart';

/// Demo population for Milestone 1.
///
/// Names, ages and one-liners only — no photo URLs. Portraits are generated
/// from [NearbyPerson.auraSeed] so the project ships with zero image assets and
/// nobody's face is in the repo.
abstract final class MockData {
  static const List<NearbyPerson> people = <NearbyPerson>[
    NearbyPerson(
      id: 'p1',
      firstNameHe: 'נועה',
      firstNameEn: 'Noa',
      age: 27,
      bioHe: 'באתי בשביל המוזיקה, נשארתי בשביל השיחות',
      bioEn: 'Came for the music, stayed for the talking',
      isPhotoVerified: true,
      auraSeed: 0,
    ),
    NearbyPerson(
      id: 'p2',
      firstNameHe: 'יותם',
      firstNameEn: 'Yotam',
      age: 30,
      bioHe: 'מתופף. כן, זו כל האישיות שלי',
      bioEn: 'Drummer. Yes, that is my whole personality',
      isPhotoVerified: false,
      auraSeed: 1,
    ),
    NearbyPerson(
      id: 'p3',
      firstNameHe: 'מאיה',
      firstNameEn: 'Maya',
      age: 25,
      bioHe: 'שואלת יותר מדי שאלות',
      bioEn: 'Asks too many questions',
      isPhotoVerified: true,
      auraSeed: 2,
    ),
    NearbyPerson(
      id: 'p4',
      firstNameHe: 'עידן',
      firstNameEn: 'Idan',
      age: 33,
      bioHe: 'שף בבוקר, גרוע בערב',
      bioEn: 'Chef by day, useless by night',
      isPhotoVerified: false,
      auraSeed: 3,
    ),
    NearbyPerson(
      id: 'p5',
      firstNameHe: 'שירה',
      firstNameEn: 'Shira',
      age: 28,
      bioHe: 'אם יש כלב במסיבה, אני שם',
      bioEn: 'If there is a dog at the party, I am with the dog',
      isPhotoVerified: true,
      auraSeed: 4,
    ),
    NearbyPerson(
      id: 'p6',
      firstNameHe: 'רועי',
      firstNameEn: 'Roi',
      age: 29,
      bioHe: 'טוב בשתיקות מביכות',
      bioEn: 'Great at awkward silences',
      isPhotoVerified: false,
      auraSeed: 5,
    ),
    NearbyPerson(
      id: 'p7',
      firstNameHe: 'טל',
      firstNameEn: 'Tal',
      age: 26,
      bioHe: 'רוקדת גרוע, בכיף',
      bioEn: 'Dances badly, joyfully',
      isPhotoVerified: true,
      auraSeed: 6,
    ),
    NearbyPerson(
      id: 'p8',
      firstNameHe: 'ליאור',
      firstNameEn: 'Lior',
      age: 31,
      bioHe: 'מחפש את מי שמזמין את הסיבוב הבא',
      bioEn: 'Looking for whoever buys the next round',
      isPhotoVerified: false,
      auraSeed: 7,
    ),
  ];

  static NearbyPerson? byId(String id) {
    for (final NearbyPerson person in people) {
      if (person.id == id) {
        return person;
      }
    }
    return null;
  }

  static const List<String> cannedRepliesHe = <String>[
    'היי! ראיתי אותך ליד הבר',
    'אוקיי, אז שנינו עשינו UP. מביך או מגניב?',
    'אתה עדיין פה?',
    'מה שותים?',
  ];

  static const List<String> cannedRepliesEn = <String>[
    'Hey! I saw you by the bar',
    'So we both sent an UP. Awkward or great?',
    'Are you still here?',
    'What are you drinking?',
  ];

  static List<String> repliesFor(String localeCode) =>
      localeCode == 'he' ? cannedRepliesHe : cannedRepliesEn;
}
