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
  // Клиентский таймаут держим выше серверного (~30 с): если функция падает на
  // 30-й секунде, у её ошибки должен быть шанс дойти до клиента, а не быть
  // перебитой более ранним клиентским TimeoutException.
  static const timeout = Duration(seconds: 40);

  static bool get hasBackend => FirebaseBackend.isInitialized;
}
