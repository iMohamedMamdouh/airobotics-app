import 'package:airobotics_app/main.dart';
import 'package:airobotics_app/screens/home_screen.dart';
import 'package:airobotics_app/services/horus_controller.dart';
import 'package:airobotics_app/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows setup instructions when Firebase keys are missing', (
    tester,
  ) async {
    await tester.pumpWidget(const HorusApp(controller: null));
    expect(find.textContaining('بيانات Firebase ناقصة'), findsOneWidget);
  });

  testWidgets('welcome screen introduces Horus', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = HorusController(settingsStore: SettingsStore());
    addTearDown(controller.dispose);
    await tester.pumpWidget(HorusApp(controller: controller));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('أهلاً! أنا حورس 👋'), findsOneWidget);
    expect(find.text('جاهز'), findsOneWidget);
  });
}
