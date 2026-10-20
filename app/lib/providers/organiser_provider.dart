import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_provider.dart';

/// Signs the organiser in anonymously and makes sure their doc exists.
///
/// The anonymous sign-in means a judge opens the hosted build and is already
/// an organiser, scoped to their own uid. Bootstrap is idempotent, so running
/// it on every launch is safe. The organiser doc stream and Settings updater
/// arrive with Split's own organiser model.
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
