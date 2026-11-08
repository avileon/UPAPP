import 'package:flutter_test/flutter_test.dart';
import 'package:up/domain/entities/live_intent.dart';

/// Why you are Live, and the one rule it changes.
///
/// The server enforces this; the copy here exists so the app can *explain* it
/// on the screen where the choice is made. Two implementations of one rule
/// stay honest only if both are stated plainly and tested.
void main() {
  test('gender preference always applies — UP is a dating app', () {
    expect(LiveIntent.date.preferencesApply, isTrue);
    expect(LiveIntent.meet.preferencesApply, isTrue);
  });

  test('an intent this build does not know about is not an error', () {
    // A phone one version behind must still be able to go Live. Falling to the
    // most permissive intent is safe in exactly one direction: it can show you
    // people, never hide the ones dating would have hidden.
    // Since November 2026 everything that is not a known name is dating.
    for (final String? raw in <String?>[null, '', 'DATE', 'romance', 'meet ', 'work', 'doing']) {
      expect(LiveIntent.fromWire(raw), LiveIntent.date, reason: '$raw');
    }
  });

  test('the wire names are the protocol and do not follow a rename', () {
    expect(
      LiveIntent.values.map((LiveIntent i) => i.wire).toList(),
      <String>['meet', 'date'],
    );
    for (final LiveIntent intent in LiveIntent.values) {
      expect(LiveIntent.fromWire(intent.wire), intent);
    }
  });
}
