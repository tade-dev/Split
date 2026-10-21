import 'package:flutter/material.dart';

import '../../core/theme/split_shape.dart';
import '../../widgets/split_app_bar.dart';

/// Holds the Breakdown route until the breakdown lands (plan Task 8), so
/// *Work out the totals* goes somewhere honest.
class BreakdownPlaceholderScreen extends StatelessWidget {
  const BreakdownPlaceholderScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SplitAppBar(title: 'Totals', fallback: '/split/$splitId/rules'),
        body: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text(
            'The rules are set. The breakdown arrives with the next build.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
