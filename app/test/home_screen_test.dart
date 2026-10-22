import 'dart:async';

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
    GoRoute(path: '/split/:id', builder: (_, s) => Text('tracker ${s.pathParameters['id']}')),
  ]);
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      bootstrapProvider.overrideWith((ref) async {}),
      organiserProvider.overrideWith((ref) => Stream.value(const Organiser(id: 'kemi', displayName: 'Kemi'))),
      splitsProvider.overrideWith((ref) => Stream.value(splits)),
      participantsProvider.overrideWith((ref, splitId) => Stream.value(switch (splitId) {
            'brunch' => [for (final n in ['Kemi', 'Tom', 'Priya', 'Ade']) Participant(id: n, name: n)],
            'dinner' => const [
                Participant(id: 'kemi', name: 'Kemi', isOrganiser: true, status: 'on_us', shareMinor: 3643),
                Participant(id: 'amaka', name: 'Amaka', status: 'paid', shareMinor: 3361),
                Participant(id: 'josh', name: 'Josh', status: 'paid', shareMinor: 4542),
                Participant(id: 'dan', name: 'Dan', status: 'link_opened', shareMinor: 3923),
                Participant(id: 'sam', name: 'Sam', status: 'on_us', shareMinor: 0),
              ],
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

  testWidgets('a collecting bill shows what has come back, and opens the tracker', (tester) async {
    await _pump(tester, [_bao.copyWith(id: 'dinner', status: 'collecting')]);
    expect(find.text('£79.03 of £118.26 back'), findsOneWidget);
    expect(find.text('Waiting on Dan'), findsOneWidget);
    await tester.tap(find.text('£79.03 of £118.26 back'));
    await tester.pumpAndSettle();
    expect(find.text('tracker dinner'), findsOneWidget);
  });

  testWidgets('a first visit shows placeholders, not a bare Hi, until the organiser arrives', (tester) async {
    final organiser = StreamController<Organiser?>();
    final bootstrap = Completer<void>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWith((ref) => bootstrap.future),
        organiserProvider.overrideWith((ref) => organiser.stream),
        splitsProvider.overrideWith((ref) => const Stream<List<SplitDoc>>.empty()),
      ],
      child: MaterialApp(theme: splitTheme(), home: const HomeScreen()),
    ));
    await tester.pump();
    expect(find.byKey(const Key('greeting-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('summary-skeleton')), findsOneWidget);
    expect(find.text('Hi'), findsNothing);

    organiser.add(const Organiser(id: 'kemi', displayName: 'Kemi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hi Kemi'), findsOneWidget);
    expect(find.byKey(const Key('greeting-skeleton')), findsNothing);
    bootstrap.complete();
    await organiser.close();
  });

  testWidgets('if bootstrap finishes with no name, it still says Hi', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWith((ref) async {}),
        organiserProvider.overrideWith((ref) => Stream.value(null)),
        splitsProvider.overrideWith((ref) => Stream.value(const <SplitDoc>[])),
      ],
      child: MaterialApp(theme: splitTheme(), home: const HomeScreen()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hi'), findsOneWidget);
    expect(find.byKey(const Key('summary-skeleton')), findsNothing);
  });
}
