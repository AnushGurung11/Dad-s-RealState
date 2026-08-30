import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and notifies themeMode changes.
/// Key: "theme_mode" bool true=dark, false=light. Defaults to light per spec.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  static const _key = 'theme_mode';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key);
    // Default to light if no preference stored
    if (isDark != null) {
      value = isDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      value = ThemeMode.light;
    }
    _loaded = true;
  }

  Future<void> setDark(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }

  Future<void> toggle() async {
    await setDark(value != ThemeMode.dark);
  }

  bool get isDark => value == ThemeMode.dark;
}

/// Global singleton for easy access from Settings.
final themeController = ThemeController();
