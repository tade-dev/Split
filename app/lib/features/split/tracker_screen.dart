import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/motion/paid_announcer.dart';
import '../../core/motion/paid_pop.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/participant.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/money_roll.dart';
import '../../widgets/settled_stamp.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';
import 'share_status_pill.dart';

bool _paid(Participant p) => p.status == 'paid' || p.status == 'paid_cash';

/// Who has paid (Tracker.dc.html). Rows come straight from the participants
/// stream, so a friend's payment flips their row in front of the organiser
/// with no reload: PaidPop on the row, one haptic and one announcement, and
/// the Settled stamp once the last share lands.
class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key, required this.splitId, this.announcer, this.openLink});

  final String splitId;

  /// Test hooks. By default, a real haptic and screen-reader announcement,
  /// and a new browser tab.
  final PaidAnnouncer? announcer;
  final Future<void> Function(Uri url)? openLink;

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  late final PaidAnnouncer _announcer = widget.announcer ?? PaidAnnouncer();

  void _observe(List<Participant> people) => _announcer.observe([
        for (final p in people)
          if (!p.isOrganiser) (id: p.id, status: p.status, label: '${p.name} paid ${formatGbp(p.shareMinor ?? 0)}'),
      ]);

  Future<void> _copy(Participant p, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) SplitToast.success(context, "Copied ${p.name}'s link");
  }

  Future<void> _preview(String url) async {
    final open = widget.openLink ?? (Uri u) => launchUrl(u, webOnlyWindowName: '_blank');
    await open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(participantsProvider(widget.splitId), (_, next) {
      final people = next.value;
      if (people != null) _observe(people);
    });
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final split = ref.watch(splitProvider(widget.splitId)).value;
    final people = ref.watch(participantsProvider(widget.splitId)).value ?? const <Participant>[];

    final payers = [for (final p in people) if (!p.isOrganiser && p.status != 'on_us') p]
      ..sort((a, b) => (b.shareMinor ?? 0).compareTo(a.shareMinor ?? 0));
    final rows = [
      ...payers,
      ...people.where((p) => !p.isOrganiser && p.status == 'on_us'),
      ...people.where((p) => p.isOrganiser),
    ];
    final owed = payers.fold<int>(0, (t, p) => t + (p.shareMinor ?? 0));
    final back = payers.where(_paid).fold<int>(0, (t, p) => t + (p.shareMinor ?? 0));
    final settled = split?.status == 'settled';

    return Scaffold(
      appBar: SplitAppBar(title: split?.title, fallback: '/split/${widget.splitId}/breakdown'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
          children: [
            Text('Getting paid back', style: text.headlineLarge),
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  key: const Key('back'),
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MoneyRoll(amountMinor: back, style: text.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('of ${formatGbp(owed)}', style: text.bodyLarge?.copyWith(color: c.muted)),
                  ],
                ),
                if (settled) const Positioned(right: 0, top: -4, child: SettledStamp(key: Key('settled'))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              settled ? 'Everyone has paid' : 'Updates live from PayPal',
              style: text.bodySmall?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 20),
            for (final p in rows)
              _PersonRow(
                person: p,
                link: split?.links[p.id],
                onCopy: _copy,
                onPreview: _preview,
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.link, required this.onCopy, required this.onPreview});

  final Participant person;
  final String? link;
  final Future<void> Function(Participant p, String url) onCopy;
  final Future<void> Function(String url) onPreview;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final p = person;
    final link = this.link;

    return PaidPop(
      paid: _paid(p),
      child: Container(
        key: Key('row-${p.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(SplitShape.cardRadius),
        ),
        child: Row(
          children: [
            Avatar(name: p.name, colourIndex: p.colourIndex, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(p.isOrganiser ? 'You' : p.name, style: text.titleSmall)),
                      if (!p.isOrganiser) ...[
                        const SizedBox(width: 8),
                        ShareStatusPill(status: p.status),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subline(p), style: text.bodySmall?.copyWith(color: c.muted)),
                ],
              ),
            ),
            Text(formatGbp(p.shareMinor ?? 0), style: text.titleMedium),
            if (link != null && !p.isOrganiser)
              PopupMenuButton<String>(
                key: Key('menu-${p.id}'),
                tooltip: 'More for ${p.name}',
                icon: SplitIcon(SplitIcons.more, size: 20, color: c.muted),
                onSelected: (choice) => choice == 'copy' ? onCopy(p, link) : onPreview(link),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy link')),
                  PopupMenuItem(value: 'preview', child: Text('Preview as ${p.name}')),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// The line under a name. Plain words for where the share stands.
String subline(Participant p) {
  if (p.isOrganiser) return 'Your own share';
  return switch (p.status) {
    'paid' => p.paidAt == null ? 'Paid through PayPal' : 'Paid at ${clockTime(p.paidAt!)}',
    'paid_cash' => 'Paid in cash',
    'owes' => "Hasn't opened the link yet",
    'link_opened' => 'Opened the link, not paid yet',
    'processing' => 'PayPal is confirming it',
    'pending' => 'PayPal has it as pending',
    'declined' => 'PayPal declined it. They can try again',
    'on_us' => 'Nothing to pay',
    _ => '',
  };
}

/// "9:14pm", in the organiser's own time zone.
String clockTime(DateTime at) {
  final t = at.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${t.minute.toString().padLeft(2, '0')}${t.hour < 12 ? 'am' : 'pm'}';
}
