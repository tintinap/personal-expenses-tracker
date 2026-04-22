import 'package:flutter/material.dart';

import '../core/currency_helper.dart';
import '../core/theme/app_theme.dart';

enum ThemeModeOption { system, light, dark }

class SettingsProvider extends ChangeNotifier {
  ThemeModeOption _themeMode = ThemeModeOption.system;
  CurrencyCode _currency = CurrencyCode.aud;

  ThemeModeOption get themeMode => _themeMode;
  CurrencyCode get currency => _currency;

  ThemeData get themeData {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return AppTheme.light;
      case ThemeModeOption.dark:
        return AppTheme.dark;
      case ThemeModeOption.system:
        return AppTheme.light; // Will be overridden by builder
    }
  }

  Brightness get brightness {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return Brightness.light;
      case ThemeModeOption.dark:
        return Brightness.dark;
      case ThemeModeOption.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  void setThemeMode(ThemeModeOption mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setCurrency(CurrencyCode code) {
    _currency = code;
    notifyListeners();
  }
}
