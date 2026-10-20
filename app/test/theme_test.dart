import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_colors.dart';
import 'package:split/core/theme/split_shape.dart';
import 'package:split/core/theme/split_theme.dart';

void main() {
  testWidgets('SplitColors is reachable from any BuildContext', (tester) async {
    SplitColors? captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: splitTheme(),
        home: Builder(
          builder: (context) {
            captured = SplitColors.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(captured, isNotNull);
  });

  testWidgets('tokens match DESIGN.md exactly', (tester) async {
    late SplitColors c;
    await tester.pumpWidget(
      MaterialApp(
        theme: splitTheme(),
        home: Builder(
          builder: (context) {
            c = SplitColors.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(c.ink, const Color(0xFF001C64));
    expect(c.primary, const Color(0xFF0070E0));
    expect(c.success, const Color(0xFF147A47));
    expect(c.successTint, const Color(0xFFE3F4EA));
    expect(c.warningTint, const Color(0xFFFFF4D6));
    expect(c.warningText, const Color(0xFF7A5200));
    expect(c.neutralTint, const Color(0xFFEBEEF3));
    expect(c.darkLink, const Color(0xFF123C96));
    expect(c.accentCyan, const Color(0xFF60CDFF));
    expect(c.paidBar, const Color(0xFF5BD08F));
  });

  testWidgets('the scaffold background is the background token', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: splitTheme(), home: const Scaffold()));
    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
  });

  test('status colours are distinguishable by lightness, not hue alone', () {
    // DESIGN.md requires this so the Paid/Waiting/Draft chips stay readable
    // for colour-blind users and in a greyscale screenshot.
    //
    // The separation lives in the FOREGROUND, not the tint. All three tints are
    // pale fills within 0.018 lightness of each other (successTint 0.9235,
    // warningTint 0.9196, neutralTint 0.9373), so a tint-only assertion would
    // fail against the design's own palette. What a reader actually tells apart
    // is the label colour on top, and those are 0.039-0.129 apart.
    const c = SplitColors.light;
    final labels = <String, Color>{
      'Paid': c.success,
      'Waiting': c.warningText,
      'Draft': c.muted,
    };

    final names = labels.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = HSLColor.fromColor(labels[names[i]]!).lightness;
        final b = HSLColor.fromColor(labels[names[j]]!).lightness;
        expect(
          (a - b).abs(),
          greaterThan(0.02),
          reason: '${names[i]} and ${names[j]} labels are too close in lightness',
        );
      }
    }
  });

  test('each status chip separates its label from its own fill', () {
    // A chip whose label sits close in lightness to its fill is unreadable
    // regardless of hue. Every pair here clears 0.4.
    const c = SplitColors.light;
    final chips = <String, (Color, Color)>{
      'Paid': (c.success, c.successTint),
      'Waiting': (c.warningText, c.warningTint),
      'Draft': (c.muted, c.neutralTint),
    };

    chips.forEach((name, pair) {
      final fg = HSLColor.fromColor(pair.$1).lightness;
      final bg = HSLColor.fromColor(pair.$2).lightness;
      expect(
        (fg - bg).abs(),
        greaterThan(0.4),
        reason: '$name label is too close in lightness to its own fill',
      );
    });
  });

  test('lerp returns a SplitColors so theme animation does not crash', () {
    final mid = SplitColors.light.lerp(SplitColors.light, 0.5);
    expect(mid, isA<SplitColors>());
  });

  test('shape constants match DESIGN.md', () {
    expect(SplitShape.screenPadding, 20.0);
    expect(SplitShape.primaryButtonHeight, 54.0);
    expect(SplitShape.primaryButtonRadius, 16.0);
    expect(SplitShape.statusChipHeight, 26.0);
    expect(SplitShape.selectableChipHeight, 40.0);
    expect(SplitShape.minTouchTarget, 44.0);
  });

  group('participant colours', () {
    // DESIGN.md gives 0-4; the plan's D12 chose 5-7 at the same lightness.
    const expected = [
      (0xFFFFC439, 0xFF3D2B00), (0xFFFF9F80, 0xFF4A1A0A), (0xFF9DBEFF, 0xFF0A2560),
      (0xFF7AD9AE, 0xFF063D26), (0xFFD6B0FF, 0xFF3A1466), (0xFFFF9EC7, 0xFF4D0A2B),
      (0xFF7FD3E6, 0xFF053A45), (0xFFB9D46C, 0xFF2E3A05),
    ];

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    test('match DESIGN.md and D12, in join order', () {
      final p = SplitColors.light.participants;
      expect(p, hasLength(8));
      for (var i = 0; i < expected.length; i++) {
        expect(p[i].fill, Color(expected[i].$1), reason: 'fill $i');
        expect(p[i].text, Color(expected[i].$2), reason: 'text $i');
      }
    });

    test('text is legible on its own fill', () {
      for (final (i, pc) in SplitColors.light.participants.indexed) {
        expect(contrast(pc.fill, pc.text), greaterThanOrEqualTo(4.5), reason: 'colour $i');
      }
    });

    test('fills share one lightness band, so no one person shouts', () {
      for (final (i, pc) in SplitColors.light.participants.indexed) {
        expect(pc.fill.computeLuminance(), inInclusiveRange(0.45, 0.65), reason: 'colour $i');
      }
    });

    test('a ninth person wraps round to the first colours', () {
      expect(SplitColors.light.participant(9), SplitColors.light.participant(1));
      expect(SplitColors.light.participant(8), SplitColors.light.participant(0));
    });

    test('lerp carries participant colours through', () {
      final mid = SplitColors.light.lerp(SplitColors.light, 0.5);
      expect(mid.participants, hasLength(8));
      expect(mid.participant(3).fill, SplitColors.light.participant(3).fill);
    });
  });
}
