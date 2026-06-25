import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBackend {
  const FirebaseBackend._();

  static const _useDebugAppCheck = bool.fromEnvironment(
    'FIREBASE_APP_CHECK_DEBUG',
    defaultValue: !kReleaseMode,
  );

  static bool _initialized = false;
  static Object? _lastError;

  static bool get isInitialized => _initialized;
  static Object? get lastError => _lastError;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await FirebaseAppCheck.instance.activate(
        providerAndroid: _useDebugAppCheck
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: _useDebugAppCheck
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );

      _initialized = true;
      _lastError = null;
    } on Object catch (error) {
      _initialized = false;
      _lastError = error;
      debugPrint('Firebase backend is disabled: $error');
    }
  }
}
