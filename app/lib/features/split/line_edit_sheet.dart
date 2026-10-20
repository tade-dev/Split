import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/receipt.dart';
import '../../widgets/primary_button.dart';

/// What the organiser did in the line sheet.
sealed class LineEdit {
  const LineEdit();
}

class LineSaved extends LineEdit {
  const LineSaved({required this.name, required this.qty, required this.lineTotalMinor});
  final String name;
  final int qty;
  final int lineTotalMinor;
}

class LineRemoved extends LineEdit {
  const LineRemoved();
}

const _priceHint = 'Enter an amount like 16.50';

/// Edits one printed line, or adds one when [line] is null. The price is the
/// line total as printed ("Lager x3 16.50" is 16.50), never a unit price.
Future<LineEdit?> showLineEditor(BuildContext context, {ReceiptLine? line}) =>
    showModalBottomSheet<LineEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LineEditSheet(line: line),
    );

/// Asks for the printed total when it could not be read.
Future<int?> showTotalEditor(BuildContext context, {int? current}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TotalSheet(current: current),
    );

class _LineEditSheet extends StatefulWidget {
  const _LineEditSheet({this.line});
  final ReceiptLine? line;

  @override
  State<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends State<_LineEditSheet> {
  late final _name = TextEditingController(text: widget.line?.name ?? '');
  late final _qty = TextEditingController(text: '${widget.line?.qty ?? 1}');
  late final _price = TextEditingController(
    text: widget.line?.lineTotalMinor == null ? '' : formatGbp(widget.line!.lineTotalMinor!).substring(1),
  );
  String? _nameError;
  String? _qtyError;
  String? _priceError;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final qty = int.tryParse(_qty.text.trim());
    final price = parseGbpInput(_price.text);
    setState(() {
      _nameError = name.isEmpty ? 'Add the name as printed' : null;
      _qtyError = qty == null || qty < 1 || qty > 99 ? 'A number from 1 to 99' : null;
      _priceError = price == null ? _priceHint : null;
    });
    if (_nameError != null || _qtyError != null || _priceError != null) return;
    Navigator.of(context).pop(LineSaved(name: name, qty: qty!, lineTotalMinor: price!));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = SplitColors.of(context);
    return _SheetFrame(
      title: widget.line == null ? 'Add a line' : 'Edit line',
      children: [
        TextField(
          key: const Key('line-name'),
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Name, as printed', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: TextField(
                key: const Key('line-qty'),
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Qty', errorText: _qtyError),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('line-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Line total',
                  prefixText: '£',
                  errorText: _priceError,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Save', onPressed: _save),
        if (widget.line != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(const LineRemoved()),
                child: Text('Remove this line', style: text.labelLarge?.copyWith(color: c.warningText)),
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalSheet extends StatefulWidget {
  const _TotalSheet({this.current});
  final int? current;

  @override
  State<_TotalSheet> createState() => _TotalSheetState();
}

class _TotalSheetState extends State<_TotalSheet> {
  late final _total = TextEditingController(
    text: widget.current == null ? '' : formatGbp(widget.current!).substring(1),
  );
  String? _error;

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  void _save() {
    final total = parseGbpInput(_total.text);
    if (total == null) {
      setState(() => _error = _priceHint);
      return;
    }
    Navigator.of(context).pop(total);
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: 'Total on the bill',
        children: [
          TextField(
            key: const Key('total-price'),
            controller: _total,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Total', prefixText: '£', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save', onPressed: _save),
        ],
      );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          SplitShape.screenPadding,
          0,
          SplitShape.screenPadding,
          SplitShape.screenPadding + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
}
