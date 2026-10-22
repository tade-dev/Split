import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/api_client.dart';
import '../models/ambiguity.dart';
import '../models/participant.dart';
import '../models/split.dart';

typedef Photo = ({List<int> bytes, String filename});

/// What POST /v1/splits/:id/open returns: one signed link per friend and the
/// text to paste in the group chat.
typedef OpenedSplit = ({List<({String participantId, String name, String url})> links, String groupMessage});

/// What POST /v1/splits/:id/claims/message wrote, and what it could not.
typedef ClaimResult = ({
  List<({String lineId, String participantId, String name, int weight, String portionLabel})> applied,
  List<Ambiguity> problems,
  List<String> ignored,
});

/// What POST /v1/splits/:id/rules/message proposes. Nothing is written until
/// the organiser says yes and the rules go through [SplitsApi.patchRules].
/// A drafted reminder (endpoint 16). `text` already holds the friend's link.
typedef NudgeDraft = ({String text, String tone, bool shouldSkip, String? skipReason});

typedef RulesPreview = ({Rules? rules, String? confirmationText, int? figureMinor, String? message});

/// Every write to a split. Named so tests can fake it without Dio or a token.
abstract class SplitsApi {
  /// POST /v1/splits/scan. 3-10 seconds: the Reading screen covers it.
  Future<SplitDoc> scan(List<Photo> photos);

  /// POST /v1/splits. A blank draft to type the bill into when a read fails.
  Future<SplitDoc> createEmpty();

  /// PATCH /v1/splits/:id/receipt. Send only what changed.
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body);

  /// PATCH /v1/splits/:id/rules.
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body);

  /// POST /v1/splits/:id/participants. The new people arrive on the stream.
  Future<void> addPeople(String splitId, List<String> names);

  /// DELETE /v1/splits/:id/participants/:pid. Before lock only.
  Future<void> removePerson(String splitId, String participantId);

  /// POST /v1/splits/:id/open. Moves the split to claiming; safe to repeat.
  Future<OpenedSplit> open(String splitId);

  /// POST /v1/splits/:id/claims/message. The organiser says who had what;
  /// it is written at once and the claims arrive on the stream.
  Future<ClaimResult> claimMessage(String splitId, String message, {String? participantId});

  /// PATCH /v1/splits/:id/claims. Replaces one line's claims, which is how
  /// *Share between …* resolves.
  Future<void> patchClaims(String splitId, String lineId, List<Claim> claims, {bool? shared});

  /// POST /v1/splits/:id/rules/message. A preview for the confirm card.
  Future<RulesPreview> rulesMessage(String splitId, String message);

  /// POST /v1/splits/:id/lock. Freezes every share; safe to repeat.
  Future<void> lock(String splitId);

  /// POST /v1/splits/:id/unlock. Refused once anyone has started paying.
  Future<void> unlock(String splitId);

  /// Endpoint 17. Supersedes any open PayPal orders.
  Future<void> cancel(String splitId);

  /// Endpoint 15: the friend paid in cash or by bank transfer.
  Future<void> markPaidCash(String splitId, String participantId);

  /// Endpoint 16: drafts a reminder in a tone ('friendly', 'cheeky', 'firm').
  Future<NudgeDraft> draftNudge(String splitId, String participantId, String tone);

  /// The organiser copied the nudge into their chat. Split never sends it.
  Future<void> nudgeSent(String splitId, String participantId, String text);

  /// "Remind me tomorrow".
  Future<void> snoozeNudge(String splitId, String participantId);
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
  Future<SplitDoc> createEmpty() async => _split(await _client.postJson('/v1/splits', const <String, Object?>{}));

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) async =>
      _split(await _client.patchJson('/v1/splits/$splitId/receipt', body));

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) async =>
      _split(await _client.patchJson('/v1/splits/$splitId/rules', body));

  @override
  Future<void> addPeople(String splitId, List<String> names) =>
      _client.postJson('/v1/splits/$splitId/participants', {'names': names});

  @override
  Future<void> removePerson(String splitId, String participantId) =>
      _client.deleteJson('/v1/splits/$splitId/participants/$participantId');

  @override
  Future<OpenedSplit> open(String splitId) async {
    final body = await _client.postJson('/v1/splits/$splitId/open', const <String, Object?>{});
    return (
      links: [
        for (final l in (body['links'] as List).cast<Map<String, dynamic>>())
          (participantId: l['participantId'] as String, name: l['name'] as String, url: l['url'] as String),
      ],
      groupMessage: body['groupMessage'] as String,
    );
  }

  @override
  Future<ClaimResult> claimMessage(String splitId, String message, {String? participantId}) async {
    final body = await _client.postJson('/v1/splits/$splitId/claims/message', {
      'participantId': participantId,
      'message': message,
    });
    return (
      applied: [
        for (final a in (body['applied'] as List).cast<Map<String, dynamic>>())
          (
            lineId: a['lineId'] as String,
            participantId: a['participantId'] as String,
            name: a['name'] as String,
            weight: (a['weight'] as num).toInt(),
            portionLabel: a['portionLabel'] as String? ?? '',
          ),
      ],
      problems: [for (final p in (body['problems'] as List).cast<Map<String, dynamic>>()) Ambiguity.fromJson(p)],
      ignored: (body['ignored'] as List).cast<String>(),
    );
  }

  @override
  Future<void> patchClaims(String splitId, String lineId, List<Claim> claims, {bool? shared}) =>
      _client.patchJson('/v1/splits/$splitId/claims', {
        'lineId': lineId,
        'claims': [for (final c in claims) {'participantId': c.participantId, 'weight': c.weight}],
        'shared': ?shared,
      });

  @override
  Future<RulesPreview> rulesMessage(String splitId, String message) async {
    final body = await _client.postJson('/v1/splits/$splitId/rules/message', {'message': message});
    final preview = body['preview'] as Map<String, dynamic>?;
    return (
      rules: preview == null ? null : Rules.fromJson(preview['rules'] as Map<String, dynamic>),
      confirmationText: preview?['confirmationText'] as String?,
      figureMinor: (preview?['figureMinor'] as num?)?.toInt(),
      message: body['message'] as String?,
    );
  }

  @override
  Future<void> lock(String splitId) => _client.postJson('/v1/splits/$splitId/lock', const <String, Object?>{});

  @override
  Future<void> unlock(String splitId) => _client.postJson('/v1/splits/$splitId/unlock', const <String, Object?>{});

  @override
  Future<void> cancel(String splitId) => _client.postJson('/v1/splits/$splitId/cancel', const <String, Object?>{});

  @override
  Future<void> markPaidCash(String splitId, String participantId) =>
      _client.postJson('/v1/splits/$splitId/participants/$participantId/paid-cash', const <String, Object?>{});

  @override
  Future<NudgeDraft> draftNudge(String splitId, String participantId, String tone) async {
    final body = await _client.postJson('/v1/splits/$splitId/participants/$participantId/nudge', {'tone': tone});
    return (
      text: body['text'] as String,
      tone: body['tone'] as String? ?? tone,
      shouldSkip: body['shouldSkip'] as bool? ?? false,
      skipReason: body['skipReason'] as String?,
    );
  }

  @override
  Future<void> nudgeSent(String splitId, String participantId, String text) =>
      _client.postJson('/v1/splits/$splitId/participants/$participantId/nudge/sent', {'text': text});

  @override
  Future<void> snoozeNudge(String splitId, String participantId) =>
      _client.postJson('/v1/splits/$splitId/participants/$participantId/nudge/snooze', const <String, Object?>{});
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
