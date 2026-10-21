import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/motion/split_motion.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';

/// What the steps say while the one scan request is in flight. Honest about
/// the order the backend works in, without claiming progress it cannot see.
const _waiting = [
  'Reading the receipt',
  'Finding every line',
  'Looking for a service charge',
  'Checking it adds up',
];

/// The same four steps, now saying what was actually found.
List<String> _found(SplitDoc split) {
  final r = split.receipt;
  final n = r.lines.length;
  return [
    'Reading the receipt',
    'Found $n ${n == 1 ? 'item' : 'items'}',
    r.serviceChargeMinor > 0 ? 'Found a service charge' : 'No service charge',
    r.printedTotalMinor == null
        ? "Couldn't read the total"
        : 'Checking it adds up to ${formatGbp(r.printedTotalMinor!)}',
  ];
}

/// The 3-10 seconds while the model reads the bill: a checklist that ticks,
/// never a bare spinner. Spec §6 asks for Sorted's Reading pattern. Once the
/// read lands, the steps say what was found, hold for a beat, and the
/// receipt opens in this screen's place.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  Timer? _ticker;
  Timer? _hold;
  int _shown = 0;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(SplitDurations.readingStep, (_) {
      if (!mounted) return;
      setState(() => _shown = (_shown + 1).clamp(0, _waiting.length - 1));
    });
    // ref.listen only fires on a change. If the read finished before this
    // screen opened, move on from the first frame instead of waiting forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(scanControllerProvider);
      if (state is ScanReady) _moveOn(state.split);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hold?.cancel();
    super.dispose();
  }

  void _moveOn(SplitDoc split) {
    if (_hold != null) return;
    _ticker?.cancel();
    _hold = Timer(SplitDurations.readingHold, () {
      if (mounted) context.pushReplacement('/split/${split.id}/receipt');
    });
  }

  void _tryAgain() {
    ref.read(scanControllerProvider.notifier).reset();
    context.canPop() ? context.pop() : context.go('/scan');
  }

  /// Spec Q2: the read failed (the API has already retried the model), so
  /// a blank receipt beats a dead end.
  Future<void> _typeItIn() async {
    setState(() => _creating = true);
    try {
      final split = await ref.read(splitsApiProvider).createEmpty();
      if (!mounted) return;
      ref.read(scanControllerProvider.notifier).reset();
      context.pushReplacement('/split/${split.id}/receipt');
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      SplitToast.error(context, describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(scanControllerProvider);

    ref.listen(scanControllerProvider, (_, next) {
      if (next is ScanReady) _moveOn(next.split);
    });

    if (state is ScanFailed) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SplitShape.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("That didn't work", style: text.headlineMedium),
                const SizedBox(height: 8),
                Text(state.message, style: text.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Type it in instead', onPressed: _creating ? null : _typeItIn),
                const SizedBox(height: 8),
                TextButton(onPressed: _creating ? null : _tryAgain, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    final ready = state is ScanReady;
    final labels = ready ? _found(state.split) : _waiting;
    return Scaffold(
      appBar: const SplitAppBar(title: 'SplitDoc a bill', fallback: '/', close: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text('Reading the bill', style: text.headlineLarge?.copyWith(height: 1.1)),
            const SizedBox(height: 26),
            const Center(child: _ScanningReceipt()),
            const SizedBox(height: 26),
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _StepRow(
                  index: i,
                  label: labels[i],
                  state: ready || i < _shown
                      ? _Step.done
                      : i == _shown
                          ? _Step.active
                          : _Step.todo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Step { done, active, todo }

/// 28 px status dot and a 16/500 label, as on Sorted's Reading.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.label, required this.state});
  final int index;
  final String label;
  final _Step state;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final key = Key('step-$index-${state.name}');
    final Widget dot = switch (state) {
      _Step.done => Container(
          key: key,
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          child: const SplitIcon(SplitIcons.check, size: 16, color: Colors.white, strokeWidth: 2.4),
        ).animate().scaleXY(
              begin: 1 - Motion.move(context, 0.4),
              end: 1,
              duration: Motion.duration(context, SplitDurations.short),
              curve: Motion.curve(context, SplitSprings.snappy),
            ),
      _Step.active => SizedBox(
          key: key,
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: c.primary,
            backgroundColor: c.line,
            // Under reduced motion a static ring still says "this one".
            value: Motion.reduced(context) ? 0.3 : null,
          ),
        ),
      _Step.todo => Container(
          key: key,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.line, width: 3),
          ),
        ),
    };
    return Row(
      children: [
        dot,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: text.bodyLarge?.copyWith(
              color: state == _Step.done ? c.ink : c.muted,
              fontWeight: state == _Step.done ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A receipt-shaped card, item bars on the left and price bars on the right,
/// with the blue scan line sweeping over it. Static under reduced motion.
class _ScanningReceipt extends StatelessWidget {
  const _ScanningReceipt();

  static const _w = 210.0;
  static const _h = 250.0;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    Widget bar(double width, {double height = 8, Color? colour}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colour ?? c.neutralTint,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );
    Widget row(int i, double item) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [bar(item), const Spacer(), bar(28)],
          ),
        ).animate().fadeIn(
              delay: SplitDurations.beat * i,
              duration: Motion.duration(context, SplitDurations.medium),
              curve: Motion.curve(context, SplitSprings.gentle),
            );

    final line = Container(
      width: _w,
      height: 3,
      decoration: BoxDecoration(
        color: c.primary,
        boxShadow: [
          BoxShadow(color: c.primary.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 6),
        ],
      ),
    );

    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: c.ink.withValues(alpha: 0.12), blurRadius: 34, offset: const Offset(0, 14)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Column(
              children: [
                Center(child: bar(90, height: 10, colour: c.line)),
                for (final (i, w) in [96.0, 70.0, 110.0, 84.0, 64.0].indexed) row(i, w),
                const SizedBox(height: 16),
                Row(children: [bar(52, height: 10, colour: c.line), const Spacer(), bar(40, height: 10, colour: c.line)]),
              ],
            ),
          ),
          if (Motion.reduced(context))
            Positioned(left: 0, top: 118, child: line)
          else
            Positioned(
              left: 0,
              top: 0,
              child: line
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .moveY(begin: 24, end: 222, duration: SplitDurations.sweep, curve: SplitCurves.loop),
            ),
        ],
      ),
    );
  }
}
