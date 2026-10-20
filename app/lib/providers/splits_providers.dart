import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/splits_repository.dart';
import '../models/participant.dart';
import '../models/split.dart';
import 'api_provider.dart';
import 'organiser_provider.dart';

final splitsApiProvider = Provider<SplitsApi>(
  (ref) => HttpSplitsApi(ref.watch(apiClientProvider)),
);

final splitsRepositoryProvider = Provider<SplitsRepository>((ref) => SplitsRepository());

/// The organiser's splits, newest first, live.
final splitsProvider = StreamProvider<List<SplitDoc>>((ref) {
  final organiserId = ref.watch(organiserIdProvider).value;
  if (organiserId == null) return const Stream<List<SplitDoc>>.empty();
  return ref.watch(splitsRepositoryProvider).watchSplits(organiserId);
});

final splitProvider = StreamProvider.family<SplitDoc?, String>((ref, splitId) {
  final organiserId = ref.watch(organiserIdProvider).value;
  if (organiserId == null) return const Stream<SplitDoc?>.empty();
  return ref.watch(splitsRepositoryProvider).watchSplit(organiserId, splitId);
});

final participantsProvider = StreamProvider.family<List<Participant>, String>((ref, splitId) {
  final organiserId = ref.watch(organiserIdProvider).value;
  if (organiserId == null) return const Stream<List<Participant>>.empty();
  return ref.watch(splitsRepositoryProvider).watchParticipants(organiserId, splitId);
});

sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

/// The model is reading [photos] photos. Reading's checklist runs meanwhile.
class ScanReading extends ScanState {
  const ScanReading(this.photos);
  final int photos;
}

class ScanReady extends ScanState {
  const ScanReady(this.split);
  final SplitDoc split;
}

class ScanFailed extends ScanState {
  const ScanFailed(this.message);
  final String message;
}

/// One receipt read at a time. Scan and *Try a sample bill* both start it;
/// Reading watches it.
class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanIdle();

  Future<void> read(List<Photo> photos) async {
    if (state is ScanReading) return;
    state = ScanReading(photos.length);
    try {
      state = ScanReady(await ref.read(splitsApiProvider).scan(photos));
    } catch (e) {
      state = ScanFailed(describeApiError(e));
    }
  }

  void reset() => state = const ScanIdle();
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);
