import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors taken from the AI Robotics logo.
class HorusColors {
  const HorusColors._();

  static const background = Color(0xFF020F1F);
  static const navy = Color(0xFF033B70);
  static const navyLight = Color(0xFF0B5AA3);
  static const sky = Color(0xFF1FA5EE);
  static const gold = Color(0xFFF2B84B);
  static const listening = Color(0xFF34D399);
  static const thinking = Color(0xFFA78BFA);
  static const error = Color(0xFFF87171);
  static const textMuted = Color(0xFF9DB3CC);
}

ThemeData buildHorusTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HorusColors.sky,
      brightness: Brightness.dark,
      surface: HorusColors.background,
    ),
    scaffoldBackgroundColor: HorusColors.background,
  );
  return base.copyWith(textTheme: GoogleFonts.cairoTextTheme(base.textTheme));
}
