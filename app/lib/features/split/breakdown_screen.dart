import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/participant.dart';
import '../../models/receipt.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/money_roll.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';

/// Who owes what (Breakdown.dc.html). One row per person, biggest share
/// first, the organiser and anyone on us last. Each row opens to the lines
/// behind it. Every figure is `computed`'s; *Send links* locks the split.
class BreakdownScreen extends ConsumerStatefulWidget {
  const BreakdownScreen({super.key, required this.splitId});

  final String splitId;

  @override
  ConsumerState<BreakdownScreen> createState() => _BreakdownScreenState();
}

class _BreakdownScreenState extends ConsumerState<BreakdownScreen> {
  final _open = <String>{};
  bool _busy = false;

  Future<void> _run(Future<void> Function() call, {String? then}) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted && then != null) context.go(then);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final split = ref.watch(splitProvider(widget.splitId)).value;
    final people = ref.watch(participantsProvider(widget.splitId)).value ?? const <Participant>[];
    final computed = split?.computed;
    final ok = computed?.ok ?? false;
    final locked = split?.status == 'collecting';

    bool onUs(Participant p) => split?.rules.onUs.contains(p.id) ?? false;
    int share(Participant p) => computed?.perParticipant[p.id]?.finalMinor ?? 0;
    final payers = [for (final p in people) if (!p.isOrganiser && !onUs(p)) p]..sort((a, b) => share(b).compareTo(share(a)));
    final ordered = [
      ...payers,
      ...people.where((p) => p.isOrganiser),
      ...people.where((p) => !p.isOrganiser && onUs(p)),
    ];
    final owed = payers.fold<int>(0, (t, p) => t + share(p));

    return Scaffold(
      appBar: SplitAppBar(title: 'Totals', fallback: '/split/${widget.splitId}/rules'),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 16),
                children: [
                  Text('Who owes what', style: text.headlineLarge),
                  const SizedBox(height: 16),
                  if (split != null && ok)
                    for (final p in ordered)
                      _PersonRow(
                        person: p,
                        split: split,
                        onUs: onUs(p),
                        open: _open.contains(p.id),
                        onTap: () => setState(() => _open.contains(p.id) ? _open.remove(p.id) : _open.add(p.id)),
                      ),
                  if (split != null && !ok)
                    Text(
                      'Something still needs an answer before the totals add up. Go back to the claims to sort it.',
                      style: text.bodyMedium?.copyWith(color: c.muted),
                    ),
                  if (ok && computed?.totalMinor != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      key: const Key('adds-up'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SplitIcon(SplitIcons.checkCircle, size: 18, color: c.success),
                        const SizedBox(width: 6),
                        Text('Adds up to the ', style: text.bodyMedium?.copyWith(color: c.success)),
                        MoneyRoll(
                          amountMinor: computed!.totalMinor!,
                          style: text.bodyMedium?.copyWith(color: c.success, fontWeight: FontWeight.w600),
                        ),
                        Text(' on the bill', style: text.bodyMedium?.copyWith(color: c.success)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: locked ? 'See who has paid' : 'Send links for ${formatGbp(owed)}',
                    icon: locked ? null : SplitIcons.link,
                    onPressed: !ok || _busy
                        ? null
                        : locked
                            ? () => context.go('/split/${widget.splitId}')
                            : () => _run(() => ref.read(splitsApiProvider).lock(widget.splitId), then: '/split/${widget.splitId}'),
                  ),
                  if (locked)
                    TextButton(
                      onPressed: _busy ? null : () => _run(() => ref.read(splitsApiProvider).unlock(widget.splitId)),
                      child: const Text('Unlock to change something'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.split, required this.onUs, required this.open, required this.onTap});
  final Participant person;
  final SplitDoc split;
  final bool onUs;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final b = split.computed?.perParticipant[person.id] ?? const Breakdown();
    final subtitle = open
        ? 'Tap to hide details'
        : person.isOrganiser
            ? 'You, already paid'
            : onUs
                ? 'On us'
                : b.lines.length == 1
                    ? '1 item'
                    : '${b.lines.length} items';

    return Container(
      key: Key('person-${person.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(SplitShape.cardRadius),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(SplitShape.cardRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Avatar(name: person.name, colourIndex: person.colourIndex, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: text.titleSmall),
                        Text(subtitle, style: text.bodySmall?.copyWith(color: c.muted)),
                      ],
                    ),
                  ),
                  Text(formatGbp(b.finalMinor), style: text.titleMedium),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(children: [for (final r in _rows(split, person, b)) _Row(label: r.label, minor: r.minor)]),
            ),
        ],
      ),
    );
  }
}

/// The lines behind a share, then what the group's rules add or take away.
List<({String label, int minor})> _rows(SplitDoc split, Participant person, Breakdown b) {
  final names = {for (final ReceiptLine l in split.receipt.lines) l.id: l.name};
  final service = split.receipt.serviceChargeLabel == null ? 'Service charge' : 'Service charge, ${split.receipt.serviceChargeLabel}';
  return [
    for (final l in b.lines)
      (
        label: switch (l.portionLabel) {
          '' => names[l.lineId] ?? l.lineId,
          'share' => '${names[l.lineId] ?? l.lineId} share',
          final portion => '${names[l.lineId] ?? l.lineId}, $portion',
        },
        minor: l.minor,
      ),
    if (b.sharedFromOnUsMinor > 0) (label: "Share of what's on the group", minor: b.sharedFromOnUsMinor),
    if (b.sharedFromOnUsMinor < 0) (label: 'Covered by the group', minor: b.sharedFromOnUsMinor),
    if (b.serviceMinor != 0) (label: service, minor: b.serviceMinor),
    if (b.tipMinor != 0) (label: 'Tip', minor: b.tipMinor),
    if (b.discountMinor != 0) (label: 'Discount', minor: -b.discountMinor),
  ];
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.minor});
  final String label;
  final int minor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(formatGbp(minor), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
