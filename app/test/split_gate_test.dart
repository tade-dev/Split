import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/features/split/split_gate.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

Future<void> _pump(WidgetTester tester, Stream<SplitDoc?> Function() stream) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [splitProvider('s1').overrideWith((ref) => stream())],
    child: MaterialApp(
      theme: splitTheme(),
      home: const SplitGate(splitId: 's1', child: Text('the screen')),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the screen for a bill that is there', (tester) async {
    await _pump(tester, () => Stream.value(const SplitDoc(id: 's1', status: 'claiming')));
    expect(find.text('the screen'), findsOneWidget);
  });

  testWidgets('shows the screen while the bill is still loading', (tester) async {
    await _pump(tester, () => const Stream<SplitDoc?>.empty());
    expect(find.text('the screen'), findsOneWidget);
  });

  testWidgets('a bill that is not there says so', (tester) async {
    await _pump(tester, () => Stream.value(null));
    expect(find.byKey(const Key('split-missing')), findsOneWidget);
    expect(find.text('the screen'), findsNothing);
  });

  testWidgets('a cancelled bill says so', (tester) async {
    await _pump(tester, () => Stream.value(const SplitDoc(id: 's1', title: 'Friday dinner', status: 'cancelled')));
    expect(find.text('Friday dinner was cancelled'), findsOneWidget);
  });

  testWidgets('a bill that could not load offers to try again', (tester) async {
    var calls = 0;
    await _pump(tester, () {
      calls++;
      return Stream.error(Exception('offline'));
    });
    expect(find.byKey(const Key('split-error')), findsOneWidget);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
  });
}
