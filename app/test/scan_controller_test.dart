import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

class _FakeApi implements SplitsApi {
  _FakeApi(this.onScan);
  final Future<Split> Function() onScan;
  final scans = <List<({List<int> bytes, String filename})>>[];

  @override
  Future<Split> scan(List<({List<int> bytes, String filename})> photos) {
    scans.add(photos);
    return onScan();
  }

  @override
  Future<Split> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();

  @override
  Future<Split> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();
}

ProviderContainer _container(SplitsApi api) {
  final c = ProviderContainer(overrides: [splitsApiProvider.overrideWithValue(api)]);
  addTearDown(c.dispose);
  return c;
}

const _photo = (bytes: <int>[1, 2, 3], filename: 'bill.png');

void main() {
  test('reading ends ready with the split the API made', () async {
    final api = _FakeApi(() async => const Split(id: 's1', merchant: 'Little Bao House'));
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
            data: {'error': {'code': 'AI_PARSE_FAILED', 'message': 'Split could not read that reliably. Please enter it by hand.'}},
          ),
        ));
    final c = _container(api);
    await c.read(scanControllerProvider.notifier).read([_photo]);
    expect(
      c.read(scanControllerProvider),
      isA<ScanFailed>().having((s) => s.message, 'message', 'Split could not read that reliably. Please enter it by hand.'),
    );
  });

  test('a second read while one is in flight does not scan twice', () async {
    final gate = Completer<Split>();
    final api = _FakeApi(() => gate.future);
    final c = _container(api);
    final first = c.read(scanControllerProvider.notifier).read([_photo]);
    await c.read(scanControllerProvider.notifier).read([_photo]);
    expect(api.scans, hasLength(1));
    gate.complete(const Split(id: 's1'));
    await first;
  });

  test('reset goes back to idle', () async {
    final c = _container(_FakeApi(() async => const Split(id: 's1')));
    await c.read(scanControllerProvider.notifier).read([_photo]);
    c.read(scanControllerProvider.notifier).reset();
    expect(c.read(scanControllerProvider), isA<ScanIdle>());
  });
}
