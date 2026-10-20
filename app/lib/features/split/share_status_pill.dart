import 'package:flutter/material.dart';

import '../../core/motion/motion_access.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import 'share_presentation.dart';

/// Status chip. Paid is the green one; the others stay in the warning, blue
/// and neutral tokens so they can be told apart without relying on hue alone.
class ShareStatusPill extends StatelessWidget {
  const ShareStatusPill({super.key, required this.status, this.label});

  final String status;

  /// Overrides the wording but keeps the tone, e.g. Home's "Deposit due".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final presentation = statusPresentation(status);
    final (
      Color background,
      Color foreground,
      Color? border,
    ) = switch (presentation.tone) {
      StatusTone.paid => (c.successTint, c.success, null),
      StatusTone.waiting => (c.warningTint, c.warningText, null),
      StatusTone.progress => (c.primaryTint, c.primary, null),
      StatusTone.pending => (c.surface, c.warningText, c.warningBorder),
      StatusTone.declined => (c.warningTint, c.warningText, c.warningBorder),
      StatusTone.draft => (c.neutralTint, c.muted, null),
      StatusTone.closed => (c.neutralTint, c.muted, c.line),
    };

    // Chip morph: the background tweens, the label cross-fades with a small
    // lift, and the box grows to fit, so Draft → Link sent → Paid reads as
    // one chip changing rather than three chips.
    final label0 = label ?? presentation.label;
    final text13 = text.bodySmall?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1,
    );

    // Padding, not height-plus-alignment. A Container with an alignment
    // expands to whatever width it is offered, so in a Row the pill was a
    // 72px chip and in a Column — Order detail — it was a full-width bar.
    // Padding leaves it the size of its own label everywhere.
    const padding = (SplitShape.statusChipHeight - 13) / 2;

    return AnimatedContainer(
      duration: Motion.duration(context, SplitDurations.medium),
      curve: Motion.curve(context, SplitSprings.gentle),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SplitShape.pillRadius),
        border: border == null ? null : Border.all(color: border),
      ),
      child: _Resize(
        child: AnimatedSwitcher(
          duration: Motion.duration(context, SplitDurations.short),
          switchInCurve: Motion.curve(context, SplitSprings.gentle),
          switchOutCurve: SplitCurves.exit,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 1 - Motion.move(context, 0.08), end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: Text(label0, key: ValueKey(label0), style: text13),
        ),
      ),
    );
  }
}

/// Grows the pill to fit a new label, or doesn't, under reduced motion.
///
/// It wraps rather than passing a zero duration because AnimatedSize asserts
/// on one: with nothing to animate it finishes inside its own performLayout
/// and re-dirties itself. "No animation" here has to mean no animator.
class _Resize extends StatelessWidget {
  const _Resize({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSize(
      duration: SplitDurations.short,
      curve: SplitSprings.snappy,
      child: child,
    );
  }
}
