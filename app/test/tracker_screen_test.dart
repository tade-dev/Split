import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/motion/paid_announcer.dart';
import 'package:split/core/motion/paid_pop.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/features/split/tracker_screen.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';
import 'package:split/widgets/settled_stamp.dart';

const _split = SplitDoc(
  id: 's1',
  title: 'Friday dinner',
  status: 'collecting',
  links: {'dan': 'https://split-api-k5ai.onrender.com/v1/s/kemi/s1/dan/sig'},
);

final _people = [
  const Participant(id: 'kemi', name: 'Kemi', isOrganiser: true, status: 'on_us', shareMinor: 3643),
  Participant(id: 'amaka', name: 'Amaka', colourIndex: 1, joinOrder: 1, status: 'paid', shareMinor: 3361, paidAt: DateTime(2026, 10, 30, 21, 14)),
  Participant(id: 'josh', name: 'Josh', colourIndex: 2, joinOrder: 2, status: 'paid', shareMinor: 4542, paidAt: DateTime(2026, 10, 30, 21, 40)),
  const Participant(id: 'dan', name: 'Dan', colourIndex: 3, joinOrder: 3, status: 'link_opened', shareMinor: 3923),
  const Participant(id: 'sam', name: 'Sam', colourIndex: 4, joinOrder: 4, status: 'on_us', shareMinor: 0),
];

List<Participant> _with(String id, String status) => [
      for (final p in _people) p.id == id ? p.copyWith(status: status, paidAt: DateTime(2026, 10, 30, 21, 52)) : p,
    ];

late StreamController<SplitDoc?> _splits;
late StreamController<List<Participant>> _participants;
late List<String> _announced;
late int _buzzes;
late List<Uri> _opened;
late _Api _api;

class _Api implements SplitsApi {
  final cash = <String>[];

  @override
  Future<void> markPaidCash(String splitId, String participantId) async => cash.add(participantId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester) async {
  _splits = StreamController<SplitDoc?>.broadcast();
  _participants = StreamController<List<Participant>>.broadcast();
  _announced = [];
  _buzzes = 0;
  _opened = [];
  _api = _Api();
  await tester.binding.setSurfaceSize(const Size(700, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider('s1').overrideWith((ref) => _splits.stream),
      participantsProvider('s1').overrideWith((ref) => _participants.stream),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp(
      theme: splitTheme(),
      home: TrackerScreen(
        splitId: 's1',
        announcer: PaidAnnouncer(haptic: () => _buzzes++, announce: _announced.add),
        openLink: (u) async => _opened.add(u),
      ),
    ),
  ));
  await tester.pump();
  _splits.add(_split);
  _participants.add(_people);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows what has come back and where each share stands', (tester) async {
    await _pump(tester);
    expect(find.text('Getting paid back'), findsOneWidget);
    expect(find.text('of £118.26'), findsOneWidget);
    expect(find.text('Paid at 9:14pm'), findsOneWidget);
    expect(find.text('Opened the link, not paid yet'), findsOneWidget);
    expect(find.text('Nothing to pay'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    // Biggest share first: Josh, Dan, Amaka, then Sam, then the organiser.
    final ys = [for (final id in ['josh', 'dan', 'amaka', 'sam', 'kemi']) tester.getTopLeft(find.byKey(Key('row-$id'))).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.byType(SettledStamp), findsNothing);
  });

  testWidgets('Dan flips to Paid live, with one pop and one announcement', (tester) async {
    await _pump(tester);
    expect(_announced, isEmpty, reason: 'shares already paid when the screen opened are history');

    _participants.add(_with('dan', 'paid'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Mid-pop: the row is wrapped in the swell animation.
    expect(find.descendant(of: find.byType(PaidPop), matching: find.byType(Animate)), findsOneWidget);
    final pop = tester.widget<PaidPop>(find.ancestor(of: find.byKey(const Key('row-dan')), matching: find.byType(PaidPop)));
    expect(pop.paid, isTrue);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('row-dan')), matching: find.text('Paid')), findsOneWidget);
    expect(_announced, ['Dan paid £39.23']);
    expect(_buzzes, 1);

    // The stream replaying the same snapshot announces nothing new.
    _participants.add(_with('dan', 'paid'));
    await tester.pumpAndSettle();
    expect(_announced, hasLength(1));
  });

  testWidgets('the Settled stamp lands when the last share does', (tester) async {
    await _pump(tester);
    _participants.add(_with('dan', 'paid'));
    _splits.add(_split.copyWith(status: 'settled'));
    await tester.pumpAndSettle();
    expect(find.byType(SettledStamp), findsOneWidget);
    expect(find.text('Everyone has paid'), findsOneWidget);
  });

  testWidgets("a row's menu previews the friend's page", (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('menu-josh')), findsNothing, reason: 'Josh has paid and has no cached link');
    await tester.tap(find.byKey(const Key('menu-dan')));
    await tester.pumpAndSettle();
    expect(find.text('Copy link'), findsOneWidget);
    await tester.tap(find.text('Preview as Dan'));
    await tester.pumpAndSettle();
    expect(_opened, [Uri.parse('https://split-api-k5ai.onrender.com/v1/s/kemi/s1/dan/sig')]);
  });

  test('clock times read the way the design writes them', () {
    expect(clockTime(DateTime(2026, 10, 30, 21, 4)), '9:04pm');
    expect(clockTime(DateTime(2026, 10, 30, 0, 30)), '12:30am');
    expect(clockTime(DateTime(2026, 10, 30, 12, 0)), '12:00pm');
  });

  testWidgets('a share paid another way can be marked paid in cash, after a confirm', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('menu-dan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid in cash'));
    await tester.pumpAndSettle();
    expect(find.text('Mark Dan as paid?'), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(_api.cash, isEmpty);

    await tester.tap(find.byKey(const Key('menu-dan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid in cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();
    expect(_api.cash, ['dan']);
  });
}
