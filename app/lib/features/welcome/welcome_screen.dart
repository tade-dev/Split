import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/first_run.dart';
import '../../core/theme/split_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_icon.dart';

/// First run only (Main.dc.html): the promise in one line, the receipt in
/// friends' colours, and two ways in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _go(BuildContext context, {required bool scan}) async {
    await FirstRun.markSeen();
    if (!context.mounted) return;
    context.go('/');
    if (scan) context.push('/scan');
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.ink,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Split',
                              style: text.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 72,
                                height: 0.95,
                                letterSpacing: -2.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Snap the bill. Everyone pays their bit.',
                              style: text.titleLarge?.copyWith(color: c.accentCyan, fontWeight: FontWeight.w600, fontSize: 22),
                            ),
                            const SizedBox(height: 18),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                'Your friends say what they had in plain words. Split works out each share to the penny and sends them a PayPal link.',
                                style: text.bodyLarge?.copyWith(color: c.onDarkMuted, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(child: _ReceiptPreview()),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PrimaryButton(
                              key: const Key('welcome-split'),
                              label: 'Split a bill',
                              icon: SplitIcons.camera,
                              onPressed: () => _go(context, scan: true),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                key: const Key('welcome-home'),
                                style: TextButton.styleFrom(foregroundColor: Colors.white),
                                onPressed: () => _go(context, scan: false),
                                child: const Text('See my splits'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Little Bao House receipt, each line dotted with who had it, and the
/// "3 links sent" pill: what Split does, before the organiser does anything.
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview();

  static const _lines = [
    ('Prawn crackers', [0, 1, 2, 3, 4], '£5.50'),
    ('Pork bao x3', [0, 2, 3], '£18.00'),
    ('Beef ramen', [2], '£15.00'),
    ('Lychee sour x2', [1, 4], '£19.00'),
    ('Lager x3', [2, 3], '£16.50'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: c.ink, fontSize: 13);
    Widget rule() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < 28; i++)
                Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 1.5), color: i.isEven ? c.line : Colors.transparent)),
            ],
          ),
        );
    return ExcludeSemantics(
      child: SizedBox(
        width: 320,
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 30,
              top: 24,
              child: Transform.rotate(
                angle: -0.052,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 16))],
                  ),
                  child: Column(
                    children: [
                      Text('Little Bao House', style: text.titleSmall?.copyWith(color: c.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Fri 2 Oct, table 6', style: text.bodySmall?.copyWith(color: c.muted, fontSize: 11)),
                      rule(),
                      for (final (name, who, price) in _lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text(name, style: small)),
                              for (final i in who)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(left: 3),
                                  decoration: BoxDecoration(
                                    color: c.participant(i).fill,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.ink.withValues(alpha: 0.25), width: 1),
                                  ),
                                ),
                              SizedBox(width: 50, child: Text(price, style: small, textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                      rule(),
                      Row(
                        children: [
                          Text('Total', style: small?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                          const Spacer(),
                          Text('£154.69', style: small?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 164,
              top: 250,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 24,
                      child: Stack(
                        children: [
                          for (final (i, (initial, colour)) in const [('A', 1), ('J', 2), ('D', 3)].indexed)
                            Positioned(
                              left: i * 16.0,
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.participant(colour).fill,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.primary, width: 2),
                                ),
                                child: Text(initial, style: text.labelSmall?.copyWith(color: c.participant(colour).text, fontWeight: FontWeight.w700, fontSize: 10)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('3 links sent', style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
