import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/breakdown_screen.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/receipt.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

const _people = [
  Participant(id: 'kemi', name: 'Kemi', isOrganiser: true),
  Participant(id: 'amaka', name: 'Amaka', colourIndex: 1, joinOrder: 1),
  Participant(id: 'josh', name: 'Josh', colourIndex: 2, joinOrder: 2),
  Participant(id: 'dan', name: 'Dan', colourIndex: 3, joinOrder: 3),
  Participant(id: 'sam', name: 'Sam', colourIndex: 4, joinOrder: 4),
];

/// The golden fixture's figures (spec §3).
SplitDoc _split({String status = 'claiming'}) => SplitDoc(
      id: 's1',
      status: status,
      receipt: const Receipt(
        lines: [
          ReceiptLine(id: 'beef-ramen-4', name: 'Beef ramen', qty: 1, lineTotalMinor: 1500),
          ReceiptLine(id: 'lager-8', name: 'Lager', qty: 3, lineTotalMinor: 1650),
          ReceiptLine(id: 'prawn-crackers-0', name: 'Prawn crackers', qty: 1, lineTotalMinor: 550),
        ],
        serviceChargeLabel: '12.5%',
      ),
      rules: const Rules(onUs: ['sam']),
      computed: const Computed(ok: true, totalMinor: 15469, perParticipant: {
        'kemi': Breakdown(finalMinor: 3643, lines: [BreakdownLine(lineId: 'prawn-crackers-0', minor: 110, portionLabel: 'share')]),
        'amaka': Breakdown(finalMinor: 3361),
        'josh': Breakdown(
          finalMinor: 4542,
          sharedFromOnUsMinor: 727,
          serviceMinor: 505,
          lines: [
            BreakdownLine(lineId: 'beef-ramen-4', minor: 1500),
            BreakdownLine(lineId: 'lager-8', minor: 1100, portionLabel: '2 of 3'),
            BreakdownLine(lineId: 'prawn-crackers-0', minor: 110, portionLabel: 'share'),
          ],
        ),
        'dan': Breakdown(finalMinor: 3923),
        'sam': Breakdown(finalMinor: 0, sharedFromOnUsMinor: -2910),
      }),
    );

class _Api implements SplitsApi {
  final calls = <String>[];

  @override
  Future<void> lock(String splitId) async => calls.add('lock');
  @override
  Future<void> unlock(String splitId) async => calls.add('unlock');

  @override
  Future<RulesPreview> rulesMessage(String splitId, String message) => throw UnimplementedError();
  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();
  @override
  Future<ClaimResult> claimMessage(String splitId, String message, {String? participantId}) => throw UnimplementedError();
  @override
  Future<void> patchClaims(String splitId, String lineId, List<Claim> claims, {bool? shared}) => throw UnimplementedError();
  @override
  Future<void> addPeople(String splitId, List<String> names) => throw UnimplementedError();
  @override
  Future<void> removePerson(String splitId, String participantId) => throw UnimplementedError();
  @override
  Future<OpenedSplit> open(String splitId) => throw UnimplementedError();
  @override
  Future<SplitDoc> createEmpty() => throw UnimplementedError();
  @override
  Future<SplitDoc> scan(List<Photo> photos) => throw UnimplementedError();
  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();
}

late _Api _api;

Future<void> _pump(WidgetTester tester, SplitDoc split) async {
  _api = _Api();
  final router = GoRouter(initialLocation: '/split/s1/breakdown', routes: [
    GoRoute(path: '/split/:id/breakdown', builder: (_, s) => BreakdownScreen(splitId: s.pathParameters['id']!)),
    GoRoute(path: '/split/:id', builder: (_, _) => const Text('tracker-route')),
  ]);
  // The test font draws every glyph as a square; real fonts fit 390.
  await tester.binding.setSurfaceSize(const Size(700, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider('s1').overrideWith((ref) => Stream.value(split)),
      participantsProvider('s1').overrideWith((ref) => Stream.value(_people)),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('orders payers by share, then the organiser, then on us', (tester) async {
    await _pump(tester, _split());
    final ys = [for (final id in ['josh', 'dan', 'amaka', 'kemi', 'sam']) tester.getTopLeft(find.byKey(Key('person-$id'))).dy];
    expect([...ys]..sort(), ys);
    expect(find.text('£45.42'), findsOneWidget);
    expect(find.text('You, already paid'), findsOneWidget);
    expect(find.text('On us'), findsOneWidget);
    expect(find.text('£154.69'), findsOneWidget);
  });

  testWidgets('a row opens to its lines and the rules', (tester) async {
    await _pump(tester, _split());
    await tester.tap(find.text('Josh'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to hide details'), findsOneWidget);
    expect(find.text('Lager, 2 of 3'), findsOneWidget);
    expect(find.text('Prawn crackers share'), findsOneWidget);
    expect(find.text("Share of what's on the group"), findsOneWidget);
    expect(find.text('£7.27'), findsOneWidget);
    expect(find.text('Service charge, 12.5%'), findsOneWidget);
  });

  testWidgets('Send links locks for the amount owed and goes to the tracker', (tester) async {
    await _pump(tester, _split());
    await tester.tap(find.text('Send links for £118.26'));
    await tester.pumpAndSettle();
    expect(_api.calls, ['lock']);
    expect(find.text('tracker-route'), findsOneWidget);
  });

  testWidgets('once locked it offers the tracker and an unlock', (tester) async {
    await _pump(tester, _split(status: 'collecting'));
    expect(find.text('See who has paid'), findsOneWidget);
    await tester.tap(find.text('Unlock to change something'));
    await tester.pumpAndSettle();
    expect(_api.calls, ['unlock']);
  });
}
