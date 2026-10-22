import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split/core/first_run.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/features/welcome/welcome_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (_, s) => FirstRun.showWelcome && s.matchedLocation == '/' ? '/welcome' : null,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home-route')),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/scan', builder: (_, _) => const Text('scan-route')),
      GoRoute(path: '/split/:id', builder: (_, s) => Text('bill ${s.pathParameters['id']}')),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp.router(theme: splitTheme(), routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a first run opens on Welcome', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await FirstRun.load();
    await _pump(tester);
    expect(find.text('Snap the bill. Everyone pays their bit.'), findsOneWidget);
    expect(find.text('3 links sent'), findsOneWidget);
  });

  testWidgets('Split a bill remembers Welcome was seen and opens the camera', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await FirstRun.load();
    await _pump(tester);
    await tester.ensureVisible(find.byKey(const Key('welcome-split')));
    await tester.tap(find.byKey(const Key('welcome-split')));
    await tester.pumpAndSettle();
    expect(find.text('scan-route'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('welcome_seen'), isTrue);
    await FirstRun.load();
    expect(FirstRun.showWelcome, isFalse);
  });

  testWidgets('See my splits goes Home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await FirstRun.load();
    await _pump(tester);
    // The test font is wider than the real one, so the page scrolls here.
    await tester.ensureVisible(find.byKey(const Key('welcome-home')));
    await tester.tap(find.byKey(const Key('welcome-home')));
    await tester.pumpAndSettle();
    expect(find.text('home-route'), findsOneWidget);
  });

  testWidgets('once seen, launch goes straight Home', (tester) async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    await FirstRun.load();
    await _pump(tester);
    expect(find.text('home-route'), findsOneWidget);
  });
}
