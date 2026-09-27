/// Build-time configuration, passed with
/// `flutter run --dart-define-from-file=config/secrets.json`.
///
/// See `config/secrets.example.json` for the expected keys.
class AppConfig {
  const AppConfig._();

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  /// App Check debug token registered in Firebase Console (App Check → Apps →
  /// Manage debug tokens). Used because the robot's APK is side-loaded, not
  /// installed from Google Play. Leave empty to use Play Integrity instead.
  static const appCheckDebugToken = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN',
  );

  /// Gemini Live model with native audio output. Can be overridden without
  /// code changes when Google releases a newer model.
  static const geminiLiveModel = String.fromEnvironment(
    'GEMINI_LIVE_MODEL',
    defaultValue: 'gemini-2.5-flash-native-audio-preview-09-2025',
  );

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
