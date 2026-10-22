import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organiser.dart';
import 'api_provider.dart';

/// Signs the organiser in anonymously.
///
/// The anonymous sign-in means a judge opens the hosted build and is already
/// an organiser, scoped to their own uid. It returns as soon as there is a
/// uid, so a returning organiser's name and bills stream straight from
/// Firestore without waiting on the API, which can take many seconds to
/// answer on a first visit.
final organiserIdProvider = FutureProvider<String>((ref) async {
  final auth = FirebaseAuth.instance;
  return auth.currentUser?.uid ?? (await auth.signInAnonymously()).user!.uid;
});

/// Makes sure the organiser's doc exists. Idempotent, so it runs on every
/// launch. With `demo: true` a new organiser is "Kemi" with the Little Bao
/// House bill waiting in draft (plan decision D11). Anything that needs the
/// doc to exist first, like reading a receipt, waits on this.
final bootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(organiserIdProvider.future);
  try {
    await ref.read(apiClientProvider).postJson('/v1/session/bootstrap', {
      'demo': true,
    });
  } catch (_) {
    // An organiser with existing splits must still get in when the API is
    // unreachable: their splits come from Firestore directly, not from here.
  }
});

/// The live organiser doc. Null until bootstrap has written it.
final organiserProvider = StreamProvider<Organiser?>((ref) {
  final organiserId = ref.watch(organiserIdProvider).value;
  if (organiserId == null) return const Stream<Organiser?>.empty();
  return FirebaseFirestore.instance.doc('organisers/$organiserId').snapshots().map(
        (snap) => snap.exists ? Organiser.fromJson({...snap.data()!, 'id': snap.id}) : null,
      );
});

/// Saves the organiser's name and PayPal email (endpoint 3). The new values
/// come back through [organiserProvider]; nothing is cached here.
final saveOrganiserProvider = Provider<Future<void> Function(Map<String, Object?> changes)>((ref) {
  return (changes) => ref.read(apiClientProvider).patchJson('/v1/session/organiser', changes);
});
