import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/people_screen.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

const _kemi = Participant(id: 'kemi', name: 'Kemi', isOrganiser: true);

/// Stands in for the API and Firestore at once: a write changes the list
/// and the change comes back on the stream, as the real listener would.
class _Api implements SplitsApi {
  _Api(this.people);
  final StreamController<List<Participant>> people;
  var current = <Participant>[_kemi];
  final opened = <String>[];

  void _emit() => people.add(List.of(current));

  @override
  Future<void> addPeople(String splitId, List<String> names) async {
    for (final n in names) {
      current.add(Participant(id: n.toLowerCase(), name: n, colourIndex: current.length, joinOrder: current.length));
    }
    _emit();
  }

  @override
  Future<void> removePerson(String splitId, String participantId) async {
    current.removeWhere((p) => p.id == participantId);
    _emit();
  }

  @override
  Future<OpenedSplit> open(String splitId) async {
    opened.add(splitId);
    return (
      links: [for (final p in current.where((p) => !p.isOrganiser)) (participantId: p.id, name: p.name, url: 'https://x/v1/s/${p.id}')],
      groupMessage: 'Friday dinner at Little Bao House. Tap your link and say what you had:\n'
          '${current.where((p) => !p.isOrganiser).map((p) => '${p.name}: https://x/v1/s/${p.id}').join('\n')}',
    );
  }

  @override
  Future<SplitDoc> createEmpty() => throw UnimplementedError();

  @override
  Future<SplitDoc> scan(List<Photo> photos) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();

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
String? _copied;

Future<void> _pump(WidgetTester tester) async {
  final people = StreamController<List<Participant>>.broadcast();
  _api = _Api(people);
  _copied = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _copied = (call.arguments as Map)['text'] as String;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  final router = GoRouter(initialLocation: '/split/s1/people', routes: [
    GoRoute(path: '/split/:id/people', builder: (_, s) => PeopleScreen(splitId: s.pathParameters['id']!)),
    GoRoute(path: '/split/:id/claims', builder: (_, _) => const Text('claims-route')),
  ]);
  // The test font draws every glyph as a square, so the 26-character button
  // label needs more than a phone's width here. Real fonts fit 390.
  await tester.binding.setSurfaceSize(const Size(600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      splitProvider('s1').overrideWith((ref) => Stream.value(const SplitDoc(id: 's1', title: 'Friday dinner'))),
      participantsProvider('s1').overrideWith((ref) => people.stream),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(theme: splitTheme(), routerConfig: router),
  ));
  await tester.pump();
  people.add(List.of(_api.current));
  await tester.pumpAndSettle();
}

Future<void> _addName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('person-name')), name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

FilledButton _ask(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Ask everyone what they had'), matching: find.byType(FilledButton)),
    );

void main() {
  testWidgets('starts with the organiser in, not removable, and nothing to send', (tester) async {
    await _pump(tester);
    expect(find.text('Who was there?'), findsOneWidget);
    expect(find.text('You, paid the bill'), findsOneWidget);
    expect(find.byTooltip('Remove Kemi'), findsNothing);
    expect(_ask(tester).enabled, isFalse);
  });

  testWidgets('add three names, remove one, then open shows the copy sheet', (tester) async {
    await _pump(tester);
    for (final n in ['Amaka', 'Josh', 'Dan']) {
      await _addName(tester, n);
    }
    expect(find.byKey(const Key('person-Josh')), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Josh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-Josh')), findsNothing);
    expect(_api.current.map((p) => p.name), ['Kemi', 'Amaka', 'Dan']);

    await tester.tap(find.text('Ask everyone what they had'));
    await tester.pumpAndSettle();
    expect(_api.opened, ['s1']);
    expect(find.text('Send this to the group'), findsOneWidget);
    expect(find.textContaining('Amaka: https://x/v1/s/amaka'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(_copied, startsWith('Friday dinner at Little Bao House.'));
    expect(_copied, contains('Dan: https://x/v1/s/dan'));
    expect(find.text('claims-route'), findsOneWidget);
    // Let the "Copied" toast time out before the test ends.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('a blank name adds nobody', (tester) async {
    await _pump(tester);
    await _addName(tester, '   ');
    expect(_api.current, hasLength(1));
  });
}
