import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/data/splits_repository.dart';
import 'package:split/features/split/nudge_sheet.dart';
import 'package:split/models/participant.dart';
import 'package:split/providers/splits_providers.dart';

const _link = 'https://split-api-k5ai.onrender.com/v1/s/kemi/s1/dan/sig';
const _dan = Participant(id: 'dan', name: 'Dan', colourIndex: 3, status: 'link_opened', shareMinor: 3923);

class _Api implements SplitsApi {
  final tones = <String>[];
  final sent = <String>[];
  var snoozed = 0;

  @override
  Future<NudgeDraft> draftNudge(String splitId, String participantId, String tone) async {
    tones.add(tone);
    final words = tone == 'cheeky' ? "Oi Dan! Your bit's £39.23." : 'Hey Dan! Your bit is £39.23.';
    return (text: '$words $_link', tone: tone, shouldSkip: false, skipReason: null);
  }

  @override
  Future<void> nudgeSent(String splitId, String participantId, String text) async => sent.add(text);

  @override
  Future<void> snoozeNudge(String splitId, String participantId) async => snoozed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

late _Api _api;
String? _clipboard;

Future<void> _pump(WidgetTester tester) async {
  _api = _Api();
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _clipboard = (call.arguments as Map)['text'] as String;
    return null;
  });
  await tester.binding.setSurfaceSize(const Size(700, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [splitsApiProvider.overrideWithValue(_api)],
    child: MaterialApp(
      theme: splitTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showNudgeSheet(context, splitId: 's1', title: 'Friday dinner', person: _dan, link: _link),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drafts a friendly nudge, with the link in its own chip', (tester) async {
    await _pump(tester);
    expect(find.text('Nudge Dan'), findsOneWidget);
    expect(find.text('£39.23 for Friday dinner'), findsOneWidget);
    expect(find.text('Hey Dan! Your bit is £39.23.'), findsOneWidget);
    expect(find.textContaining(_link), findsOneWidget);
    expect(_api.tones, ['friendly']);
  });

  testWidgets('a new tone redrafts', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Cheeky'));
    await tester.pumpAndSettle();
    expect(_api.tones, ['friendly', 'cheeky']);
    expect(find.text("Oi Dan! Your bit's £39.23."), findsOneWidget);
  });

  testWidgets('Copy nudge copies the whole message, link included, and records it', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Copy nudge'));
    await tester.pumpAndSettle();
    expect(_clipboard, 'Hey Dan! Your bit is £39.23. $_link');
    expect(_api.sent, ['Hey Dan! Your bit is £39.23. $_link']);
    expect(find.text('Nudge Dan'), findsNothing);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Remind me tomorrow snoozes', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Remind me tomorrow'));
    await tester.pumpAndSettle();
    expect(_api.snoozed, 1);
    await tester.pump(const Duration(seconds: 4));
  });
}
