import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../data/splits_repository.dart';
import '../../models/participant.dart';
import '../../models/receipt.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';
import '../../widgets/warning_card.dart';

/// How the extras split (Rules.dc.html): the lines more than one person
/// shared, who is on us, and how the service charge divides. Every figure
/// comes from `computed`; a typed rule is only ever a preview until *Yes*.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key, required this.splitId});

  final String splitId;

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final _message = TextEditingController();
  bool _asking = false;
  RulesPreview? _preview;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  SplitsApi get _api => ref.read(splitsApiProvider);

  Future<void> _patch(Map<String, Object?> body) async {
    try {
      await _api.patchRules(widget.splitId, body);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  Future<void> _ask() async {
    final text = _message.text.trim();
    if (text.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _preview = null;
    });
    try {
      final preview = await _api.rulesMessage(widget.splitId, text);
      if (!mounted) return;
      _message.clear();
      setState(() => _preview = preview);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _confirm(Rules rules) async {
    setState(() => _preview = null);
    await _patch({
      'serviceMode': rules.serviceMode,
      'onUs': rules.onUs,
      'onUsPaidBy': rules.onUsPaidBy,
      'serviceOptOut': rules.serviceOptOut,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final split = ref.watch(splitProvider(widget.splitId)).value;
    final people = ref.watch(participantsProvider(widget.splitId)).value ?? const <Participant>[];
    final ok = split?.computed?.ok ?? false;
    final preview = _preview;

    return Scaffold(
      appBar: SplitAppBar(title: 'Shared items', fallback: '/split/${widget.splitId}/claims'),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 16),
                children: [
                  Text('How the extras split', style: text.headlineLarge),
                  const SizedBox(height: 6),
                  Text(
                    "Split set these up from what the group said. Change anything that's off.",
                    style: text.bodyMedium?.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 16),
                  if (split != null)
                    for (final line in split.receipt.lines)
                      if (_sharers(split, line).length > 1) _SharedRow(split: split, line: line, people: people),
                  if (split != null)
                    for (final p in people.where((p) => !p.isOrganiser))
                      _OnUsRow(
                        person: p,
                        split: split,
                        coveredBy: split.rules.onUsPaidBy == null
                            ? 'the other ${people.length - split.rules.onUs.length}'
                            : _listNames([for (final q in people) if (split.rules.onUsPaidBy!.contains(q.id)) q.name]),
                        onChanged: (on) => _patch({
                          'onUs': on
                              ? [...split.rules.onUs, p.id]
                              : [for (final id in split.rules.onUs) if (id != p.id) id],
                        }),
                      ),
                  if (split != null && split.receipt.serviceChargeMinor > 0) ...[
                    const SizedBox(height: 8),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            split.receipt.serviceChargeLabel == null
                                ? 'Service charge'
                                : 'Service charge, ${split.receipt.serviceChargeLabel}',
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          SegmentedControl<String>(
                            key: const Key('service-mode'),
                            segments: const {'proportional': 'By what they had', 'even': 'Evenly'},
                            selected: split.rules.serviceMode,
                            onChanged: (mode) {
                              if (mode != split.rules.serviceMode) _patch({'serviceMode': mode});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: 12),
                    if (preview.rules == null)
                      WarningCard(message: preview.message ?? "I didn't catch a rule in that.")
                    else
                      _ConfirmCard(
                        text: preview.confirmationText ?? 'Use these rules?',
                        onYes: () => _confirm(preview.rules!),
                        onNo: () => setState(() => _preview = null),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('rules-message'),
                      controller: _message,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(hintText: "Tell Split a rule, like 'Sam's on us'", counterText: ''),
                      onSubmitted: (_) => _ask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _asking ? null : _ask,
                    style: IconButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size(48, 48)),
                    icon: SplitIcon(SplitIcons.send, size: 20, color: c.surface),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
              child: PrimaryButton(
                label: 'Work out the totals',
                onPressed: ok ? () => context.go('/split/${widget.splitId}/breakdown') : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everyone with a claim on [line], in claim order.
List<String> _sharers(SplitDoc split, ReceiptLine line) =>
    [for (final c in split.claims[line.id]?.claims ?? const <Claim>[]) c.participantId];

/// "Kemi", "Kemi and Josh", "Kemi, Josh and Dan".
String _listNames(List<String> names) =>
    names.length <= 1 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(SplitShape.cardRadius),
      ),
      child: child,
    );
  }
}

/// "Prawn crackers, £5.50 / Shared by all 5, £1.10 each".
class _SharedRow extends StatelessWidget {
  const _SharedRow({required this.split, required this.line, required this.people});
  final SplitDoc split;
  final ReceiptLine line;
  final List<Participant> people;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final byId = {for (final p in people) p.id: p};
    final claims = split.claims[line.id]?.claims ?? const <Claim>[];
    final who = [for (final cl in claims) if (byId[cl.participantId] != null) byId[cl.participantId]!];
    final names = [for (final p in who) p.name];
    final everyone = who.length == people.length && people.length > 2;
    final oneEach = line.qty > 1 && claims.every((cl) => cl.weight == 1) && claims.length == line.qty;

    // Amounts from computed only, and only once the bill adds up.
    final computed = split.computed;
    final amounts = computed != null && computed.ok
        ? {
            for (final p in who)
              computed.perParticipant[p.id]?.lines.where((l) => l.lineId == line.id).firstOrNull?.minor,
          }
        : const <int?>{};
    final each = amounts.length == 1 && amounts.first != null ? ', ${formatGbp(amounts.first!)} each' : '';

    final detail = oneEach
        ? 'One each for ${_listNames(names)}'
        : everyone
            ? 'Shared by all ${who.length}$each'
            : 'Shared by ${_listNames(names)}$each';
    final title = '${line.name}${line.qty > 1 ? ' x${line.qty}' : ''}'
        '${line.lineTotalMinor == null ? '' : ', ${formatGbp(line.lineTotalMinor!)}'}';

    return _Card(
      child: Row(
        children: [
          AvatarStack(people: [for (final p in who) (name: p.name, colourIndex: p.colourIndex)], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(detail, style: text.bodySmall?.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sam's on us / £29.10 covered by the other 4", with a switch.
class _OnUsRow extends StatelessWidget {
  const _OnUsRow({required this.person, required this.split, required this.coveredBy, required this.onChanged});
  final Participant person;
  final SplitDoc split;

  /// "the other 4", or "Kemi and Josh" when the rule names who covers it.
  final String coveredBy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final on = split.rules.onUs.contains(person.id);
    final moved = split.computed?.ok ?? false ? -(split.computed!.perParticipant[person.id]?.sharedFromOnUsMinor ?? 0) : 0;
    final name = person.name;
    final possessive = name.endsWith('s') ? "$name'" : "$name's";
    final detail = !on
        ? 'Pays for what they had'
        : moved > 0
            ? '${formatGbp(moved)} covered by $coveredBy'
            : 'Covered by $coveredBy';

    return _Card(
      child: Row(
        children: [
          Avatar(name: name, colourIndex: person.colourIndex, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$possessive on us', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(detail, style: text.bodySmall?.copyWith(color: c.muted)),
              ],
            ),
          ),
          Switch(key: Key('on-us-${person.id}'), value: on, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.text, required this.onYes, required this.onNo});
  final String text;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final style = Theme.of(context).textTheme;
    return Container(
      key: const Key('rules-confirm'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(SplitShape.cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: style.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: onYes, child: const Text('Yes'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: onNo, child: const Text('Not quite'))),
            ],
          ),
        ],
      ),
    );
  }
}
