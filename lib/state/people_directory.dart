import 'package:flutter/foundation.dart';

import '../domain/entities/nearby_person.dart';

/// Everyone this device has legitimately been shown, by id.
///
/// The screens need to render a name next to a match long after the radio
/// stopped seeing that person, and asking the server for a profile by id would
/// mean an endpoint that hands out profiles by id — precisely the endpoint the
/// privacy rules exist to avoid. So the app remembers only what the server
/// already chose to send it, and remembers it nowhere but in memory: closing
/// the app forgets everyone.
class PeopleDirectory extends ChangeNotifier {
  final Map<String, NearbyPerson> _byId = <String, NearbyPerson>{};

  NearbyPerson? byId(String id) => _byId[id];

  int get length => _byId.length;

  void remember(NearbyPerson person) => rememberAll(<NearbyPerson>[person]);

  void rememberAll(Iterable<NearbyPerson> people) {
    bool changed = false;
    for (final NearbyPerson person in people) {
      if (person.id.isEmpty) {
        continue;
      }
      // Always overwrite — a re-resolved profile is the fresher one. Notify
      // sparingly, so a poll that returns the same room every five seconds does
      // not rebuild the whole tree on every tick: a new person, or one of the
      // two UP flags flipping. Those flags are the only fields that change
      // mid-session *and* change what a screen draws, and missing the flip is
      // the difference between being told somebody UP'd you and not.
      final NearbyPerson? existing = _byId[person.id];
      final bool worthRebuilding = existing == null ||
          existing.sentYouUp != person.sentYouUp ||
          existing.youSentUp != person.youSentUp;
      _byId[person.id] = person;
      changed = changed || worthRebuilding;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Called when someone is blocked: nothing about them should survive in the
  /// app's memory once the user has said they do not want to see them.
  void forget(String id) {
    if (_byId.remove(id) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_byId.isEmpty) {
      return;
    }
    _byId.clear();
    notifyListeners();
  }
}
