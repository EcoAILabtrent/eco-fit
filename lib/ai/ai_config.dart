import '../firebase/firebase_backend.dart';

class AiConfig {
  const AiConfig._();

  static const functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );
  static const adviceFunctionName = String.fromEnvironment(
    'AI_ADVICE_FUNCTION_NAME',
    defaultValue: 'aiAdvice',
  );
  static const connectivityHost = 'firebase.googleapis.com';
  static const timeout = Duration(seconds: 30);

  static bool get hasBackend => FirebaseBackend.isInitialized;
}
