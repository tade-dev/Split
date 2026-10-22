import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/organiser_provider.dart';
import 'package:split/providers/splits_providers.dart';

class _FakeApi implements SplitsApi {
  _FakeApi(this.onScan);
  final Future<SplitDoc> Function() onScan;
  final scans = <List<({List<int> bytes, String filename})>>[];

  @override
  Future<SplitDoc> scan(List<({List<int> bytes, String filename})> photos) {
    scans.add(photos);
    return onScan();
  }

  @override
  Future<SplitDoc> createEmpty() => throw UnimplementedError();

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();

  @override
  Future<void> addPeople(String splitId, List<String> names) => throw UnimplementedError();

  @override
  Future<void> removePerson(String splitId, String participantId) => throw UnimplementedError();

  @override
  Future<OpenedSplit> open(String splitId) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();

  @override
  Future<ClaimResult> claimMessage(String splitId, String message, {String? participantId}) => throw UnimplementedError();

  @override
  Future<void> patchClaims(String splitId, String lineId, List<Claim> claims, {bool? shared}) => throw UnimplementedError();

  @override
  Future<RulesPreview> rulesMessage(String splitId, String message) => throw UnimplementedError();

  @override
  Future<void> lock(String splitId) => throw UnimplementedError();

  @override
  Future<void> unlock(String splitId) => throw UnimplementedError();

  @override
  Future<void> markPaidCash(String splitId, String participantId) => throw UnimplementedError();

  @override
  Future<NudgeDraft> draftNudge(String splitId, String participantId, String tone) => throw UnimplementedError();

  @override
  Future<void> nudgeSent(String splitId, String participantId, String text) => throw UnimplementedError();

  @override
  Future<void> snoozeNudge(String splitId, String participantId) => throw UnimplementedError();
}

ProviderContainer _container(SplitsApi api) {
  final c = ProviderContainer(overrides: [splitsApiProvider.overrideWithValue(api), bootstrapProvider.overrideWith((ref) async {})]);
  addTearDown(c.dispose);
  return c;
}

const _photo = (bytes: <int>[1, 2, 3], filename: 'bill.png');

void main() {
  test('reading ends ready with the split the API made', () async {
    final api = _FakeApi(() async => const SplitDoc(id: 's1', merchant: 'Little Bao House'));
    final c = _container(api);
    final pending = c.read(scanControllerProvider.notifier).read([_photo]);
    expect(c.read(scanControllerProvider), isA<ScanReading>().having((s) => s.photos, 'photos', 1));
    await pending;
    expect(c.read(scanControllerProvider), isA<ScanReady>().having((s) => s.split.id, 'id', 's1'));
    expect(api.scans.single.single.filename, 'bill.png');
  });

  test("a model that failed twice ends with the API's own words", () async {
    final api = _FakeApi(() async => throw DioException(
          requestOptions: RequestOptions(path: '/v1/splits/scan'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/splits/scan'),
            statusCode: 502,
            data: {'error': {'code': 'AI_PARSE_FAILED', 'message': 'SplitDoc could not read that reliably. Please enter it by hand.'}},
          ),
        ));
    final c = _container(api);
    await c.read(scanControllerProvider.notifier).read([_photo]);
    expect(
      c.read(scanControllerProvider),
      isA<ScanFailed>().having((s) => s.message, 'message', 'SplitDoc could not read that reliably. Please enter it by hand.'),
    );
  });

  test('a second read while one is in flight does not scan twice', () async {
    final gate = Completer<SplitDoc>();
    final api = _FakeApi(() => gate.future);
    final c = _container(api);
    final first = c.read(scanControllerProvider.notifier).read([_photo]);
    await c.read(scanControllerProvider.notifier).read([_photo]);
    // The first read waits for bootstrap before it scans.
    await Future<void>.delayed(Duration.zero);
    expect(api.scans, hasLength(1));
    gate.complete(const SplitDoc(id: 's1'));
    await first;
  });

  test('reset goes back to idle', () async {
    final c = _container(_FakeApi(() async => const SplitDoc(id: 's1')));
    await c.read(scanControllerProvider.notifier).read([_photo]);
    c.read(scanControllerProvider.notifier).reset();
    expect(c.read(scanControllerProvider), isA<ScanIdle>());
  });
}
