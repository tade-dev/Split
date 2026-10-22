import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/splits_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/split_app_bar.dart';
import '../../widgets/split_icon.dart';

/// Stands in front of every `/split/:id` screen. The screens themselves
/// only handle "still loading" (they draw from whatever has arrived); this
/// covers a bill that could not load, one that is not there (an old or
/// mistyped link), and one the organiser cancelled.
class SplitGate extends ConsumerWidget {
  const SplitGate({super.key, required this.splitId, required this.child});

  final String splitId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(splitProvider(splitId));
    final Widget? stop = switch (async) {
      AsyncValue(hasError: true, hasValue: false) => EmptyState(
          key: const Key('split-error'),
          icon: SplitIcons.alert,
          title: "Couldn't load this bill",
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(splitProvider(splitId)),
        ),
      AsyncData(value: null) => EmptyState(
          key: const Key('split-missing'),
          icon: SplitIcons.orders,
          title: "This bill isn't here",
          body: 'It may have been from an old link. Your bills are on Home.',
          actionLabel: 'Go to Home',
          onAction: () => context.go('/'),
        ),
      AsyncData(value: final split?) when split.status == 'cancelled' => EmptyState(
          key: const Key('split-cancelled'),
          icon: SplitIcons.close,
          title: '${split.title} was cancelled',
          body: "Nobody can pay it now, and friends' links say so.",
          actionLabel: 'Go to Home',
          onAction: () => context.go('/'),
        ),
      _ => null,
    };
    if (stop == null) return child;
    return Scaffold(appBar: const SplitAppBar(fallback: '/'), body: SafeArea(child: stop));
  }
}
