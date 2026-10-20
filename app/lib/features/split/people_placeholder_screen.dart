import 'package:flutter/material.dart';

import '../../core/theme/split_shape.dart';
import '../../widgets/split_app_bar.dart';

/// Holds the People route until Week B builds it from People.dc.html, so
/// Add people on the Receipt screen goes somewhere honest.
class PeoplePlaceholderScreen extends StatelessWidget {
  const PeoplePlaceholderScreen({super.key, required this.splitId});

  final String splitId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SplitAppBar(title: 'Who was there?', fallback: '/split/$splitId/receipt'),
        body: Padding(
          padding: const EdgeInsets.all(SplitShape.screenPadding),
          child: Text(
            'Adding people arrives with the next build. The bill is saved as it is.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
