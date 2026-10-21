import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/claims_screen.dart';
import 'package:split/models/ambiguity.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/receipt.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

const _people = [
  Participant(id: 'kemi', name: 'Kemi', isOrganiser: true),
  Participant(id: 'josh', name: 'Josh', colourIndex: 1, joinOrder: 1),
  Participant(id: 'dan', name: 'Dan', colourIndex: 2, joinOrder: 2),
];

const _lines = [
  ReceiptLine(id: 'lager-8', name: 'Lager', qty: 3, lineTotalMinor: 1650),
  ReceiptLine(id: 'ramen-5', name: 'Beef ramen', qty: 1, lineTotalMinor: 1500),
];

SplitDoc _split({Map<String, LineClaims> claims = const {}, List<Ambiguity> problems = const [], bool ok = false}) => SplitDoc(
      id: 's1',
      title: 'Friday dinner',
      status: 'claiming',
      receipt: const Receipt(lines: _lines),
      claims: claims,
      computed: Computed(ok: ok, problems: problems),
    );

const _lagerShort = Ambiguity(
  field: 'claims.lager-8',
  kind: 'unclaimed',
  question: 'Lager: 1 of 3 unclaimed',
  options: ['Share between Josh and Dan', 'Ask the group'],
);
const _ramenNobody = Ambiguity(
  field: 'claims.ramen-5',
  kind: 'unclaimed',
  question: 'Nobody claimed the beef ramen',
  options: ['Share between all 3', 'Ask the group'],
);

class _Api implements SplitsApi {
  final patches = <({String lineId, List<Claim> claims, bool? shared})>[];
  final messages = <String>[];

  @override
  Future<void> patchClaims(String splitId, String lineId, List<Claim> claims, {bool? shared}) async =>
      patches.add((lineId: lineId, claims: claims, shared: shared));

  @override
  Future<ClaimResult> claimMessage(String splitId, String message, {String? participantId}) async {
    messages.add(message);
    return (
      applied: [(lineId: 'ramen-5', participantId: 'dan', name: 'Beef ramen', weight: 1, portionLabel: '')],
      problems: const [
        Ambiguity(field: 'claims', kind: 'unclear', question: 'Who had the gyoza? That name isn\'t in the group.'),
      ],
      ignored: const <String>[],
    );
  }

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
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();
}

late _Api _api;
late StreamController<SplitDoc?> _splits;
late StreamController<List<Participant>> _participants;

Future<void> _pump(WidgetTester tester, SplitDoc split, [List<Participant> people = _people]) async {
  _api = _Api();
  _splits = StreamController<SplitDoc?>.broadcast();
  _participants = StreamController<List<Participant>>.broadcast();
  final router = GoRouter(initialLocation: '/split/s1/claims', routes: [
    GoRoute(path: '/split/:id/claims', builder: (_, s) => ClaimsScreen(splitId: s.pathParameters['id']!)),
    GoRoute(path: '/split/:id/rules', builder: (_, _) => const Text('rules-route')),
  ]);
  // The test font draws every glyph as a square; real fonts fit 390.
  await tester.binding.setSurfaceSize(const Size(700, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider('s1').overrideWith((ref) => _splits.stream),
      participantsProvider('s1').overrideWith((ref) => _participants.stream),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  await tester.pump();
  _splits.add(split);
  _participants.add(people);
  await tester.pumpAndSettle();
}

TextButton _totals(WidgetTester tester) => tester.widget<TextButton>(find.byKey(const Key('totals')));

void main() {
  testWidgets("a friend's confirm shows their message and card without reloading", (tester) async {
    await _pump(tester, _split(problems: const [_ramenNobody]));
    expect(find.text('1 of 2 items claimed'), findsOneWidget);
    expect(find.byKey(const Key('added-josh')), findsNothing);

    _splits.add(_split(
      claims: const {
        'lager-8': LineClaims(claims: [Claim(participantId: 'josh', weight: 2, source: 'friend')]),
      },
      problems: const [_lagerShort, _ramenNobody],
    ));
    _participants.add([
      _people[0],
      _people[1].copyWith(status: 'claimed', claimText: 'two lagers for me', claimedAt: DateTime.utc(2026, 10, 21, 20)),
      _people[2],
    ]);
    await tester.pumpAndSettle();

    expect(find.text('two lagers for me'), findsOneWidget);
    expect(find.byKey(const Key('added-josh')), findsOneWidget);
    expect(find.text('Added to Josh'), findsOneWidget);
    expect(find.text('Lager, 2 of 3'), findsOneWidget);
    expect(find.text('0 of 2 items claimed'), findsOneWidget);
  });

  testWidgets('Share between Josh and Dan keeps their claims and sends shared', (tester) async {
    await _pump(tester, _split(
      claims: const {
        'lager-8': LineClaims(claims: [
          Claim(participantId: 'josh', weight: 1, source: 'friend'),
          Claim(participantId: 'dan', weight: 1, source: 'friend'),
        ]),
      },
      problems: const [_lagerShort],
    ));
    await tester.tap(find.text('Share between Josh and Dan'));
    await tester.pumpAndSettle();
    expect(_api.patches, hasLength(1));
    expect(_api.patches.single.lineId, 'lager-8');
    expect(_api.patches.single.shared, isTrue);
    expect(_api.patches.single.claims.map((c) => c.participantId), ['josh', 'dan']);
  });

  testWidgets('Share between all puts everyone on a line nobody claimed', (tester) async {
    await _pump(tester, _split(problems: const [_ramenNobody]));
    await tester.tap(find.text('Share between all 3'));
    await tester.pumpAndSettle();
    expect(_api.patches.single.claims.map((c) => (c.participantId, c.weight)), [('kemi', 1), ('josh', 1), ('dan', 1)]);
    expect(_api.patches.single.shared, isTrue);
  });

  testWidgets('the composer sends what the organiser typed and shows what came back', (tester) async {
    await _pump(tester, _split(problems: const [_ramenNobody]));
    await tester.enterText(find.byKey(const Key('claim-message')), 'dan had the ramen and the gyoza');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(_api.messages, ['dan had the ramen and the gyoza']);
    expect(find.text('dan had the ramen and the gyoza'), findsOneWidget);
    expect(find.text('Added 1 item'), findsOneWidget);
    expect(find.text("Who had the gyoza? That name isn't in the group."), findsOneWidget);
  });

  testWidgets('Totals waits until nothing is unclaimed', (tester) async {
    await _pump(tester, _split(problems: const [_ramenNobody]));
    expect(_totals(tester).onPressed, isNull);
    _splits.add(_split(
      claims: const {
        'lager-8': LineClaims(claims: [Claim(participantId: 'josh', weight: 3)]),
        'ramen-5': LineClaims(claims: [Claim(participantId: 'dan')]),
      },
      ok: true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 items claimed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('totals')));
    await tester.pumpAndSettle();
    expect(find.text('rules-route'), findsOneWidget);
  });
}
