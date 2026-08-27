import 'package:flutter/foundation.dart';

/// Someone the radio picked up and the server agreed to reveal.
///
/// There is deliberately no distance, no coordinates and no RSSI on this
/// object. The only spatial claim UP ever makes is "near you right now", and
/// modelling anything finer would invite a UI that leaks it.
@immutable
class NearbyPerson {
  const NearbyPerson({
    required this.id,
    required this.firstNameHe,
    required this.firstNameEn,
    required this.age,
    required this.bioHe,
    required this.bioEn,
    required this.isPhotoVerified,
    required this.auraSeed,
  });

  final String id;
  final String firstNameHe;
  final String firstNameEn;
  final int age;
  final String bioHe;
  final String bioEn;
  final bool isPhotoVerified;

  /// Deterministic seed for the placeholder portrait. Milestone 2 replaces this
  /// with a signed photo URL.
  final int auraSeed;

  String nameFor(String localeCode) =>
      localeCode == 'he' ? firstNameHe : firstNameEn;

  String bioFor(String localeCode) => localeCode == 'he' ? bioHe : bioEn;

  String initialFor(String localeCode) {
    final String name = nameFor(localeCode);
    return name.isEmpty ? '?' : name.substring(0, 1);
  }

  @override
  bool operator ==(Object other) => other is NearbyPerson && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
