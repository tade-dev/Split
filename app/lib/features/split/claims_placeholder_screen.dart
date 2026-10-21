import 'package:flutter/material.dart';

import '../../core/theme/split_shape.dart';
import '../../widgets/split_app_bar.dart';

/// Holds the Claims route until the claim chat lands (plan Task 6), so
/// sending the links goes somewhere honest.
class ClaimsPlaceholderScreen extends StatelessWidget {
  const ClaimsPlaceholderScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SplitAppBar(title: 'What everyone had', fallback: '/split/$splitId/people'),
        body: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text(
            'The links are out. Claims show up here with the next build.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
