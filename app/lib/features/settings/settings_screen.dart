import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme/split_colors.dart';
import '../../core/theme/split_shape.dart';
import '../../models/organiser.dart';
import '../../providers/organiser_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_toast.dart';

const _repo = 'https://github.com/tade-dev/Split';

/// The name friends see and where their money goes (spec §6 `/settings`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.openLink});

  /// Test hook. By default, a new browser tab.
  final Future<void> Function(Uri url)? openLink;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  Organiser? _loaded;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Fills the fields once, from the first organiser doc, so a save that
  /// streams back never overwrites what is being typed.
  void _fill(Organiser? o) {
    if (o == null || _loaded != null) return;
    _loaded = o;
    _name.text = o.displayName;
    _email.text = o.paypalEmail ?? '';
  }

  Future<void> _save() async {
    final loaded = _loaded;
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      SplitToast.error(context, 'Add the name your friends know you by.');
      return;
    }
    final changes = <String, Object?>{
      if (name != loaded?.displayName) 'displayName': name,
      if (email != (loaded?.paypalEmail ?? '')) 'paypalEmail': email.isEmpty ? null : email,
    };
    if (changes.isEmpty) {
      SplitToast.info(context, 'Nothing to save');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(saveOrganiserProvider)(changes);
      _loaded = (loaded ?? const Organiser(id: '')).copyWith(displayName: name, paypalEmail: email.isEmpty ? null : email);
      if (mounted) SplitToast.success(context, 'Saved');
    } catch (e) {
      if (mounted) SplitToast.error(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    final open = widget.openLink ?? (Uri u) => launchUrl(u, webOnlyWindowName: '_blank');
    await open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    _fill(ref.watch(organiserProvider).value);

    return Scaffold(
      appBar: const SplitAppBar(title: 'Settings', fallback: '/'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SplitShape.screenPadding, 8, SplitShape.screenPadding, 24),
          children: [
            Text('Your name', style: text.titleSmall),
            const SizedBox(height: 4),
            Text('What friends see on their link: "Kemi paid the bill".', style: text.bodySmall?.copyWith(color: c.muted)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('settings-name'),
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your first name', counterText: ''),
            ),
            const SizedBox(height: 24),
            Text('Your PayPal email', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(
              "Friends' payments go straight to this PayPal account. Leave it empty and they go to Split's demo merchant instead.",
              style: text.bodySmall?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('settings-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('sandbox-note'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.neutralTint, borderRadius: BorderRadius.circular(SplitShape.cardRadius)),
              child: Text(
                'This build runs on PayPal sandbox, so no real money moves. Use a sandbox personal account email here.',
                style: text.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Save', onPressed: _busy ? null : _save),
            const SizedBox(height: 32),
            Divider(color: c.line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Source code'),
              subtitle: const Text('github.com/tade-dev/Split'),
              onTap: () => _open(_repo),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Licence'),
              onTap: () => _open('$_repo/blob/main/LICENSE'),
            ),
          ],
        ),
      ),
    );
  }
}
