import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_fix.dart';

/// Why a location could not be read, as a code the screens translate.
class LocationException implements Exception {
  const LocationException(this.code);

  /// `location_denied`, `location_off`, or `location_timeout`.
  final String code;

  @override
  String toString() => 'LocationException($code)';
}

/// The phone's location, read once, when the person asks for something that
/// needs it — joining a venue, or "who is around me".
///
/// Never in the background and never stored: one reading goes to the server
/// with one request, and the app forgets it.
class LocationService {
  const LocationService();

  static const Duration _timeout = Duration(seconds: 20);

  /// Asks for permission if needed, then reads one fix. Throws
  /// [LocationException] with a code the UI can explain.
  Future<GeoFix> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException('location_off');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException('location_denied');
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
      return GeoFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException('location_timeout');
    } on PermissionDeniedException {
      throw const LocationException('location_denied');
    } on LocationServiceDisabledException {
      throw const LocationException('location_off');
    } catch (_) {
      // The web implementation reports a refusal as a plain error in some
      // browsers. From the person's side it is the same thing.
      throw const LocationException('location_denied');
    }
  }

  /// [currentFix], or null instead of throwing — for the background refresh
  /// in area mode, where a failed read just keeps the last one.
  Future<GeoFix?> tryFix() async {
    try {
      return await currentFix();
    } on LocationException {
      return null;
    }
  }
}
