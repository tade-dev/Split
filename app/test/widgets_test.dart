import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_colors.dart';
import 'package:split/core/theme/split_shape.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/widgets/primary_button.dart';
import 'package:split/widgets/warning_card.dart';

Widget host(Widget child) =>
    MaterialApp(theme: splitTheme(), home: Scaffold(body: child));

void main() {
  testWidgets('PrimaryButton is at least the design height', (tester) async {
    await tester.pumpWidget(host(PrimaryButton(label: 'Save', onPressed: () {})));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(SplitShape.primaryButtonHeight));
  });

  testWidgets('PrimaryButton disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(host(const PrimaryButton(label: 'Save', onPressed: null)));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isFalse);
  });

  testWidgets('WarningCard uses the warning tokens, not arbitrary colours', (tester) async {
    await tester.pumpWidget(host(const WarningCard(message: "Couldn't read a price.")));
    final box = tester.widget<Container>(find.byType(Container).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, SplitColors.light.warningTint);
    expect(find.text("Couldn't read a price."), findsOneWidget);
  });

}
