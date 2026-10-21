import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../data/splits_repository.dart';
import '../../models/participant.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';
import '../../widgets/split_toast.dart';

/// Seven friends at most: eight colours, the organiser's first. The API
/// refuses an eighth too; this keeps the field from offering one.
const maxFriends = 7;

/// Who was there? (People.dc.html). Type a name, it joins on its colour; the
/// organiser is already in and cannot be taken out. *Ask everyone what they
/// had* sends the links and hands over the group message.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key, required this.splitId});

  final String splitId;

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  bool _opening = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  SplitsApi get _api => ref.read(splitsApiProvider);

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    _name.clear();
    _focus.requestFocus();
    try {
      await _api.addPeople(widget.splitId, [name]);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  Future<void> _remove(Participant p) async {
    try {
      await _api.removePerson(widget.splitId, p.id);
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    }
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final opened = await _api.open(widget.splitId);
      if (!mounted) return;
      await showGroupMessageSheet(context, opened.groupMessage);
      if (mounted) context.go('/split/${widget.splitId}/claims');
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final split = ref.watch(splitProvider(widget.splitId)).value;
    final people = ref.watch(participantsProvider(widget.splitId)).value ?? const <Participant>[];
    final friends = people.where((p) => !p.isOrganiser).length;
    final full = friends >= maxFriends;
    // Before lock only (spec §4 endpoint 7); the organiser always stays.
    final canRemove = split == null || split.isDraft || split.status == 'claiming';

    return Scaffold(
      appBar: SplitAppBar(title: split?.title ?? '', fallback: '/split/${widget.splitId}/receipt'),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
                children: [
                  Text('Who was there?', style: text.headlineLarge),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('person-name'),
                    controller: _name,
                    focusNode: _focus,
                    enabled: !full,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: full ? 'That is everyone Split can take' : 'Type a name',
                      counterText: '',
                      suffixIcon: IconButton(
                        tooltip: 'Add',
                        onPressed: full ? null : _add,
                        icon: const SplitIcon(SplitIcons.add),
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                  const SizedBox(height: 12),
                  for (final p in people)
                    _PersonRow(
                      person: p,
                      onRemove: p.isOrganiser || !canRemove ? null : () => _remove(p),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.primaryTint,
                      borderRadius: BorderRadius.circular(SplitShape.cardRadius),
                    ),
                    child: Row(
                      children: [
                        SplitIcon(SplitIcons.link, size: 22, color: c.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Everyone gets their own link', style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text('Drop them in your group chat. No app needed.',
                                  style: text.bodySmall?.copyWith(color: c.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
              child: PrimaryButton(
                label: 'Ask everyone what they had',
                onPressed: friends == 0 || _opening ? null : _open,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.onRemove});
  final Participant person;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      key: Key('person-${person.name}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Avatar(name: person.name, colourIndex: person.colourIndex, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(person.name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                if (person.isOrganiser) Text('You, paid the bill', style: text.bodySmall?.copyWith(color: c.muted)),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove ${person.name}',
              onPressed: onRemove,
              icon: SplitIcon(SplitIcons.close, size: 20, color: c.muted),
            ),
        ],
      ),
    );
  }
}

/// The text to paste in the group chat, with a Copy button. Closing the sheet
/// carries on to the claims screen either way.
Future<void> showGroupMessageSheet(BuildContext context, String message) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        final c = SplitColors.of(sheet);
        final text = Theme.of(sheet).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 0, SplitShape.screenPadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send this to the group', style: text.headlineSmall),
                const SizedBox(height: 12),
                Container(
                  key: const Key('group-message'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(SplitShape.cardRadius),
                  ),
                  child: SelectableText(message, style: text.bodyMedium),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Copy',
                  icon: SplitIcons.copy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message));
                    if (sheet.mounted) {
                      SplitToast.success(sheet, 'Copied. Paste it in your group chat');
                      Navigator.of(sheet).pop();
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.of(sheet).pop(), child: const Text('Done')),
              ],
            ),
          ),
        );
      },
    );
