import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../constants/app_constants.dart';

class ThemeManager {
  static const _themeModeKey = 'theme_mode';
  static late final ValueNotifier<ThemeMode> mode;
  static late final Box _settingsBox;

  static Future<void> init() async {
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    final storedMode =
        _settingsBox.get(_themeModeKey, defaultValue: 'dark') as String;
    mode = ValueNotifier(_themeModeFromString(storedMode));
  }

  static ThemeMode _themeModeFromString(String value) {
    return value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  static String _themeModeToString(ThemeMode mode) {
    return mode == ThemeMode.light ? 'light' : 'dark';
  }

  static void setThemeMode(ThemeMode newMode) {
    _settingsBox.put(_themeModeKey, _themeModeToString(newMode));
    mode.value = newMode;
  }

  static bool get isDarkMode => mode.value == ThemeMode.dark;
}
