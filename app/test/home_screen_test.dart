import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/home/home_screen.dart';
import 'package:split/models/organiser.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/organiser_provider.dart';
import 'package:split/providers/splits_providers.dart';

final _bao = SplitDoc.fromJson(
  (jsonDecode(File('test/fixtures/scan-response.json').readAsStringSync()) as Map)['split'] as Map<String, dynamic>,
).copyWith(title: 'Friday dinner', receiptAmbiguities: const []);

const _brunch = SplitDoc(id: 'brunch', title: 'Sunday brunch', receiptDate: '2026-09-27', status: 'settled');

class _Api implements SplitsApi {
  final scans = <List<Photo>>[];

  @override
  Future<SplitDoc> scan(List<Photo> photos) async {
    scans.add(photos);
    return _bao;
  }

  @override
  Future<SplitDoc> createEmpty() => throw UnimplementedError();

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();
}

late _Api _api;
const _sample = (bytes: <int>[1, 2, 3], filename: 'little-bao-house.png');

Future<void> _pump(WidgetTester tester, List<SplitDoc> splits) async {
  _api = _Api();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/scan', builder: (_, _) => const Text('scan-route')),
    GoRoute(path: '/split/reading', builder: (_, _) => const Text('reading-route')),
    GoRoute(path: '/split/:id/receipt', builder: (_, s) => Text('receipt ${s.pathParameters['id']}')),
  ]);
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      organiserProvider.overrideWith((ref) => Stream.value(const Organiser(id: 'kemi', displayName: 'Kemi'))),
      splitsProvider.overrideWith((ref) => Stream.value(splits)),
      participantsProvider.overrideWith((ref, splitId) => Stream.value(switch (splitId) {
            'brunch' => [for (final n in ['Kemi', 'Tom', 'Priya', 'Ade']) Participant(id: n, name: n)],
            _ => const [Participant(id: 'kemi', name: 'Kemi', isOrganiser: true)],
          })),
      splitsApiProvider.overrideWithValue(_api),
      sampleBillProvider.overrideWithValue(() async => _sample),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('greets the organiser by the name friends see', (tester) async {
    await _pump(tester, [_bao]);
    expect(find.text('Hi Kemi'), findsOneWidget);
  });

  testWidgets('a draft bill is the card, with its total, and opens its receipt', (tester) async {
    await _pump(tester, [_bao]);
    expect(find.text('Friday dinner, Little Bao House'), findsOneWidget);
    expect(find.text('£154.69'), findsOneWidget);
    expect(find.text('Still checking the bill'), findsOneWidget);
    await tester.tap(find.text('£154.69'));
    await tester.pumpAndSettle();
    expect(find.text('receipt ${_bao.id}'), findsOneWidget);
  });

  testWidgets('settled bills are listed with their date and head count', (tester) async {
    await _pump(tester, [_bao, _brunch]);
    expect(find.text('Settled'), findsWidgets);
    expect(find.text('Sunday brunch'), findsOneWidget);
    expect(find.text('Sun 27 Sep, 4 people'), findsOneWidget);
  });

  testWidgets('Split a new bill opens the camera', (tester) async {
    await _pump(tester, [_bao]);
    await tester.tap(find.text('Split a new bill'));
    await tester.pumpAndSettle();
    expect(find.text('scan-route'), findsOneWidget);
  });

  testWidgets('Try a sample bill sends the sample photo to be read, and shows Reading', (tester) async {
    await _pump(tester, [_bao]);
    await tester.tap(find.text('Try a sample bill'));
    await tester.pumpAndSettle();
    expect(_api.scans.single.single.filename, 'little-bao-house.png');
    expect(_api.scans.single.single.bytes, _sample.bytes);
    expect(find.text('reading-route'), findsOneWidget);
  });

  testWidgets('with no bills yet, both ways in are still there', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Friday dinner, Little Bao House'), findsNothing);
    expect(find.text('Split a new bill'), findsOneWidget);
    expect(find.text('Try a sample bill'), findsOneWidget);
  });

  testWidgets('the sample bill really is bundled', (tester) async {
    final data = await tester.runAsync(() => rootBundle.load(sampleBillAsset));
    final png = File('../samples/receipts/little-bao-house.png').readAsBytesSync();
    expect(data!.buffer.asUint8List(), png);
  });
}
