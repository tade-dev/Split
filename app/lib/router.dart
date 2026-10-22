import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/split_motion.dart';
import 'features/home/home_screen.dart';
import 'features/scan/reading_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/split/claims_screen.dart';
import 'features/split/split_gate.dart';
import 'features/split/people_screen.dart';
import 'features/split/breakdown_screen.dart';
import 'features/split/rules_screen.dart';
import 'features/split/tracker_screen.dart';
import 'features/split/receipt_screen.dart';

/// Push for further along the task, sheet for something that sits over it
/// to be dismissed back (the camera). Split has a single Home with a primary
/// "Split a new bill", so there is no tab shell.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (_, s) => splitPushPage(s, const HomeScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, s) => splitPushPage(s, const SettingsScreen()),
    ),
    GoRoute(
      path: '/scan',
      pageBuilder: (_, s) => splitSheetPage(s, const ScanScreen()),
    ),
    // No id in the path: the split does not exist until the scan returns
    // (plan decision D9).
    GoRoute(
      path: '/split/reading',
      pageBuilder: (_, s) => splitPushPage(s, const ReadingScreen()),
    ),
    GoRoute(
      path: '/split/:id/receipt',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => ReceiptScreen(splitId: id))),
    ),
    GoRoute(
      path: '/split/:id/people',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => PeopleScreen(splitId: id))),
    ),
    GoRoute(
      path: '/split/:id/claims',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => ClaimsScreen(splitId: id))),
    ),
    GoRoute(
      path: '/split/:id/rules',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => RulesScreen(splitId: id))),
    ),
    GoRoute(
      path: '/split/:id/breakdown',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => BreakdownScreen(splitId: id))),
    ),
    // Last, so /split/reading above wins over the id.
    GoRoute(
      path: '/split/:id',
      pageBuilder: (_, s) => splitPushPage(s, _gated(s, (id) => TrackerScreen(splitId: id))),
    ),
  ],
);

/// Every screen of one bill goes through [SplitGate].
Widget _gated(GoRouterState s, Widget Function(String id) screen) {
  final id = s.pathParameters['id']!;
  return SplitGate(splitId: id, child: screen(id));
}
