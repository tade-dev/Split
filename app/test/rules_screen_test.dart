import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/rules_screen.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/receipt.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

const _people = [
  Participant(id: 'kemi', name: 'Kemi', isOrganiser: true),
  Participant(id: 'josh', name: 'Josh', colourIndex: 1, joinOrder: 1),
  Participant(id: 'sam', name: 'Sam', colourIndex: 2, joinOrder: 2),
];

SplitDoc _split({Rules rules = const Rules(), bool ok = true}) => SplitDoc(
      id: 's1',
      title: 'Friday dinner',
      status: 'claiming',
      receipt: const Receipt(
        lines: [ReceiptLine(id: 'crackers-0', name: 'Prawn crackers', qty: 1, lineTotalMinor: 550)],
        serviceChargeMinor: 300,
        serviceChargeLabel: '12.5%',
      ),
      claims: const {
        'crackers-0': LineClaims(claims: [
          Claim(participantId: 'kemi'),
          Claim(participantId: 'josh'),
          Claim(participantId: 'sam'),
        ]),
      },
      rules: rules,
      computed: Computed(ok: ok, perParticipant: {
        'kemi': const Breakdown(lines: [BreakdownLine(lineId: 'crackers-0', minor: 183)]),
        'josh': const Breakdown(lines: [BreakdownLine(lineId: 'crackers-0', minor: 183)]),
        'sam': Breakdown(
          lines: const [BreakdownLine(lineId: 'crackers-0', minor: 183)],
          sharedFromOnUsMinor: rules.onUs.contains('sam') ? -183 : 0,
        ),
      }),
    );

class _Api implements SplitsApi {
  final rulePatches = <Map<String, Object?>>[];
  RulesPreview next = (rules: null, confirmationText: null, figureMinor: null, message: "I didn't catch a rule in that. Try 'Sam's on us'.");

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) async {
    rulePatches.add(body);
    return _split();
  }

  @override
  Future<RulesPreview> rulesMessage(String splitId, String message) async => next;

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

  @override
  Future<void> lock(String splitId) => throw UnimplementedError();

  @override
  Future<void> unlock(String splitId) => throw UnimplementedError();
}

late _Api _api;
late StreamController<SplitDoc?> _splits;

Future<void> _pump(WidgetTester tester, SplitDoc split) async {
  _api = _Api();
  _splits = StreamController<SplitDoc?>.broadcast();
  final router = GoRouter(initialLocation: '/split/s1/rules', routes: [
    GoRoute(path: '/split/:id/rules', builder: (_, s) => RulesScreen(splitId: s.pathParameters['id']!)),
    GoRoute(path: '/split/:id/breakdown', builder: (_, _) => const Text('breakdown-route')),
  ]);
  // The test font draws every glyph as a square; real fonts fit 390.
  await tester.binding.setSurfaceSize(const Size(700, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider('s1').overrideWith((ref) => _splits.stream),
      participantsProvider('s1').overrideWith((ref) => Stream.value(_people)),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  await tester.pump();
  _splits.add(split);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists shared lines with the amounts from computed', (tester) async {
    await _pump(tester, _split());
    expect(find.text('Prawn crackers, £5.50'), findsOneWidget);
    expect(find.text('Shared by all 3, £1.83 each'), findsOneWidget);
    expect(find.text("Sam's on us"), findsOneWidget);
    expect(find.text('Pays for what they had'), findsNWidgets(2));
    expect(find.text("Kemi's on us"), findsNothing);
  });

  testWidgets('the on-us switch patches the rules and the row says who covers it', (tester) async {
    await _pump(tester, _split());
    await tester.tap(find.byKey(const Key('on-us-sam')));
    await tester.pumpAndSettle();
    expect(_api.rulePatches, [
      {'onUs': ['sam']},
    ]);
    _splits.add(_split(rules: const Rules(onUs: ['sam'])));
    await tester.pumpAndSettle();
    expect(find.text('£1.83 covered by the other 2'), findsOneWidget);
  });

  testWidgets('Evenly patches the service mode', (tester) async {
    await _pump(tester, _split());
    expect(find.text('Service charge, 12.5%'), findsOneWidget);
    await tester.tap(find.text('Evenly'));
    await tester.pumpAndSettle();
    expect(_api.rulePatches, [
      {'serviceMode': 'even'},
    ]);
  });

  testWidgets('a typed rule shows as a confirm card and Yes applies it', (tester) async {
    await _pump(tester, _split());
    _api.next = (
      rules: const Rules(onUs: ['sam']),
      confirmationText: "Sam's share, £29.10, split between the other 4?",
      figureMinor: 2910,
      message: null,
    );
    await tester.enterText(find.byKey(const Key('rules-message')), "it's Sam's birthday so his is on us");
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text("Sam's share, £29.10, split between the other 4?"), findsOneWidget);
    expect(_api.rulePatches, isEmpty);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(_api.rulePatches.single, {
      'serviceMode': 'proportional',
      'onUs': ['sam'],
      'onUsPaidBy': null,
      'serviceOptOut': <String>[],
    });
    expect(find.byKey(const Key('rules-confirm')), findsNothing);
  });

  testWidgets('says so when no rule was caught', (tester) async {
    await _pump(tester, _split());
    await tester.enterText(find.byKey(const Key('rules-message')), 'lovely evening');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text("I didn't catch a rule in that. Try 'Sam's on us'."), findsOneWidget);
  });

  testWidgets('Work out the totals waits for the bill to add up', (tester) async {
    await _pump(tester, _split(ok: false));
    final button = find.ancestor(of: find.text('Work out the totals'), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(button).enabled, isFalse);
    _splits.add(_split());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work out the totals'));
    await tester.pumpAndSettle();
    expect(find.text('breakdown-route'), findsOneWidget);
  });
}
