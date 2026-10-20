// Placeholder until Split's own Firebase project exists. Sorted's options are
// deliberately not copied (spec §1). Replace this file by running
// `flutterfire configure` inside app/ against the new project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Split has no Firebase project configured yet. '
        'Run `flutterfire configure` in app/ to generate this file.',
      );
}
