import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion/split_motion.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';

/// The dark card on Home: the bill in progress.
///
/// Week A only has bills in draft, so the figure is the bill's total and the
/// line says it is still being checked. The collecting state from
/// Home.dc.html ("£79.03 of £118.26 back", the cyan bar, "Waiting on Dan")
/// comes from participants' payments and lands with the Tracker; it is a
/// change to [_figures], not to the card.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key, required this.split});

  final SplitDoc split;

  ({String amount, String? caption, String status}) _figures() {
    final total = split.receipt.printedTotalMinor;
    return (
      amount: total == null ? 'Total not read' : formatGbp(total),
      caption: null,
      status: switch (split.status) {
        'draft' => 'Still checking the bill',
        'claiming' => 'Friends are saying what they had',
        _ => 'Collecting',
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final people = ref.watch(participantsProvider(split.id)).value ?? const [];
    final f = _figures();
    final heading = [split.title, if (split.merchant != null) split.merchant!].join(', ');

    return PressScale(
      // Draft is the only state Week A builds; later states open the Tracker.
      onTap: () => context.push('/split/${split.id}/receipt'),
      child: Semantics(
        button: true,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(SplitShape.cardRadiusLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(heading, style: text.bodyMedium?.copyWith(color: c.onDarkMuted)),
                  ),
                  AvatarStack(
                    size: 24,
                    ring: c.ink,
                    people: [
                      for (final p in people)
                        if (!p.isOrganiser) (name: p.name, colourIndex: p.colourIndex),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                f.amount,
                style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(f.status, style: text.bodyMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
