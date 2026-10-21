import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../data/splits_repository.dart';
import '../../models/ambiguity.dart';
import '../../models/participant.dart';
import '../../models/receipt.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';
import '../../widgets/warning_card.dart';

/// The claim chat (Claim.dc.html). What each friend typed on their link,
/// then what Split added to them, live as they confirm. The organiser can
/// say who had what in the composer, and settle each unclaimed line from its
/// warning. *Totals* opens once nothing is left unclaimed.
class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key, required this.splitId});

  final String splitId;

  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

/// One message the organiser sent this session, and what came of it. The API
/// does not keep these: the claims it wrote are the record.
class _Sent {
  _Sent(this.text);
  final String text;
  ClaimResult? result;
  String? error;
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {
  final _message = TextEditingController();
  final _sent = <_Sent>[];
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  SplitsApi get _api => ref.read(splitsApiProvider);

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    final sent = _Sent(text);
    setState(() {
      _sending = true;
      _sent.add(sent);
      _message.clear();
    });
    try {
      final result = await _api.claimMessage(widget.splitId, text);
      if (mounted) setState(() => sent.result = result);
    } catch (e) {
      if (mounted) setState(() => sent.error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// A warning's option. *Share between …* marks the line shared, keeping who
  /// already claimed it, or putting everyone on it when nobody did.
  Future<void> _answer(SplitDoc split, List<Participant> people, ReceiptLine line, String option) async {
    if (!option.startsWith('Share between')) {
      await Clipboard.setData(ClipboardData(text: 'Who had the ${line.name.toLowerCase()}?'));
      if (mounted) SplitToast.success(context, 'Copied. Paste it in your group chat');
      return;
    }
    final current = split.claims[line.id]?.claims ?? const <Claim>[];
    final claims = current.isEmpty ? [for (final p in people) Claim(participantId: p.id)] : current;
    try {
      await _api.patchClaims(widget.splitId, line.id, claims, shared: true);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final split = ref.watch(splitProvider(widget.splitId)).value;
    final people = ref.watch(participantsProvider(widget.splitId)).value ?? const <Participant>[];
    final lines = split?.receipt.lines ?? const <ReceiptLine>[];
    final problems = [
      for (final p in split?.computed?.problems ?? const <Ambiguity>[])
        if (p.field.startsWith('claims.')) p,
    ];
    final unclaimed = {for (final p in problems) if (p.kind == 'unclaimed') p.field.substring('claims.'.length)};
    final claimedCount = lines.where((l) => !unclaimed.contains(l.id)).length;
    final ready = split != null && unclaimed.isEmpty && (split.computed?.ok ?? false);

    return Scaffold(
      appBar: SplitAppBar(
        title: split?.title ?? '',
        fallback: '/split/${widget.splitId}/people',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              key: const Key('totals'),
              style: TextButton.styleFrom(backgroundColor: ready ? c.primaryTint : null),
              onPressed: ready ? () => context.go('/split/${widget.splitId}/rules') : null,
              child: const Text('Totals'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: lines.isEmpty ? 0 : claimedCount / lines.length,
                        minHeight: 8,
                        color: c.primary,
                        backgroundColor: c.neutralTint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$claimedCount of ${lines.length} items claimed',
                    style: text.bodySmall?.copyWith(color: c.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  if (split != null)
                    for (final p in _claimants(split, people)) ...[
                      if (p.claimText != null) _FriendBubble(person: p),
                      _AddedCard(person: p, rows: _rowsFor(split, p)),
                      const SizedBox(height: 10),
                    ],
                  for (final s in _sent) ...[_SentBubble(sent: s), const SizedBox(height: 10)],
                  if (split != null)
                    for (final p in problems) ...[
                      _problemCard(split, people, lines, p),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('claim-message'),
                      controller: _message,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(hintText: 'Message the group', counterText: ''),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size(48, 48)),
                    icon: SplitIcon(SplitIcons.send, size: 20, color: c.surface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _problemCard(SplitDoc split, List<Participant> people, List<ReceiptLine> lines, Ambiguity p) {
    final lineId = p.field.substring('claims.'.length);
    final line = lines.where((l) => l.id == lineId).firstOrNull;
    if (line == null || p.options.isEmpty) return WarningCard(message: p.question);
    return WarningCard(
      key: Key('unclaimed-$lineId'),
      message: p.question,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, option) in p.options.indexed)
            i == 0
                ? FilledButton(onPressed: () => _answer(split, people, line, option), child: Text(option))
                : OutlinedButton(onPressed: () => _answer(split, people, line, option), child: Text(option)),
        ],
      ),
    );
  }
}

/// Everyone with something claimed, in the order they claimed it.
List<Participant> _claimants(SplitDoc split, List<Participant> people) {
  bool hasClaims(Participant p) => split.claims.values.any((e) => e.claims.any((c) => c.participantId == p.id));
  final out = [for (final p in people) if (p.claimText != null || hasClaims(p)) p];
  out.sort((a, b) {
    final at = a.claimedAt, bt = b.claimedAt;
    if (at != null && bt != null && at != bt) return at.compareTo(bt);
    if ((at == null) != (bt == null)) return at == null ? 1 : -1;
    return a.joinOrder.compareTo(b.joinOrder);
  });
  return out;
}

/// "Lager, 2 of 3", with the amount once the bill adds up. Amounts come
/// from `computed` only; the app never works money out itself.
List<({String label, int? minor})> _rowsFor(SplitDoc split, Participant p) {
  final breakdown = (split.computed?.ok ?? false) ? split.computed!.perParticipant[p.id] : null;
  final rows = <({String label, int? minor})>[];
  for (final line in split.receipt.lines) {
    final entry = split.claims[line.id];
    final weight = (entry?.claims ?? const <Claim>[])
        .where((c) => c.participantId == p.id)
        .fold<int>(0, (t, c) => t + c.weight);
    if (weight == 0) continue;
    final others = entry!.claims.any((c) => c.participantId != p.id);
    final label = line.qty == 1
        ? (others ? '${line.name}, shared' : line.name)
        : (weight >= line.qty && !others ? line.name : '${line.name}, $weight of ${line.qty}');
    final minor = breakdown?.lines.where((l) => l.lineId == line.id).firstOrNull?.minor;
    rows.add((label: label, minor: minor));
  }
  return rows;
}

class _FriendBubble extends StatelessWidget {
  const _FriendBubble({required this.person});
  final Participant person;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Avatar(name: person.name, colourIndex: person.colourIndex, size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(person.name, style: text.bodySmall?.copyWith(color: c.muted)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Text(person.claimText!, style: text.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddedCard extends StatelessWidget {
  const _AddedCard({required this.person, required this.rows});
  final Participant person;
  final List<({String label, int? minor})> rows;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final colour = c.participant(person.colourIndex);
    return Container(
      key: Key('added-${person.id}'),
      margin: const EdgeInsets.only(left: 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colour.fill.withValues(alpha: 0.2),
        border: Border.all(color: colour.fill),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SplitIcon(SplitIcons.check, size: 14, color: c.ink),
              const SizedBox(width: 6),
              Text(
                rows.isEmpty ? '${person.name} claimed nothing yet' : 'Added to ${person.name}',
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(r.label, style: text.bodyMedium)),
                  if (r.minor != null) Text(formatGbp(r.minor!), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SentBubble extends StatelessWidget {
  const _SentBubble({required this.sent});
  final _Sent sent;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final result = sent.result;
    final notes = [
      if (sent.error != null) sent.error!,
      if (result != null) ...[for (final p in result.problems) p.question, ...result.ignored],
    ];
    final added = result?.applied.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(sent.text, style: text.bodyLarge?.copyWith(color: c.surface)),
          ),
        ),
        if (result == null && sent.error == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Matching it to the bill…', style: text.bodySmall?.copyWith(color: c.muted)),
          ),
        if (added > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              added == 1 ? 'Added 1 item' : 'Added $added items',
              style: text.bodySmall?.copyWith(color: c.muted),
            ),
          ),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: WarningCard(message: n),
          ),
      ],
    );
  }
}
