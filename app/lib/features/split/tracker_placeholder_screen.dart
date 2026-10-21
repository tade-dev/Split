import 'package:flutter/material.dart';

import '../../core/theme/split_shape.dart';
import '../../widgets/split_app_bar.dart';

/// Holds the Tracker route until the tracker lands (plan Task 11), so
/// *Send links* goes somewhere honest.
class TrackerPlaceholderScreen extends StatelessWidget {
  const TrackerPlaceholderScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SplitAppBar(title: 'Who has paid', fallback: '/split/$splitId/breakdown'),
        body: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text(
            'The split is locked and everyone can pay from their link. Live payments show here with the next build.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
