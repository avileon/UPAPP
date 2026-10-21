import 'package:flutter/foundation.dart';

/// One reading of the phone's location, as sent to the server.
///
/// Used for one question only — "is this phone inside that place / near
/// those people" — and never stored by the app. The server drops it after
/// answering.
@immutable
class GeoFix {
  const GeoFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
  });

  final double lat;
  final double lng;

  /// The phone's own error estimate, in metres.
  final double accuracy;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
      };
}
