import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// {@template firebase_config}
/// Configuration for Firebase services.
/// Initializes Firebase based on the environment.
/// {@endtemplate}
class FirebaseConfig {
  /// {@macro firebase_config}
  const FirebaseConfig._();

  static FirebaseApp? _app;
  static FirebaseFirestore? _firestore;
  static FirebaseMessaging? _messaging;

  /// Initialize Firebase for the given environment.
  static Future<void> initialize({
    required String environment,
    bool enableFirestore = true,
    bool enableMessaging = true,
  }) async {
    if (_app != null) return; // Already initialized

    // Select options based on environment
    final options = _getOptionsForEnvironment(environment);

    _app = await Firebase.initializeApp(options: options);

    if (enableFirestore) {
      _firestore = FirebaseFirestore.instance;
    }

    if (enableMessaging) {
      _messaging = FirebaseMessaging.instance;
    }
  }

  /// Get Firebase options for the environment.
  static FirebaseOptions _getOptionsForEnvironment(String environment) {
    // For now, use default. In a real template, you'd have different options per env.
    // You can extend this to load from different files or configs.
    return DefaultFirebaseOptions.currentPlatform;
  }

  /// Get the Firestore instance, if enabled.
  static FirebaseFirestore? get firestore => _firestore;

  /// Get the Firebase Messaging instance, if enabled.
  static FirebaseMessaging? get messaging => _messaging;

  /// Dispose Firebase services.
  static Future<void> dispose() async {
    // Add any cleanup if needed
  }
}
