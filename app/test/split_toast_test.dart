import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/widgets/split_toast.dart';

Widget _host(void Function(BuildContext) onTap, {bool reduceMotion = false}) => MaterialApp(
      theme: splitTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => onTap(context), child: const Text('go')),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows a success toast and auto-dismisses it', (tester) async {
    await tester.pumpWidget(_host((c) => SplitToast.success(c, 'Copied')));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('a new toast replaces the one showing', (tester) async {
    var n = 0;
    await tester.pumpWidget(_host((c) => SplitToast.info(c, 'Toast ${++n}')));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('runs the action and closes', (tester) async {
    var undone = false;
    await tester.pumpWidget(_host((c) => SplitToast.error(
          c,
          'Could not save',
          action: SplitToastAction(label: 'Retry', onPressed: () => undone = true),
        )));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(undone, isTrue);
    expect(find.text('Could not save'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('swipes away', (tester) async {
    await tester.pumpWidget(_host((c) => SplitToast.info(c, 'Swipe me')));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.fling(find.text('Swipe me'), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('outlives the screen that raised it, using a handle', (tester) async {
    await tester.pumpWidget(_host((c) {
      final toast = SplitToast.of(c);
      Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      toast.show('Saved', kind: SplitToastKind.success);
    }));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('shows without animating under Reduce Motion', (tester) async {
    await tester.pumpWidget(_host((c) => SplitToast.info(c, 'Still'), reduceMotion: true));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Still'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
