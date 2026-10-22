import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../core/uk_date.dart';
import '../../data/splits_repository.dart';
import '../../models/split.dart';
import '../../providers/organiser_provider.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/bill_illustration.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';
import 'summary_card.dart';

/// The bundled photo behind *Try a sample bill*. A copy of
/// samples/receipts/little-bao-house.png.
const sampleBillAsset = 'assets/samples/little-bao-house.png';

/// Loads the sample photo. A provider so tests can hand in known bytes.
final sampleBillProvider = Provider<Future<Photo> Function()>(
  (ref) => () async {
    final data = await rootBundle.load(sampleBillAsset);
    return (bytes: data.buffer.asUint8List().toList(), filename: 'little-bao-house.png');
  },
);

/// Home.dc.html. The bill in progress as the dark card, the settled ones
/// underneath, and two ways in: a new bill, or the sample for judges.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Plan decision D11: the sample goes through the real read, so a judge
  /// watches the AI work rather than a canned result appear.
  Future<void> _trySample(BuildContext context, WidgetRef ref) async {
    try {
      final photo = await ref.read(sampleBillProvider)();
      // Not awaited: Reading shows the read while it runs.
      ref.read(scanControllerProvider.notifier).read([photo]);
      if (context.mounted) await context.push('/split/reading');
    } catch (e) {
      if (context.mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final name = ref.watch(organiserProvider).value?.displayName ?? '';
    // On a first visit the name and the sample bill arrive with bootstrap.
    // Until then the greeting and the card are placeholders, not a bare "Hi".
    final waiting = name.isEmpty && !ref.watch(bootstrapProvider).hasValue;
    final splitsAsync = ref.watch(splitsProvider);
    final splits = splitsAsync.value ?? const <SplitDoc>[];
    final active = splits.where((s) => s.isOpen).firstOrNull;
    final settled = splits.where((s) => s.status == 'settled').toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 16, SplitShape.screenPadding, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: waiting
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: SkeletonLine(key: Key('greeting-skeleton'), width: 140, fontSize: 30),
                              )
                            : Text(name.isEmpty ? 'Hi' : 'Hi $name', style: text.headlineLarge),
                      ),
                      if (waiting)
                        const SkeletonBox(width: 44, height: 44, radius: 22)
                      else if (name.isNotEmpty)
                        Semantics(
                          button: true,
                          label: 'Settings',
                          child: GestureDetector(
                            key: const Key('open-settings'),
                            onTap: () => context.push('/settings'),
                            child: Avatar(name: name, colourIndex: 0, size: 44),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (active != null)
                    SummaryCard(split: active)
                  else if (splitsAsync.hasError && !splitsAsync.hasValue)
                    Column(
                      key: const Key('splits-error'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Couldn't load your bills. Check your connection.", style: text.bodyLarge?.copyWith(color: c.muted)),
                        TextButton(onPressed: () => ref.invalidate(splitsProvider), child: const Text('Try again')),
                      ],
                    )
                  else if (waiting || !splitsAsync.hasValue)
                    const _SummarySkeleton()
                  else
                    const _EmptyHome(first: true),
                  if (active != null && settled.isEmpty) const _EmptyHome(first: false),
                  if (settled.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Settled', style: text.titleLarge),
                    const SizedBox(height: 6),
                    for (final s in settled) _SettledRow(split: s),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: () => _trySample(context, ref),
                    icon: SplitIcon(SplitIcons.image, size: 20, color: c.primary),
                    label: const Text('Try a sample bill'),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Split a new bill',
                    icon: SplitIcons.camera,
                    onPressed: () => context.push('/scan'),
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

/// The space under the summary while there is nothing settled yet: the
/// illustration and a line on what happens next. The actions stay pinned
/// below it, so they sit right under the picture.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.first});

  /// No bill at all yet, rather than one still in progress.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      key: Key(first ? 'home-empty' : 'home-empty-settled'),
      padding: EdgeInsets.only(top: first ? 72 : 40),
      child: Column(
        children: [
          const BillIllustration(),
          const SizedBox(height: 20),
          Text(
            first ? 'Split your first bill' : 'Paid-up bills land here',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            first
                ? 'Snap the receipt. Friends say what they had, and everyone pays you back by PayPal, to the penny.'
                : 'Once everyone has paid you back, the bill moves down here.',
            style: text.bodyMedium?.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettledRow extends ConsumerWidget {
  const _SettledRow({required this.split});
  final SplitDoc split;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final people = ref.watch(participantsProvider(split.id)).value?.length;
    final caption = [
      if (split.receiptDate != null) formatUkDate(split.receiptDate!),
      if (people != null) '$people ${people == 1 ? 'person' : 'people'}',
    ].join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.neutralTint, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: SplitIcon(SplitIcons.checkCircle, size: 20, color: c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(split.title, style: text.titleSmall),
                if (caption.isNotEmpty) Text(caption, style: text.bodySmall?.copyWith(color: c.muted)),
              ],
            ),
          ),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.successTint, borderRadius: BorderRadius.circular(999)),
            child: Text('Settled', style: text.labelMedium?.copyWith(color: c.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The dark card's shape while the first bill is on its way.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    return Container(
      key: const Key('summary-skeleton'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(SplitShape.cardRadiusLarge)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(width: 160, dark: true),
          SizedBox(height: 16),
          SkeletonLine(width: 120, fontSize: 36, dark: true),
          SizedBox(height: 16),
          SkeletonLine(width: 200, dark: true),
        ],
      ),
    );
  }
}
