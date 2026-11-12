import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Customer choices stored on the phone: language and light/dark mode.
class PrefsProvider extends ChangeNotifier {
  static const _langKey = 'appforge_language';
  static const _themeKey = 'appforge_theme_mode';

  String _lang = '';
  String _theme = ''; // '' = follow the store setting, or light | dark | system

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _lang = p.getString(_langKey) ?? '';
    _theme = p.getString(_themeKey) ?? '';
  }

  AppLanguage language(LanguagesConfig? cfg) {
    final list = cfg?.list ?? [AppLanguage('en', 'English', 'English', false)];
    for (final l in list) {
      if (l.code == _lang) return l;
    }
    for (final l in list) {
      if (l.code == cfg?.defaultCode) return l;
    }
    return list.first;
  }

  Future<void> setLanguage(String code) async {
    _lang = code;
    final p = await SharedPreferences.getInstance();
    await p.setString(_langKey, code);
    notifyListeners();
  }

  String themeChoice(AppSettings s) => (s.allowThemeSwitch && _theme.isNotEmpty) ? _theme : s.themeMode;

  ThemeMode themeMode(AppSettings s) {
    switch (themeChoice(s)) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  bool isDark(BuildContext context, AppSettings s) {
    final mode = themeMode(s);
    if (mode == ThemeMode.system) return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return mode == ThemeMode.dark;
  }

  Future<void> setTheme(String mode) async {
    _theme = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_themeKey, mode);
    notifyListeners();
  }
}
