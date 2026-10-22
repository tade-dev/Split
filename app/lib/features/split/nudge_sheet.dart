import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../data/splits_repository.dart';
import '../../models/participant.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/reply_bubble.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';

/// Nudge.dc.html as a sheet over the Tracker: Split drafts a reminder with
/// the friend's own link, the organiser picks a tone and copies it into
/// their chat. Split never sends anything itself.
Future<void> showNudgeSheet(
  BuildContext context, {
  required String splitId,
  required String title,
  required Participant person,
  String? link,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NudgeSheet(splitId: splitId, title: title, person: person, link: link),
    );

class NudgeSheet extends ConsumerStatefulWidget {
  const NudgeSheet({super.key, required this.splitId, required this.title, required this.person, this.link});

  final String splitId;
  final String title;
  final Participant person;

  /// The friend's link, when the split has it cached. The bubble shows it in
  /// its own chip so the organiser can see it survived the draft.
  final String? link;

  @override
  ConsumerState<NudgeSheet> createState() => _NudgeSheetState();
}

const _tones = {'friendly': 'Friendly', 'cheeky': 'Cheeky', 'firm': 'Firm'};

class _NudgeSheetState extends ConsumerState<NudgeSheet> {
  String _tone = 'friendly';
  NudgeDraft? _draft;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tone = _tone;
    setState(() {
      _draft = null;
      _error = null;
    });
    try {
      final draft = await ref.read(splitsApiProvider).draftNudge(widget.splitId, widget.person.id, tone);
      if (mounted && tone == _tone) setState(() => _draft = draft);
    } catch (e) {
      if (mounted && tone == _tone) setState(() => _error = describeApiError(e));
    }
  }

  Future<void> _copy() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _busy = true);
    await Clipboard.setData(ClipboardData(text: draft.text));
    try {
      await ref.read(splitsApiProvider).nudgeSent(widget.splitId, widget.person.id, draft.text);
    } catch (_) {
      // The words are on the clipboard either way; the count is bookkeeping.
    }
    if (!mounted) return;
    SplitToast.success(context, 'Copied. Paste it to ${widget.person.name}');
    Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    setState(() => _busy = true);
    try {
      await ref.read(splitsApiProvider).snoozeNudge(widget.splitId, widget.person.id);
      if (!mounted) return;
      SplitToast.info(context, "We'll bring ${widget.person.name} up again tomorrow");
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      SplitToast.error(context, describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final p = widget.person;
    final draft = _draft;
    final link = widget.link;
    final words = draft == null
        ? null
        : link != null && draft.text.contains(link)
            ? draft.text.replaceFirst(link, '').replaceAll(RegExp(r'\s+$'), '').replaceAll(RegExp(r'[ \t]{2,}'), ' ')
            : draft.text;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: p.name, colourIndex: p.colourIndex, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nudge ${p.name}', style: text.headlineSmall),
                      Text('${formatGbp(p.shareMinor ?? 0)} for ${widget.title}', style: text.bodyMedium?.copyWith(color: c.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Split drafted this for you', style: text.labelMedium?.copyWith(color: c.muted)),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: text.bodyMedium?.copyWith(color: c.warningText))
            else
              ReplyBubble(
                key: const Key('nudge-bubble'),
                text: words,
                link: draft != null && link != null && draft.text.contains(link) ? link : null,
                placeholder: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [SkeletonLine(width: 220, dark: true), SizedBox(height: 8), SkeletonLine(width: 160, dark: true)],
                ),
              ),
            if (draft != null && draft.shouldSkip && draft.skipReason != null) ...[
              const SizedBox(height: 8),
              Text(draft.skipReason!, style: text.bodySmall?.copyWith(color: c.muted)),
            ],
            const SizedBox(height: 16),
            Text('Tone', style: text.labelMedium?.copyWith(color: c.muted)),
            const SizedBox(height: 8),
            SegmentedControl<String>(
              segments: _tones,
              selected: _tone,
              onChanged: (tone) {
                if (tone == _tone) return;
                setState(() => _tone = tone);
                _load();
              },
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Copy nudge',
              icon: SplitIcons.copy,
              onPressed: draft == null || _busy ? null : _copy,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : _snooze, child: const Text('Remind me tomorrow')),
          ],
        ),
      ),
    );
  }
}
