import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const green = Color(0xFF1B6A26);
  static const greenDark = Color(0xFF22C55E);
  static const greenHover = Color(0xFF15561D);
  static const greenHoverDark = Color(0xFF4ADE80);
  static const accentSoftLight = Color(0xFFE8F5EC);
  static const accentSoftDark = Color(0x2422C55E);
  static const orange = Color(0xFFFC7100);
  static const orangeDark = Color(0xFFD95F00);
  static const orangeDarkTheme = Color(0xFFFF8A2A);
  static const orangeSoftLight = Color(0x24FC7100);
  static const orangeSoftDark = Color(0x29FC7100);
  static const gold = Color(0xFFC9A227);
  static const goldDark = Color(0xFFE2BE4F);
  static const goldSoftLight = Color(0x1AC9A227);
  static const goldSoftDark = Color(0x24E2BE4F);
  static const danger = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFF87171);
  static const dangerSoftLight = Color(0xFFFDECEC);
  static const dangerSoftDark = Color(0x1EF87171);

  static const lightBg = Color(0xFFF6F7F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1C231E);
  static const lightMuted = Color(0xFF6C7570);
  static const lightBorder = Color(0xFFE3E6E3);
  static const lightSurface2 = Color(0xFFF0F2F0);

  static const darkBg = Color(0xFF121413);
  static const darkSurface = Color(0xFF1A1D1B);
  static const darkText = Color(0xFFE8EAE8);
  static const darkMuted = Color(0xFF9AA39D);
  static const darkBorder = Color(0xFF2C312E);
  static const darkSurface2 = Color(0xFF222624);

  static const _transparentBlack = Color(0x00000000);
  static const _transparentWhite = Color(0x00FFFFFF);

  static Color onImage(bool isDark) => isDark ? Colors.white : lightText;
  static Color onImageMuted(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.85) : lightMuted;
  static List<Color> topFade(bool isDark) =>
      isDark ? const [Colors.black, _transparentBlack] : const [Colors.white, _transparentWhite];
  static List<Color> bottomFade(bool isDark) =>
      isDark ? const [_transparentBlack, Colors.black] : const [_transparentWhite, Colors.white];

  static Color accentSoft(bool isDark) =>
      isDark ? accentSoftDark : accentSoftLight;
  static Color orangeSoft(bool isDark) =>
      isDark ? orangeSoftDark : orangeSoftLight;
  static Color dangerSoft(bool isDark) =>
      isDark ? dangerSoftDark : dangerSoftLight;
}

class AppTheme {
  static ThemeData light() {
    final base = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.green,
        onPrimary: Colors.white,
        secondary: AppColors.orange,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.danger,
      ),
      textTheme: base.copyWith(
        bodyMedium: base.bodyMedium?.copyWith(color: AppColors.lightText),
        bodySmall: base.bodySmall?.copyWith(color: AppColors.lightMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.lightText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightText),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.green,
        unselectedItemColor: Color(0x73000000),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData dark() {
    final base = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.greenDark,
        onPrimary: Colors.white,
        secondary: AppColors.orange,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        error: AppColors.danger,
      ),
      textTheme: base.copyWith(
        bodyMedium: base.bodyMedium?.copyWith(color: AppColors.darkText),
        bodySmall: base.bodySmall?.copyWith(color: AppColors.darkMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.darkText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.greenHoverDark,
        unselectedItemColor: Color(0x8CFFFFFF),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
