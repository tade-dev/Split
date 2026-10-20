import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../core/uk_date.dart';
import '../../models/ambiguity.dart';
import '../../models/receipt.dart';
import '../../models/split.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/money_roll.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_toast.dart';
import '../../widgets/warning_card.dart';
import 'line_edit_sheet.dart';

/// Check the bill (Receipt.dc.html). The organiser confirms what was read
/// before anyone is asked what they had.
///
/// The screen never decides whether the bill adds up: every warning here is a
/// sentence the API derived from the numbers, so money has one source of
/// truth. Edits go to the API, and the result arrives back on the stream.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(splitProvider(splitId));
    return Scaffold(
      appBar: const SplitAppBar(title: 'Check the bill', fallback: '/'),
      body: switch (split) {
        AsyncData(value: final s?) => _Body(split: s),
        AsyncData() => const _Gone(),
        AsyncError() => const _Gone(),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text('This bill is no longer here.', style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.split});

  final SplitDoc split;

  Future<void> _send(BuildContext context, WidgetRef ref, Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      if (context.mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  Future<void> _editLine(BuildContext context, WidgetRef ref, ReceiptLine line) async {
    final edit = await showLineEditor(context, line: line);
    if (edit == null || !context.mounted) return;
    final api = ref.read(splitsApiProvider);
    switch (edit) {
      case LineRemoved():
        await _send(context, ref, () => api.patchReceipt(split.id, {'removeLineIds': [line.id]}));
      case LineSaved(:final name, :final qty, :final lineTotalMinor):
        final changed = <String, Object?>{
          'id': line.id,
          if (name != line.name) 'name': name,
          if (qty != line.qty) 'qty': qty,
          if (lineTotalMinor != line.lineTotalMinor) 'lineTotalMinor': lineTotalMinor,
        };
        if (changed.length == 1) return;
        await _send(context, ref, () => api.patchReceipt(split.id, {'lines': [changed]}));
    }
  }

  Future<void> _addLine(BuildContext context, WidgetRef ref) async {
    final edit = await showLineEditor(context);
    if (edit is! LineSaved || !context.mounted) return;
    await _send(
      context,
      ref,
      () => ref.read(splitsApiProvider).patchReceipt(split.id, {
        'addLines': [
          {'name': edit.name, 'qty': edit.qty, 'lineTotalMinor': edit.lineTotalMinor},
        ],
      }),
    );
  }

  Future<void> _editTotal(BuildContext context, WidgetRef ref) async {
    final total = await showTotalEditor(context, current: split.receipt.printedTotalMinor);
    if (total == null || !context.mounted) return;
    await _send(context, ref, () => ref.read(splitsApiProvider).patchReceipt(split.id, {'printedTotalMinor': total}));
  }

  /// A question about a line opens that line; one about the total opens the
  /// total. The rest ("check the photo or edit a line") need no single target.
  VoidCallback? _resolver(BuildContext context, WidgetRef ref, Ambiguity a) {
    final lineId = RegExp(r'^lines\.([^.]+)').firstMatch(a.field)?.group(1);
    final line = lineId == null ? null : split.receipt.lines.where((l) => l.id == lineId).firstOrNull;
    if (line != null) return () => _editLine(context, ref, line);
    if (a.field == 'printedTotalMinor' && a.kind == 'missing') return () => _editTotal(context, ref);
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final receipt = split.receipt;
    final count = receipt.lines.length;
    final subtitle = [
      if (split.receiptDate != null) '${formatUkDate(split.receiptDate!)}.',
      'Split read $count ${count == 1 ? 'item' : 'items'}.',
    ].join(' ');

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
              children: [
                Text(split.merchant ?? split.title, style: text.headlineLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodyMedium?.copyWith(color: c.muted)),
                for (final a in split.blocking) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _resolver(context, ref, a),
                    child: WarningCard(message: a.question),
                  ),
                ],
                for (final a in split.notes) ...[
                  const SizedBox(height: 12),
                  _Note(question: a.question, onTap: _resolver(context, ref, a)),
                ],
                const SizedBox(height: 12),
                _Lines(lines: receipt.lines, onTap: (l) => _editLine(context, ref, l)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _addLine(context, ref),
                    child: const Text('Add a line'),
                  ),
                ),
                if (receipt.serviceChargeMinor > 0) ...[
                  const SizedBox(height: 4),
                  WarningCard(
                    message: _serviceQuestion(receipt),
                    child: SegmentedControl<String>(
                      segments: const {'proportional': 'By what they had', 'even': 'Evenly'},
                      selected: split.rules.serviceMode,
                      onChanged: (mode) => _send(
                        context,
                        ref,
                        () => ref.read(splitsApiProvider).patchRules(split.id, {'serviceMode': mode}),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text('Total paid by you', style: text.titleSmall)),
                      receipt.printedTotalMinor == null
                          ? Text('Not read yet', style: text.bodyMedium?.copyWith(color: c.warningText))
                          : MoneyRoll(amountMinor: receipt.printedTotalMinor!, style: text.headlineMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
            child: PrimaryButton(
              label: 'Add people',
              onPressed: split.blocking.isEmpty ? () => context.push('/split/${split.id}/people') : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Found a 12.5% service charge (£17.19). Split it by what each person had?"
/// The rate comes from the printed label when there is one.
String _serviceQuestion(Receipt r) {
  final rate = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(r.serviceChargeLabel ?? '')?.group(1);
  final what = rate == null ? 'a service charge' : 'a $rate% service charge';
  return 'Found $what (${formatGbp(r.serviceChargeMinor)}). Split it by what each person had?';
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.onTap});
  final List<ReceiptLine> lines;
  final ValueChanged<ReceiptLine> onTap;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(SplitShape.cardRadius),
      ),
      child: Column(
        children: [
          for (final line in lines)
            InkWell(
              onTap: () => onTap(line),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: SplitShape.minTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(width: 22, child: Text('${line.qty}', style: text.bodyMedium?.copyWith(color: c.muted))),
                      Expanded(child: Text(line.name, style: text.bodyMedium)),
                      line.lineTotalMinor == null
                          ? Text('Add price', style: text.bodyMedium?.copyWith(color: c.warningText, fontWeight: FontWeight.w600))
                          : Text(formatGbp(line.lineTotalMinor!), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The model's own question: worth reading, never in the way.
class _Note extends StatelessWidget {
  const _Note({required this.question, this.onTap});
  final String question;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.primaryTint,
          borderRadius: BorderRadius.circular(SplitShape.cardRadius),
        ),
        child: Text(question, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.ink)),
      ),
    );
  }
}
