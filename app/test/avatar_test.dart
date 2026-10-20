import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_colors.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/widgets/avatar.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: splitTheme(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the initial, upper-cased, in the participant colours', (tester) async {
    await tester.pumpWidget(_host(const Avatar(name: 'dan', colourIndex: 3)));
    expect(find.text('D'), findsOneWidget);
    final colours = SplitColors.light.participant(3);
    final box = tester.widget<Container>(find.byKey(const Key('avatar-disc'))).decoration! as BoxDecoration;
    expect(box.color, colours.fill);
    expect(tester.widget<Text>(find.text('D')).style!.color, colours.text);
  });

  testWidgets('is the size asked for', (tester) async {
    await tester.pumpWidget(_host(const Avatar(name: 'Kemi', colourIndex: 0, size: 44)));
    expect(tester.getSize(find.byType(Avatar)), const Size(44, 44));
  });

  test('refuses a size that is not in the design', () {
    expect(() => Avatar(name: 'Kemi', colourIndex: 0, size: 33), throwsAssertionError);
  });

  testWidgets('says the name, so colour never carries meaning alone', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const Avatar(name: 'Amaka', colourIndex: 1)));
    expect(find.bySemanticsLabel('Amaka'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a stack overlaps, so three are narrower than three side by side', (tester) async {
    await tester.pumpWidget(_host(const AvatarStack(people: [
      (name: 'Amaka', colourIndex: 1),
      (name: 'Josh', colourIndex: 2),
      (name: 'Dan', colourIndex: 3),
    ])));
    expect(find.byType(Avatar), findsNWidgets(3));
    final width = tester.getSize(find.byType(AvatarStack)).width;
    expect(width, lessThan(3 * (30 + 4)));
    expect(width, 30 + 4 + 2 * (30 + 4 - 8));
  });

  testWidgets('an empty stack takes no space', (tester) async {
    await tester.pumpWidget(_host(const AvatarStack(people: [])));
    expect(tester.getSize(find.byType(AvatarStack)), Size.zero);
  });
}
