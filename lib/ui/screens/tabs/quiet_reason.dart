import '../../../core/l10n/app_strings.dart';
import '../../../state/live_controller.dart';

/// Why the nearby list is empty — in one place, because two screens ask it.
///
/// "Nobody here" has three causes with three different fixes, and they are
/// indistinguishable to the person holding the phone: no room at all, an empty
/// room, or a room whose people the preference rules exclude. The third is the
/// one that reads as a broken app and is not — the rule has to agree in both
/// directions, so two people who each say "interested in women" never see each
/// other, which is correct and completely invisible without this text.
///
/// Returns null when there is nothing useful to say — not live, or people are
/// actually showing.
String? quietReason({
  required AppStrings strings,
  required LiveController live,
  required bool hasServer,
  required bool anyoneVisible,
}) {
  if (!live.isLive || anyoneVisible) {
    return null;
  }
  if (!hasServer) {
    // The mock stack finds people with a fake radio and has no room at all.
    // Sending someone to the venue screen there would be advice they cannot
    // act on.
    return strings.nearbyQuietBody;
  }
  if (!live.room.isJoined) {
    return strings.quietNoRoomBody;
  }
  if (live.room.peers == 0) {
    return strings.quietEmptyRoomBody(live.room.code);
  }
  return strings.quietFilteredBody(live.room.peers);
}
