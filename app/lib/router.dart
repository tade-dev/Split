import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/split_motion.dart';
import 'features/scan/scan_screen.dart';

/// Push for further along the task, sheet for something that sits over it
/// to be dismissed back (the camera). Split has a single Home with a primary
/// "Split a bill", so there is no tab shell; `splitTabPage` stays available
/// in the motion layer for anything that later behaves as a peer.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (_, s) => splitPushPage(s, const _HomePlaceholder()),
    ),
    GoRoute(
      path: '/scan',
      pageBuilder: (_, s) => splitSheetPage(s, const ScanScreen()),
    ),
  ],
);

/// Stands in for Home until the Week A plan builds it from Home.dc.html.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.push('/scan'),
            child: const Text('Split a bill'),
          ),
        ),
      );
}
