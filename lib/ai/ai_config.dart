class AiConfig {
  const AiConfig._();

  // For development, prefer:
  // flutter run --dart-define-from-file=env/gemini.local.env
  //
  // For production, move the model call behind your own backend so the mobile
  // app does not expose the secret key inside the APK.
  static const apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'PASTE_GEMINI_API_KEY_HERE',
  );
  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );
  static const host = 'generativelanguage.googleapis.com';
  static const timeout = Duration(seconds: 24);

  static Uri get endpoint =>
      Uri.https(host, '/v1beta/models/$model:generateContent');

  static bool get hasApiKey {
    final key = apiKey.trim();
    return key.isNotEmpty && !key.startsWith('PASTE_');
  }
}
