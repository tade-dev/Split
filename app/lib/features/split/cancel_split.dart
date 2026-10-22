import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../providers/splits_providers.dart';
import '../../widgets/split_toast.dart';

/// Asks, then cancels the split (endpoint 17) and goes home. Friends' links
/// then read "This bill was cancelled" and any open PayPal order is replaced.
Future<void> confirmCancelSplit(BuildContext context, WidgetRef ref, String splitId, {required String title}) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Cancel $title?'),
      content: const Text("Everyone's link will say the bill was cancelled, and nobody can pay it. Anyone who already paid keeps their payment until you sort it with them."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel split')),
      ],
    ),
  );
  if (sure != true || !context.mounted) return;
  try {
    await ref.read(splitsApiProvider).cancel(splitId);
    if (!context.mounted) return;
    SplitToast.info(context, '$title is cancelled');
    GoRouter.maybeOf(context)?.go('/');
  } catch (e) {
    if (context.mounted) SplitToast.error(context, describeApiError(e));
  }
}
