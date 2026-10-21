import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split/core/motion/split_motion.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/scan/reading_screen.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/splits_providers.dart';

/// The split the API returned for the Little Bao House photo.
final _bao = SplitDoc.fromJson(
  (jsonDecode(File('test/fixtures/scan-response.json').readAsStringSync()) as Map)['split'] as Map<String, dynamic>,
);

class _Controller extends ScanController {
  _Controller(this.initial);
  final ScanState initial;

  @override
  ScanState build() => initial;

  void set(ScanState next) => state = next;
}

class _Api implements SplitsApi {
  _Api(this.blank);
  final SplitDoc blank;
  int created = 0;

  @override
  Future<SplitDoc> createEmpty() async {
    created++;
    return blank;
  }

  @override
  Future<SplitDoc> scan(List<Photo> photos) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchReceipt(String splitId, Map<String, Object?> body) => throw UnimplementedError();

  @override
  Future<SplitDoc> patchRules(String splitId, Map<String, Object?> body) => throw UnimplementedError();
}

late _Controller _controller;
late _Api _api;

Widget _app(ScanState initial, {bool reduce = false}) {
  _controller = _Controller(initial);
  _api = _Api(_bao.copyWith(id: 'blank-1'));
  final router = GoRouter(initialLocation: '/scan', routes: [
    GoRoute(path: '/scan', builder: (_, _) => const Text('scan-route')),
    GoRoute(path: '/split/reading', builder: (_, _) => const ReadingScreen()),
    GoRoute(path: '/split/:id/receipt', builder: (_, s) => Text('receipt ${s.pathParameters['id']}')),
  ]);
  return ProviderScope(
    overrides: [
      scanControllerProvider.overrideWith(() => _controller),
      splitsApiProvider.overrideWithValue(_api),
    ],
    child: MaterialApp.router(
      theme: splitTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: child!,
      ),
    ),
  );
}

Future<void> _openReading(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.text('scan-route')));
  router.push('/split/reading');
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('ticks through the steps while the bill is read, never a spinner alone', (tester) async {
    await tester.pumpWidget(_app(const ScanReading(1)));
    await _openReading(tester);
    expect(find.text('Reading the bill'), findsOneWidget);
    for (final step in ['Reading the receipt', 'Finding every line', 'Looking for a service charge', 'Checking it adds up']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.byKey(const Key('step-0-active')), findsOneWidget);
    await tester.pump(SplitDurations.readingStep);
    expect(find.byKey(const Key('step-0-done')), findsOneWidget);
    expect(find.byKey(const Key('step-1-active')), findsOneWidget);
    // It stops on the last step rather than looping.
    await tester.pump(SplitDurations.readingStep * 10);
    expect(find.byKey(const Key('step-3-active')), findsOneWidget);
    // A step that just ticked starts its pop on a zero-length timer; let it
    // land before the test ends, as Sorted's scan tests do.
    await tester.pump(SplitDurations.micro);
  });

  testWidgets('shows what it really found, then opens the receipt', (tester) async {
    await tester.pumpWidget(_app(const ScanReading(1)));
    await _openReading(tester);
    _controller.set(ScanReady(_bao));
    await tester.pump();
    expect(find.text('Found 10 items'), findsOneWidget);
    expect(find.text('Found a service charge'), findsOneWidget);
    expect(find.text('Checking it adds up to £154.69'), findsOneWidget);
    expect(find.byKey(const Key('step-3-done')), findsOneWidget);
    await tester.pump(SplitDurations.readingHold);
    await tester.pumpAndSettle();
    expect(find.text('receipt ${_bao.id}'), findsOneWidget);
  });

  testWidgets('says so when there is no service charge or no readable total', (tester) async {
    final plain = _bao.copyWith(receipt: _bao.receipt.copyWith(serviceChargeMinor: 0, printedTotalMinor: null));
    await tester.pumpWidget(_app(ScanReady(plain)));
    await _openReading(tester);
    expect(find.text('No service charge'), findsOneWidget);
    expect(find.text("Couldn't read the total"), findsOneWidget);
    await tester.pump(SplitDurations.readingHold);
    await tester.pumpAndSettle();
  });

  testWidgets('moves on even if the read finished before it opened', (tester) async {
    await tester.pumpWidget(_app(ScanReady(_bao)));
    await _openReading(tester);
    await tester.pump(SplitDurations.readingHold);
    await tester.pumpAndSettle();
    expect(find.text('receipt ${_bao.id}'), findsOneWidget);
  });

  testWidgets('a failed read says why and Try again goes back with the photos', (tester) async {
    await tester.pumpWidget(_app(const ScanReading(1)));
    await _openReading(tester);
    _controller.set(const ScanFailed('SplitDoc could not read that reliably. Please enter it by hand.'));
    await tester.pump();
    expect(find.text('SplitDoc could not read that reliably. Please enter it by hand.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('scan-route'), findsOneWidget);
    expect(_controller.state, isA<ScanIdle>());
  });

  testWidgets('a failed read offers to type the bill in, which opens a blank receipt', (tester) async {
    await tester.pumpWidget(_app(const ScanReading(1)));
    await _openReading(tester);
    _controller.set(const ScanFailed('Split could not read that reliably.'));
    await tester.pump();
    await tester.tap(find.text('Type it in instead'));
    await tester.pumpAndSettle();
    expect(_api.created, 1);
    expect(find.text('receipt blank-1'), findsOneWidget);
    expect(_controller.state, isA<ScanIdle>());
  });

  testWidgets('under reduced motion the steps still appear and nothing loops', (tester) async {
    await tester.pumpWidget(_app(const ScanReading(1), reduce: true));
    await _openReading(tester);
    expect(find.text('Reading the receipt'), findsOneWidget);
    await tester.pump(SplitDurations.readingStep);
    expect(find.byKey(const Key('step-0-done')), findsOneWidget);
    _controller.set(ScanReady(_bao));
    await tester.pump(SplitDurations.readingHold);
    await tester.pumpAndSettle();
    expect(find.text('receipt ${_bao.id}'), findsOneWidget);
  });
}
