import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion/split_motion.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/participant.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';

/// The dark card on Home: the bill in progress.
///
/// Before lock the figure is the bill's total. Once collecting it is what
/// has come back (Home.dc.html, "£79.03 of £118.26 back"), from the
/// participants' own statuses, and the card opens the Tracker.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key, required this.split});

  final SplitDoc split;

  ({String amount, String? caption, String status}) _figures(List<Participant> people) {
    if (split.status == 'collecting') {
      final payers = [for (final p in people) if (!p.isOrganiser && p.status != 'on_us') p];
      bool paid(Participant p) => p.status == 'paid' || p.status == 'paid_cash';
      final owed = payers.fold<int>(0, (t, p) => t + (p.shareMinor ?? 0));
      final back = payers.where(paid).fold<int>(0, (t, p) => t + (p.shareMinor ?? 0));
      final waiting = [for (final p in payers) if (!paid(p)) p.name];
      return (
        amount: '${formatGbp(back)} of ${formatGbp(owed)} back',
        caption: null,
        status: switch (waiting.length) {
          0 => 'Everyone has paid',
          1 => 'Waiting on ${waiting.single}',
          final n => 'Waiting on $n people',
        },
      );
    }
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

  String get _route => switch (split.status) {
        'draft' => '/split/${split.id}/receipt',
        'claiming' => '/split/${split.id}/claims',
        _ => '/split/${split.id}',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final people = ref.watch(participantsProvider(split.id)).value ?? const [];
    final f = _figures(people);
    final heading = [split.title, if (split.merchant != null) split.merchant!].join(', ');

    return PressScale(
      onTap: () => context.push(_route),
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
