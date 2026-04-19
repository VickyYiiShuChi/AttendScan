// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

// Provide platform-specific Firebase configuration options
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web: use the provided configuration
      return web;
    } else {
      // Android & iOS: let Firebase read google-services.json automatically
      // Note: ideally this should return a default value rather than throwing
      throw UnsupportedError(
        'For mobile platforms, use the default configuration from google-services.json\n'
        'Call Firebase.initializeApp() without options parameter.'
      );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCATepyc4GV-N0sm-mx1pXHXoE04xIhIHs',
    authDomain: 'final-exam-attendance-app.firebaseapp.com',
    projectId: 'final-exam-attendance-app',
    storageBucket: 'final-exam-attendance-app.firebasestorage.app',
    messagingSenderId: '4187189867',
    appId: '1:4187189867:web:d12aac08c7815b32c8372e',
  );
}