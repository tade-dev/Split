import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/theme/split_theme.dart';
import 'package:split/features/home/home_screen.dart';
import 'package:split/features/scan/camera_port.dart';
import 'package:split/features/scan/reading_screen.dart';
import 'package:split/features/scan/scan_screen.dart';
import 'package:split/features/split/claims_screen.dart';
import 'package:split/features/split/breakdown_screen.dart';
import 'package:split/features/split/tracker_screen.dart';
import 'package:split/features/split/rules_screen.dart';
import 'package:split/features/split/people_screen.dart';
import 'package:split/models/participant.dart';
import 'package:split/features/split/receipt_screen.dart';
import 'package:split/models/organiser.dart';
import 'package:split/models/split.dart';
import 'package:split/providers/organiser_provider.dart';
import 'package:split/providers/splits_providers.dart';
import 'package:split/router.dart';

class _NoCamera implements CameraPort {
  @override
  Future<CameraStatus> open() async => CameraStatus.unavailable;
  @override
  Widget preview() => const SizedBox();
  @override
  Future<({List<int> bytes, String filename})> capture() => throw UnsupportedError('none');
  @override
  Future<void> close() async {}
}

void main() {
  final routes = <String, Type>{
    '/': HomeScreen,
    '/scan': ScanScreen,
    '/split/reading': ReadingScreen,
    '/split/s1/receipt': ReceiptScreen,
    '/split/s1/people': PeopleScreen,
    '/split/s1/claims': ClaimsScreen,
    '/split/s1/rules': RulesScreen,
    '/split/s1/breakdown': BreakdownScreen,
    '/split/s1': TrackerScreen,
  };

  for (final MapEntry(key: path, value: screen) in routes.entries) {
    testWidgets('$path builds $screen', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapProvider.overrideWith((ref) async {}),
          organiserProvider.overrideWith((ref) => Stream.value(const Organiser(id: 'kemi', displayName: 'Kemi'))),
          splitsProvider.overrideWith((ref) => Stream.value(const <SplitDoc>[])),
          splitProvider.overrideWith((ref, id) => Stream.value(SplitDoc(id: id))),
          participantsProvider.overrideWith((ref, id) => Stream.value(const <Participant>[])),
          cameraPortProvider.overrideWithValue(_NoCamera()),
          scanControllerProvider.overrideWith(_Reading.new),
        ],
        child: MaterialApp.router(theme: splitTheme(), routerConfig: appRouter),
      ));
      appRouter.go(path);
      await tester.pump();
      await tester.pump();
      expect(find.byType(screen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

class _Reading extends ScanController {
  @override
  ScanState build() => const ScanReading(1);
}
