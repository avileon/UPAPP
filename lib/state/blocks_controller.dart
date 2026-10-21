import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_mappers.dart';

/// Someone this user blocked.
@immutable
class BlockedPerson {
  const BlockedPerson({
    required this.id,
    required this.firstName,
    this.photoKey,
  });

  final String id;
  final String firstName;
  final String? photoKey;
}

/// The block list, and lifting a block.
///
/// A block is forever until lifted here. Lifting it does not bring back
/// anything the block removed — UPs and a match stay gone — it only lets the
/// two of you see each other again the next time you are in the same place.
class BlocksController extends ChangeNotifier {
  BlocksController({required ApiClient client}) : _client = client;

  final ApiClient _client;

  List<BlockedPerson> get people => _people;
  List<BlockedPerson> _people = const <BlockedPerson>[];

  bool get loading => _loading;
  bool _loading = false;

  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;

  Future<void> load() async {
    _loading = true;
    _lastErrorCode = null;
    notifyListeners();
    try {
      final Map<String, dynamic> result = await _client.get('/me/blocks');
      _people = ApiMappers.list(result['blocked'])
          .map(
            (Map<String, dynamic> json) => BlockedPerson(
              id: ApiMappers.string(json['id']),
              firstName: ApiMappers.string(json['firstName']),
              photoKey: json['photo'] is String ? json['photo'] as String : null,
            ),
          )
          .toList(growable: false);
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> unblock(String personId) async {
    _lastErrorCode = null;
    try {
      await _client.delete('/users/$personId/block');
      _people = _people
          .where((BlockedPerson p) => p.id != personId)
          .toList(growable: false);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastErrorCode = error.code;
      notifyListeners();
      return false;
    }
  }
}
