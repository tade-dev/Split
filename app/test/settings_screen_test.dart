import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/features/settings/settings_screen.dart';
import 'package:split/models/organiser.dart';
import 'package:split/providers/organiser_provider.dart';

late List<Map<String, Object?>> _saved;
late List<Uri> _opened;

Future<void> _pump(WidgetTester tester, {String? email}) async {
  _saved = [];
  _opened = [];
  await tester.binding.setSurfaceSize(const Size(700, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      organiserProvider.overrideWith((ref) => Stream.value(Organiser(id: 'kemi', displayName: 'Kemi', paypalEmail: email))),
      saveOrganiserProvider.overrideWithValue((changes) async => _saved.add(changes)),
    ],
    child: MaterialApp(
      theme: splitTheme(),
      home: SettingsScreen(openLink: (u) async => _opened.add(u)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the name friends see and the sandbox note', (tester) async {
    await _pump(tester);
    expect(find.widgetWithText(TextField, 'Kemi'), findsOneWidget);
    expect(find.byKey(const Key('sandbox-note')), findsOneWidget);
  });

  testWidgets('saves only what changed', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('settings-email')), 'Kemi@Example.com');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(_saved, [
      {'paypalEmail': 'Kemi@Example.com'},
    ]);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an emptied email clears it, so payments go to the demo merchant', (tester) async {
    await _pump(tester, email: 'kemi@example.com');
    await tester.enterText(find.byKey(const Key('settings-email')), '');
    await tester.enterText(find.byKey(const Key('settings-name')), 'Kems');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(_saved, [
      {'displayName': 'Kems', 'paypalEmail': null},
    ]);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an empty name is refused before anything is sent', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('settings-name')), '  ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(_saved, isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('links to the source code', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Source code'));
    expect(_opened.single.toString(), 'https://github.com/tade-dev/Split');
  });
}
