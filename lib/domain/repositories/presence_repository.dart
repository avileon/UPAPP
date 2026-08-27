import '../entities/live_session.dart';
import '../entities/nearby_person.dart';

/// Everything about being discoverable and discovering others.
///
/// This is the seam where real BLE arrives in Milestone 3. The app above it
/// never sees a token, a MAC address or an RSSI value — it asks to go Live and
/// receives resolved people. That boundary is what keeps the identity rules
/// enforceable in one place.
abstract interface class PresenceRepository {
  /// Maps to `POST /live/start`. The server mints the rotating BLE tokens.
  Future<LiveSession> startLive(Duration duration);

  /// Maps to `POST /live/stop`.
  Future<void> stopLive();

  /// People currently resolved as nearby. Emits a fresh list on every change
  /// and an empty list when the session ends.
  ///
  /// Behind this stream in Milestone 3: scan → collect tokens → dedupe locally
  /// → `POST /nearby/resolve` → filter by blocks and preferences server-side.
  Stream<List<NearbyPerson>> watchNearby();

  /// Test and demo hook: pretend the radio just picked someone up.
  void simulateDiscovery();

  void dispose();
}
