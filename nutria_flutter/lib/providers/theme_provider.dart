import 'package:flutter/material.dart';
import '../core/storage.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  final _storage = SecureStorage();
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Color accentColor(BuildContext context) =>
      isDark ? AppColors.greenDark : AppColors.green;

  Color accentHoverColor(BuildContext context) =>
      isDark ? AppColors.greenHoverDark : AppColors.greenHover;

  Color bgColor(BuildContext context) =>
      isDark ? AppColors.darkBg : AppColors.lightBg;

  Color surfaceColor(BuildContext context) =>
      isDark ? AppColors.darkSurface : AppColors.lightSurface;

  Color textColor(BuildContext context) =>
      isDark ? AppColors.darkText : AppColors.lightText;

  Color mutedColor(BuildContext context) =>
      isDark ? AppColors.darkMuted : AppColors.lightMuted;

  Color borderColor(BuildContext context) =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;

  Color surface2Color(BuildContext context) =>
      isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;

  Future<void> init() async {
    final theme = await _storage.getTheme();
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    await _storage.saveTheme(isDark ? 'dark' : 'light');
    notifyListeners();
  }
}
