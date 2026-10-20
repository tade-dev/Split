import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/api_client.dart';
import '../models/participant.dart';
import '../models/split.dart';

typedef Photo = ({List<int> bytes, String filename});

/// Every write to a split. Named so tests can fake it without Dio or a token.
abstract class SplitsApi {
  /// POST /v1/splits/scan. 3-10 seconds: the Reading screen covers it.
  Future<SplitDoc> scan(List<Photo> photos);

  /// PATCH /v1/splits/:id/receipt. Send only what changed.
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body);

  /// PATCH /v1/splits/:id/rules.
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body);
}

class HttpSplitsApi implements SplitsApi {
  HttpSplitsApi(this._client);
  final ApiClient _client;

  static SplitDoc _split(Map<String, dynamic> body) =>
      SplitDoc.fromJson(body['split'] as Map<String, dynamic>);

  @override
  Future<SplitDoc> scan(List<Photo> photos) async =>
      _split(await _client.postImages('/v1/splits/scan', photos));

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) async =>
      _split(await _client.patchJson('/v1/splits/$splitId/receipt', body));

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) async =>
      _split(await _client.patchJson('/v1/splits/$splitId/rules', body));
}

/// Reads go straight to Firestore so the screens update live; writes go
/// through [SplitsApi]. Clients never write Firestore.
class SplitsRepository {
  SplitsRepository([this._firestore]);
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<SplitDoc>> watchSplits(String organiserId) => _db
      .collection('organisers/$organiserId/splits')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) SplitDoc.fromJson({...d.data(), 'id': d.id})]);

  /// One split, live. A missing document emits null rather than an error.
  Stream<SplitDoc?> watchSplit(String organiserId, String splitId) => _db
      .doc('organisers/$organiserId/splits/$splitId')
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return SplitDoc.fromJson({...data, 'id': snap.id});
      });

  Stream<List<Participant>> watchParticipants(String organiserId, String splitId) => _db
      .collection('organisers/$organiserId/splits/$splitId/participants')
      .orderBy('joinOrder')
      .snapshots()
      .map((snap) => [for (final d in snap.docs) Participant.fromJson({...d.data(), 'id': d.id})]);
}
