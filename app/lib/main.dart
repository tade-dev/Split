import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/split_theme.dart';
import 'firebase_options.dart';
import 'providers/organiser_provider.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: SplitApp()));
}

class SplitApp extends ConsumerWidget {
  const SplitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read at the root so signing in and seeding the demo split happen on
    // launch, not the first time a screen needs the organiser.
    ref.watch(bootstrapProvider);

    return MaterialApp.router(
      title: 'Split',
      theme: splitTheme(),
      routerConfig: appRouter,
    );
  }
}
