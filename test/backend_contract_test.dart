import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up/data/api/api_mappers.dart';
import 'package:up/data/api/backend_config.dart';
import 'package:up/domain/entities/nearby_person.dart';
import 'package:up/domain/entities/user_profile.dart';

/// The two places where the app and the server have to agree exactly.
///
/// Both rules are implemented twice — once in Dart and once in JavaScript —
/// because neither side can trust the other to have applied it. That is the
/// right call, and it is also exactly the situation where the two copies drift
/// apart six months later. So the examples here are deliberately the same
/// examples as in `server/test/venue.test.js`: when one side changes, one of
/// the two suites goes red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('venue keys', () {
    test('the same room, however it is typed', () {
      for (final String raw in <String>[
        'BAR12',
        'bar12',
        ' bar 12 ',
        'bar-12',
        'Bar_12',
        'bar.12',
      ]) {
        expect(BackendConfig.normaliseVenue(raw), 'BAR12', reason: raw);
      }
    });

    test('nothing usable is null, never a shared empty room', () {
      // Two people who typed nothing must not end up in one enormous room
      // together, so an unusable code has to be null rather than empty.
      for (final String raw in <String>['', '  ', '--', 'ab', 'שלום']) {
        expect(BackendConfig.normaliseVenue(raw), isNull, reason: raw);
      }
    });

    test('long codes are rejected rather than truncated into collisions', () {
      expect(BackendConfig.normaliseVenue('THIRTEENCHARS'), isNull);
      expect(BackendConfig.normaliseVenue('TWELVECHARSX'), 'TWELVECHARSX');
    });
  });

  group('age', () {
    UserProfile profileBornOn(DateTime date) => UserProfile(
          id: 'u',
          firstName: 'Test',
          birthDate: date,
          gender: Gender.other,
          interestedIn: InterestedIn.everyone,
        );

    test('the birthday has to have happened', () {
      final DateTime today = DateTime(2026, 8, 27);
      // Eighteen years to the day: of age.
      expect(profileBornOn(DateTime(2008, 8, 27)).ageAt(today), 18);
      // One day short: not yet, and the difference matters legally.
      expect(profileBornOn(DateTime(2008, 8, 28)).ageAt(today), 17);
      expect(profileBornOn(DateTime(2008, 8, 28)).isOfAgeAt(today), isFalse);
      expect(profileBornOn(DateTime(2008, 8, 27)).isOfAgeAt(today), isTrue);
    });

    test('a year alone would have let that case through', () {
      // The reason the profile stores a date rather than a year: both of the
      // dates above are in 2008, and year subtraction calls both of them 18.
      final DateTime today = DateTime(2026, 8, 27);
      expect(today.year - 2008, 18);
      expect(profileBornOn(DateTime(2008, 12, 31)).isOfAgeAt(today), isFalse);
    });

    test('the ISO form is what the server re-checks', () {
      expect(profileBornOn(DateTime(2000, 3, 7)).birthDateIso, '2000-03-07');
      expect(UserProfile.parseIsoDate('2000-03-07'), DateTime(2000, 3, 7));
      expect(UserProfile.parseIsoDate('not-a-date'), isNull);
      expect(UserProfile.parseIsoDate(null), isNull);
    });
  });

  group('server address', () {
    setUp(() {
      // An empty store per test, so nothing here leaks into the widget tests.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    BackendConfig freshConfig() => BackendConfig();

    test('a pasted tunnel URL is cleaned up rather than refused', () async {
      final BackendConfig config = freshConfig();
      await config.setServer(baseUrl: '  xyz.trycloudflare.com/  ');
      expect(config.baseUrl, 'https://xyz.trycloudflare.com');
      expect(config.isConfigured, isTrue);
    });

    test('changing server drops the previous server\'s tokens', () async {
      final BackendConfig config = freshConfig();
      await config.setServer(baseUrl: 'https://one.example');
      await config.setTokens(accessToken: 'a', refreshToken: 'r');
      expect(config.isSignedIn, isTrue);

      await config.setServer(baseUrl: 'https://two.example');
      expect(config.isSignedIn, isFalse);
    });

    test('no address means the app stays on mock data', () {
      expect(freshConfig().isConfigured, isFalse);
    });
  });

  group('the UP flags on a nearby person', () {
    // These decide whether an UP is visible to anyone at all. Sent by the
    // server per request, for people the caller is already allowed to see, and
    // read here — so a rename on either side goes red rather than quietly
    // turning the feature off, which is exactly how it was off to begin with.
    Map<String, dynamic> person(Map<String, dynamic> extra) {
      return <String, dynamic>{
        'id': 'p1',
        'firstName': 'Dana',
        'age': 30,
        'bio': '',
        'photos': <String>[],
        'photoVerified': false,
        ...extra,
      };
    }

    test('both directions are read', () {
      final NearbyPerson mapped = ApiMappers.nearbyPerson(
        person(<String, dynamic>{'sentYouUp': true, 'youSentUp': true}),
      );
      expect(mapped.sentYouUp, isTrue);
      expect(mapped.youSentUp, isTrue);
    });

    test('they are independent of each other', () {
      final NearbyPerson mapped = ApiMappers.nearbyPerson(
        person(<String, dynamic>{'sentYouUp': true, 'youSentUp': false}),
      );
      expect(mapped.sentYouUp, isTrue);
      expect(mapped.youSentUp, isFalse,
          reason: 'receiving an UP is not the same as having sent one');
    });

    test('a server that says nothing means no', () {
      final NearbyPerson mapped = ApiMappers.nearbyPerson(person(<String, dynamic>{}));
      expect(mapped.sentYouUp, isFalse);
      expect(mapped.youSentUp, isFalse);
    });
  });
}
