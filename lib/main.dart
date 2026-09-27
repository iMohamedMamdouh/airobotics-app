import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'services/horus_controller.dart';
import 'services/settings_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kiosk-style: full screen and the tablet never sleeps.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  HorusController? controller;
  if (AppConfig.isFirebaseConfigured) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseAppId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
      ),
    );
    // Firebase AI Logic rejects requests without a valid App Check token.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AppConfig.appCheckDebugToken.isNotEmpty
          ? const AndroidDebugProvider(debugToken: AppConfig.appCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
    );
    controller = HorusController(settingsStore: SettingsStore());
    await controller.init();
  }

  runApp(HorusApp(controller: controller));
}

class HorusApp extends StatelessWidget {
  const HorusApp({super.key, required this.controller});

  /// Null when Firebase keys were not provided at build time.
  final HorusController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return MaterialApp(
      title: 'Horus - AI Robotics',
      debugShowCheckedModeBanner: false,
      theme: buildHorusTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: c != null
          ? HomeScreen(controller: c)
          : const _MissingConfigScreen(),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'بيانات Firebase ناقصة.\n'
            'شغّل التطبيق بالأمر:\n'
            'flutter run --dart-define-from-file=config/secrets.json',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
