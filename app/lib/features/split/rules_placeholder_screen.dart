import 'package:flutter/material.dart';

import '../../core/theme/split_shape.dart';
import '../../widgets/split_app_bar.dart';

/// Holds the Rules route until the rules screen lands (plan Task 7), so
/// *Totals* goes somewhere honest.
class RulesPlaceholderScreen extends StatelessWidget {
  const RulesPlaceholderScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SplitAppBar(title: 'Totals', fallback: '/split/$splitId/claims'),
        body: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text(
            'Everything is claimed. Rules and totals arrive with the next build.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
