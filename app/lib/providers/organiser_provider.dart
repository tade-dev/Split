import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organiser.dart';
import 'api_provider.dart';

/// Signs the organiser in anonymously and makes sure their doc exists.
///
/// The anonymous sign-in means a judge opens the hosted build and is already
/// an organiser, scoped to their own uid. Bootstrap is idempotent, so running
/// it on every launch is safe. With `demo: true` a new organiser is "Kemi"
/// with the Little Bao House bill waiting in draft (plan decision D11).
final organiserIdProvider = FutureProvider<String>((ref) async {
  final auth = FirebaseAuth.instance;
  final uid = auth.currentUser?.uid ??
      (await auth.signInAnonymously()).user!.uid;

  try {
    await ref.read(apiClientProvider).postJson('/v1/session/bootstrap', {
      'demo': true,
    });
  } catch (_) {
    // An organiser with existing splits must still get in when the API is
    // unreachable: their splits come from Firestore directly, not from here.
  }

  return uid;
});

/// The live organiser doc. Null until bootstrap has written it.
final organiserProvider = StreamProvider<Organiser?>((ref) {
  final organiserId = ref.watch(organiserIdProvider).value;
  if (organiserId == null) return const Stream<Organiser?>.empty();
  return FirebaseFirestore.instance.doc('organisers/$organiserId').snapshots().map(
        (snap) => snap.exists ? Organiser.fromJson({...snap.data()!, 'id': snap.id}) : null,
      );
});
