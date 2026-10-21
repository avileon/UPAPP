import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_mappers.dart';

/// A registered place, as the join screen needs it.
@immutable
class VenueInfo {
  const VenueInfo({
    required this.code,
    required this.name,
    required this.sessionMinutes,
    this.logoKey,
  });

  /// The place's logo, as a media key, or null.
  final String? logoKey;

  final String code;
  final String name;

  /// How long one scan lets you stay before you have to scan again.
  final int sessionMinutes;
}

/// Looks up the place behind a QR code.
class VenueApi {
  const VenueApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// The place, or null when the code is unknown or switched off. Network
  /// problems throw [ApiException] like everything else.
  Future<VenueInfo?> lookup(String code) async {
    try {
      final Map<String, dynamic> json =
          await _client.get('/venues/${Uri.encodeComponent(code)}');
      return VenueInfo(
        code: ApiMappers.string(json['code']),
        name: ApiMappers.string(json['name']),
        sessionMinutes: ApiMappers.integer(json['sessionMinutes'], 60),
        logoKey: json['logo'] is String ? json['logo'] as String : null,
      );
    } on ApiException catch (error) {
      if (error.code == 'venue_unknown') {
        return null;
      }
      rethrow;
    }
  }

  /// Pulls a venue code out of whatever a QR held: our own join link
  /// (`…/?venue=CODE`), a bare code, or anything with a `venue` parameter.
  static String? codeFromScan(String raw) {
    final String text = raw.trim();
    final Uri? uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme) {
      final String? fromQuery = uri.queryParameters['venue'];
      if (fromQuery != null) {
        return _normalise(fromQuery);
      }
      return null;
    }
    return _normalise(text);
  }

  static String? _normalise(String raw) {
    final String key = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (key.length < 3 || key.length > 12) {
      return null;
    }
    return key;
  }
}
