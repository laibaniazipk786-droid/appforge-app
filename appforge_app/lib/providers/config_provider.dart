import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repository.dart';

/// Loads the design (theme, screens, navigation) published from the WordPress builder.
/// The last config is cached so the app opens instantly and works offline.
class ConfigProvider extends ChangeNotifier {
  static const _cacheKey = 'appforge_config_cache';

  AppConfigData? config;
  ThemeData theme = buildTheme(AppSettings(const {}));
  ThemeData darkTheme = buildTheme(AppSettings(const {}), dark: true);
  String? error;
  bool loading = true;

  AppSettings get settings => config?.settings ?? AppSettings(const {});

  ScreenLayout? screen(String slug) => config?.screens[slug];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _apply(jsonDecode(cached) as Map<String, dynamic>);
        loading = false;
        notifyListeners();
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final raw = await Repo.configRaw();
      _apply(raw);
      error = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(raw));
    } catch (e) {
      if (config == null) error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> raw) {
    config = AppConfigData.fromJson(raw);
    Money.currency = config!.currency;
    theme = buildTheme(config!.settings);
    darkTheme = buildTheme(config!.settings, dark: true);
  }
}
