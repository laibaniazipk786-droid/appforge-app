import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../services/repository.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'appforge_token';
  static const _userKey = 'appforge_user';

  AppUser? user;
  bool get loggedIn => user != null && (Api.instance.token ?? '').isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (token != null && userJson != null) {
      Api.instance.token = token;
      try {
        user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
      notifyListeners();
      // Validate token in the background.
      refreshMe();
    }
  }

  Future<void> _save(Map<String, dynamic> res) async {
    final token = toStr(res['token']);
    final u = AppUser.fromJson(toMap(res['user']));
    Api.instance.token = token;
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> login(String username, String password) async => _save(await Repo.login(username, password));

  Future<void> register({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    await _save(await Repo.register({
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    }));
  }

  Future<void> refreshMe() async {
    try {
      final u = await Repo.me();
      user = u;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(u.toJson()));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await logout();
    } catch (_) {}
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    user = await Repo.updateMe(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> changePassword(String oldPass, String newPass) async {
    await _save(await Repo.changePassword(oldPass, newPass));
  }

  Future<void> deleteAccount(String password) async {
    await Repo.deleteAccount(password);
    await logout();
  }

  Future<void> logout() async {
    Api.instance.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
