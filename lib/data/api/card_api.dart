import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_mappers.dart';

/// A card this person can hand over right now.
@immutable
class CardShare {
  const CardShare({
    required this.token,
    required this.url,
    this.expiresAt,
    this.wallet = false,
  });

  /// The server can make a Google Wallet pass.
  final bool wallet;

  final String token;

  /// `https://…/c/<token>` — what the QR holds and what NFC sends.
  final String url;

  /// Null for cards that last until revoked (stickers, Wallet passes).
  final DateTime? expiresAt;
}

/// What a received card shows: a first name and, maybe, a photo.
@immutable
class CardInfo {
  const CardInfo({
    required this.token,
    required this.firstName,
    required this.hasPhoto,
    required this.verified,
  });

  final String token;
  final String firstName;
  final bool hasPhoto;
  final bool verified;
}

/// The answer to a card: always a match, because giving the card was the
/// giver's UP.
@immutable
class CardAnswer {
  const CardAnswer({required this.matchId, required this.personId});

  final String matchId;
  final String personId;
}

/// Business cards: issue one to share, look one up, answer one.
class CardApi {
  const CardApi({required ApiClient client, required String Function() baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  final ApiClient _client;
  final String Function() _baseUrl;

  /// A fresh card for one tap or one scan. Valid for 24 hours, answers one
  /// person.
  Future<CardShare> issue({String kind = 'share'}) async {
    final Map<String, dynamic> json =
        await _client.post('/me/card', <String, Object?>{'kind': kind});
    final String expires = ApiMappers.string(json['expiresAt']);
    return CardShare(
      token: ApiMappers.string(json['token']),
      url: ApiMappers.string(json['url']),
      expiresAt: expires.isEmpty ? null : DateTime.tryParse(expires),
      wallet: json['wallet'] == true,
    );
  }

  /// A "Save to Google Wallet" link for a long-lived card. Replaces the
  /// previous Wallet pass's QR.
  Future<String> walletSaveUrl() async {
    final Map<String, dynamic> json = await _client.post('/me/card/wallet');
    return ApiMappers.string(json['saveUrl']);
  }

  /// Every card ever handed out stops working.
  Future<void> revokeAll() => _client.delete('/me/cards');

  /// Throws [ApiException] with `card_expired`, `card_used` or
  /// `card_unknown` when the card no longer works.
  Future<CardInfo> lookup(String token) async {
    final Map<String, dynamic> json =
        await _client.get('/cards/${Uri.encodeComponent(token)}');
    return CardInfo(
      token: token,
      firstName: ApiMappers.string(json['firstName']),
      hasPhoto: json['photo'] == true,
      verified: json['verified'] == true,
    );
  }

  Future<CardAnswer> answer(String token) async {
    final Map<String, dynamic> json =
        await _client.post('/cards/${Uri.encodeComponent(token)}/up');
    final Object? match = json['match'];
    final Map<String, dynamic> m =
        match is Map<String, dynamic> ? match : const <String, dynamic>{};
    return CardAnswer(
      matchId: ApiMappers.string(m['id']),
      personId: ApiMappers.string(m['personId']),
    );
  }

  /// The card's one public photo. Works without signing in, and only while
  /// the card does.
  String photoUrl(String token) =>
      '${_baseUrl()}/c/${Uri.encodeComponent(token)}/photo';
}
