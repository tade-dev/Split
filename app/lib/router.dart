import 'package:go_router/go_router.dart';

import 'core/motion/split_motion.dart';
import 'features/home/home_screen.dart';
import 'features/scan/reading_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/split/claims_screen.dart';
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
      pageBuilder: (_, s) => splitPushPage(s, ReceiptScreen(splitId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/split/:id/people',
      pageBuilder: (_, s) => splitPushPage(s, PeopleScreen(splitId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/split/:id/claims',
      pageBuilder: (_, s) => splitPushPage(s, ClaimsScreen(splitId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/split/:id/rules',
      pageBuilder: (_, s) => splitPushPage(s, RulesScreen(splitId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/split/:id/breakdown',
      pageBuilder: (_, s) => splitPushPage(s, BreakdownScreen(splitId: s.pathParameters['id']!)),
    ),
    // Last, so /split/reading above wins over the id.
    GoRoute(
      path: '/split/:id',
      pageBuilder: (_, s) => splitPushPage(s, TrackerScreen(splitId: s.pathParameters['id']!)),
    ),
  ],
);
