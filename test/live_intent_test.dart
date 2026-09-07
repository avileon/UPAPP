import 'package:flutter_test/flutter_test.dart';
import 'package:up/domain/entities/live_intent.dart';

/// Why you are Live, and the one rule it changes.
///
/// The server enforces this; the copy here exists so the app can *explain* it
/// on the screen where the choice is made. Two implementations of one rule
/// stay honest only if both are stated plainly and tested.
void main() {
  test('gender preference gates dating and nothing else', () {
    // The whole difference between an app for meeting people and a dating app.
    // Before this, the filter ran on every discovery, so two men who had both
    // said "interested in women" could stand in the same room all evening and
    // never see each other — correct for dating, absurd for a five-a-side game.
    expect(LiveIntent.date.preferencesApply, isTrue);
    for (final LiveIntent intent in <LiveIntent>[
      LiveIntent.meet,
      LiveIntent.work,
      LiveIntent.doing,
    ]) {
      expect(intent.preferencesApply, isFalse, reason: intent.name);
    }
  });

  test('an intent this build does not know about is not an error', () {
    // A phone one version behind must still be able to go Live. Falling to the
    // most permissive intent is safe in exactly one direction: it can show you
    // people, never hide the ones dating would have hidden.
    for (final String? raw in <String?>[null, '', 'DATE', 'romance', 'meet ']) {
      expect(LiveIntent.fromWire(raw), LiveIntent.meet, reason: '$raw');
    }
  });

  test('the wire names are the protocol and do not follow a rename', () {
    expect(
      LiveIntent.values.map((LiveIntent i) => i.wire).toList(),
      <String>['meet', 'date', 'work', 'doing'],
    );
    for (final LiveIntent intent in LiveIntent.values) {
      expect(LiveIntent.fromWire(intent.wire), intent);
    }
  });
}
