// Generated for Firebase project intellispendiq (298945862169).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:intellispendiq/bootstrap.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions currentPlatform({
    AppFlavor flavor = AppFlavor.production,
  }) {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'the Flutter client is Android-first.',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android(flavor),
      TargetPlatform.iOS => throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for ios.',
      ),
      TargetPlatform.macOS => throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for macos.',
      ),
      TargetPlatform.windows => throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for windows.',
      ),
      TargetPlatform.linux => throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for linux.',
      ),
      TargetPlatform.fuchsia => throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      ),
    };
  }

  static FirebaseOptions android(AppFlavor flavor) => switch (flavor) {
    AppFlavor.production => androidProduction,
    AppFlavor.staging => androidStaging,
    AppFlavor.development => androidDevelopment,
  };

  static const FirebaseOptions androidProduction = FirebaseOptions(
    apiKey: 'AIzaSyDoFE2yDIsZuI0K9jiEu2zKNzJa-I6ixyI',
    appId: '1:298945862169:android:7bc99c15da58a31791a888',
    messagingSenderId: '298945862169',
    projectId: 'intellispendiq',
    storageBucket: 'intellispendiq.firebasestorage.app',
  );

  static const FirebaseOptions androidStaging = FirebaseOptions(
    apiKey: 'AIzaSyDoFE2yDIsZuI0K9jiEu2zKNzJa-I6ixyI',
    appId: '1:298945862169:android:1a647cee7591c7d491a888',
    messagingSenderId: '298945862169',
    projectId: 'intellispendiq',
    storageBucket: 'intellispendiq.firebasestorage.app',
  );

  static const FirebaseOptions androidDevelopment = FirebaseOptions(
    apiKey: 'AIzaSyDoFE2yDIsZuI0K9jiEu2zKNzJa-I6ixyI',
    appId: '1:298945862169:android:8cf8337b69c3968591a888',
    messagingSenderId: '298945862169',
    projectId: 'intellispendiq',
    storageBucket: 'intellispendiq.firebasestorage.app',
  );
}
