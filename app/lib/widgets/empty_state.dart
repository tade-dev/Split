import 'package:flutter/material.dart';

import '../core/theme/split_colors.dart';
import '../core/theme/split_shape.dart';
import 'split_icon.dart';

/// A centred icon, headline, one line of help and at most one action: what a
/// screen shows when there is nothing to show, or it could not load.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});

  final SplitIconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SplitShape.screenPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SplitIcon(icon, size: 36, color: c.muted),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: text.bodyMedium?.copyWith(color: c.muted), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
