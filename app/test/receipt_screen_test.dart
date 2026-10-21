import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/receipt_screen.dart';
import 'package:split/models/ambiguity.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

/// The scan response for the Little Bao House photo, with Lager misread as
/// £15.60, so it arrives with a blocking mismatch and a model note.
final _misread = SplitDoc.fromJson(
  (jsonDecode(File('test/fixtures/scan-response.json').readAsStringSync()) as Map)['split'] as Map<String, dynamic>,
);

/// The same bill once fixed: Lager at £16.50, nothing in the way.
final _fixed = _misread.copyWith(
  receipt: _misread.receipt.copyWith(lines: [
    for (final l in _misread.receipt.lines) l.id == 'lager-8' ? l.copyWith(lineTotalMinor: 1650) : l,
  ]),
  receiptAmbiguities: const [],
);

class _RecordingApi implements SplitsApi {
  final receiptPatches = <Map<String, Object?>>[];
  final rulesPatches = <Map<String, Object?>>[];

  @override
  Future<SplitDoc> scan(List<Photo> photos) => throw UnimplementedError();

  @override
  Future<SplitDoc> createEmpty() => throw UnimplementedError();

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) async {
    receiptPatches.add(body);
    return _fixed;
  }

  @override
  Future<void> addPeople(String splitId, List<String> names) => throw UnimplementedError();

  @override
  Future<void> removePerson(String splitId, String participantId) => throw UnimplementedError();

  @override
  Future<OpenedSplit> open(String splitId) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) async {
    rulesPatches.add(body);
    return _fixed;
  }
}

late StreamController<SplitDoc?> _stream;
late _RecordingApi _api;

Future<void> _pump(WidgetTester tester, SplitDoc split) async {
  _stream = StreamController<SplitDoc?>();
  _api = _RecordingApi();
  final router = GoRouter(initialLocation: '/split/${split.id}/receipt', routes: [
    GoRoute(path: '/split/:id/receipt', builder: (_, s) => ReceiptScreen(splitId: s.pathParameters['id']!)),
    GoRoute(path: '/split/:id/people', builder: (_, _) => const Text('people-route')),
  ]);
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider(split.id).overrideWith((ref) => _stream.stream),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  _stream.add(split);
  await tester.pumpAndSettle();
}

FilledButton _addPeople(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Add people'), matching: find.byType(FilledButton)),
    );

void main() {
  testWidgets('lists every line as printed, with the date and count', (tester) async {
    await _pump(tester, _fixed);
    expect(find.text('Check the bill'), findsOneWidget);
    expect(find.text('Little Bao House'), findsOneWidget);
    expect(find.text('Fri 2 Oct. Split read 10 items.'), findsOneWidget);
    expect(find.text('Pork bao'), findsOneWidget);
    expect(find.text('£18.00'), findsOneWidget);
    expect(find.text('£154.69'), findsOneWidget);
    expect(_addPeople(tester).enabled, isTrue);
  });

  testWidgets("shows the server's mismatch sentence and holds Add people", (tester) async {
    await _pump(tester, _misread);
    expect(find.text('Items add up to £153.79 but the bill says £154.69. Check the photo or edit a line.'), findsOneWidget);
    expect(_addPeople(tester).enabled, isFalse);
    // The model's own question is shown, but quietly and without blocking.
    expect(find.text(_misread.notes.single.question), findsOneWidget);
  });

  testWidgets('fixing a line sends only what changed, then the fix lands from the stream', (tester) async {
    await _pump(tester, _misread);
    await tester.tap(find.text('Lager'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('line-price')), '16.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_api.receiptPatches.single, {
      'lines': [{'id': 'lager-8', 'lineTotalMinor': 1650}],
    });
    _stream.add(_fixed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Items add up to'), findsNothing);
    expect(_addPeople(tester).enabled, isTrue);
  });

  testWidgets('a price that is not money is refused before it is sent', (tester) async {
    await _pump(tester, _fixed);
    await tester.tap(find.text('Lager'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('line-price')), '16,5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_api.receiptPatches, isEmpty);
    expect(find.text('Enter an amount like 16.50'), findsOneWidget);
  });

  testWidgets('a line can be added and removed', (tester) async {
    await _pump(tester, _fixed);
    await tester.tap(find.text('Add a line'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('line-name')), 'Edamame');
    await tester.enterText(find.byKey(const Key('line-price')), '4.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_api.receiptPatches.last, {
      'addLines': [{'name': 'Edamame', 'qty': 1, 'lineTotalMinor': 450}],
    });
    await tester.tap(find.text('Lemonade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove this line'));
    await tester.pumpAndSettle();
    expect(_api.receiptPatches.last, {'removeLineIds': ['lemonade-9']});
  });

  testWidgets('choosing Evenly sends the service mode', (tester) async {
    await _pump(tester, _fixed);
    expect(find.text('Found a 12.5% service charge (£17.19). Split it by what each person had?'), findsOneWidget);
    await tester.tap(find.text('Evenly'));
    await tester.pumpAndSettle();
    expect(_api.rulesPatches.single, {'serviceMode': 'even'});
  });

  testWidgets('no service charge, no service card', (tester) async {
    await _pump(tester, _fixed.copyWith(receipt: _fixed.receipt.copyWith(serviceChargeMinor: 0, serviceChargeLabel: null)));
    expect(find.text('Evenly'), findsNothing);
  });

  testWidgets('an unread price says so, never £0.00, and blocks', (tester) async {
    final unread = _fixed.copyWith(
      receipt: _fixed.receipt.copyWith(lines: [
        for (final l in _fixed.receipt.lines) l.id == 'lager-8' ? l.copyWith(lineTotalMinor: null) : l,
      ]),
      receiptAmbiguities: const [
        Ambiguity(field: 'lines.lager-8.lineTotalMinor', kind: 'missing', question: 'What did the Lager cost? Split could not read the price.'),
      ],
    );
    await _pump(tester, unread);
    expect(find.text('Add price'), findsOneWidget);
    expect(find.text('£0.00'), findsNothing);
    expect(_addPeople(tester).enabled, isFalse);
    // Tapping the question opens that line.
    await tester.tap(find.text('What did the Lager cost? Split could not read the price.'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('line-price')), findsOneWidget);
  });

  testWidgets('an unread total can be typed in', (tester) async {
    final noTotal = _fixed.copyWith(
      receipt: _fixed.receipt.copyWith(printedTotalMinor: null),
      receiptAmbiguities: const [
        Ambiguity(field: 'printedTotalMinor', kind: 'missing', question: 'Split could not read the total. What does the bill say?'),
      ],
    );
    await _pump(tester, noTotal);
    await tester.tap(find.text('Split could not read the total. What does the bill say?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('total-price')), '154.69');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_api.receiptPatches.single, {'printedTotalMinor': 15469});
  });

  group('typed in from blank', () {
    // What POST /v1/splits returns: no lines, no total, two questions.
    final blank = _fixed.copyWith(
      merchant: null,
      receiptDate: null,
      receipt: _fixed.receipt.copyWith(lines: const [], serviceChargeMinor: 0, printedTotalMinor: null),
      receiptAmbiguities: const [
        Ambiguity(field: 'lines', kind: 'missing', question: 'Add the items on the bill.'),
        Ambiguity(field: 'printedTotalMinor', kind: 'missing', question: "What's the total on the bill?"),
      ],
    );

    testWidgets('asks for the items and the total, and holds Add people', (tester) async {
      await _pump(tester, blank);
      expect(find.text('Add each item on the bill.'), findsOneWidget);
      expect(find.text("What's the total on the bill?"), findsOneWidget);
      expect(find.text('Add the total'), findsOneWidget);
      expect(_addPeople(tester).enabled, isFalse);
    });

    testWidgets('adding two lines and a total clears the questions', (tester) async {
      await _pump(tester, blank);
      Future<void> addLine(String name, String qty, String price) async {
        await tester.tap(find.text('Add a line'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('line-name')), name);
        await tester.enterText(find.byKey(const Key('line-qty')), qty);
        await tester.enterText(find.byKey(const Key('line-price')), price);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await addLine('Ramen', '1', '15.00');
      await addLine('Lager', '2', '11.00');
      await tester.tap(find.byKey(const Key('printed-total')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('total-price')), '26.00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_api.receiptPatches, [
        {'addLines': [{'name': 'Ramen', 'qty': 1, 'lineTotalMinor': 1500}]},
        {'addLines': [{'name': 'Lager', 'qty': 2, 'lineTotalMinor': 1100}]},
        {'printedTotalMinor': 2600},
      ]);

      _stream.add(blank.copyWith(
        receipt: blank.receipt.copyWith(lines: [
          _fixed.receipt.lines.first.copyWith(id: 'ramen-0', name: 'Ramen', qty: 1, lineTotalMinor: 1500),
          _fixed.receipt.lines.first.copyWith(id: 'lager-1', name: 'Lager', qty: 2, lineTotalMinor: 1100),
        ], printedTotalMinor: 2600),
        receiptAmbiguities: const [],
      ));
      await tester.pumpAndSettle();
      expect(find.text("What's the total on the bill?"), findsNothing);
      expect(find.text('Add the items on the bill.'), findsNothing);
      expect(find.text('£26.00'), findsOneWidget);
      expect(_addPeople(tester).enabled, isTrue);
    });

    testWidgets('tapping the items question opens an empty line', (tester) async {
      await _pump(tester, blank);
      await tester.tap(find.text('Add the items on the bill.'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('line-name')), findsOneWidget);
    });
  });

  testWidgets('Add people goes to People', (tester) async {
    await _pump(tester, _fixed);
    await tester.tap(find.text('Add people'));
    await tester.pumpAndSettle();
    expect(find.text('people-route'), findsOneWidget);
  });
}
