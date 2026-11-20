import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/repository.dart';
import 'auth_provider.dart';

/// Wishlist kept on the phone for everyone, synced with the account when logged in.
class WishlistProvider extends ChangeNotifier {
  static const _key = 'appforge_wishlist';

  final List<int> _ids = [];
  AuthProvider? _auth;
  bool _wasLoggedIn = false;

  List<int> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(int productId) => _ids.contains(productId);

  Future<void> init(AuthProvider auth) async {
    final p = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll((p.getStringList(_key) ?? const []).map(int.tryParse).whereType<int>());
    _auth = auth;
    _wasLoggedIn = auth.loggedIn;
    auth.addListener(_onAuthChanged);
    if (auth.loggedIn) _sync();
    notifyListeners();
  }

  void _onAuthChanged() {
    final now = _auth?.loggedIn ?? false;
    if (now && !_wasLoggedIn) _sync(); // just logged in: merge phone list into the account
    _wasLoggedIn = now;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, _ids.map((e) => '$e').toList());
  }

  Future<void> _sync() async {
    try {
      final merged = await Repo.wishlistSync(_ids);
      _ids
        ..clear()
        ..addAll(merged);
      await _persist();
      notifyListeners();
    } catch (_) {
      // Offline: keep the local list, it will sync next time.
    }
  }

  /// Returns true when the product is now in the wishlist.
  bool toggle(int productId) {
    final add = !_ids.contains(productId);
    if (add) {
      _ids.insert(0, productId);
    } else {
      _ids.remove(productId);
    }
    _persist();
    notifyListeners();
    if (_auth?.loggedIn ?? false) {
      Repo.wishlistUpdate(productId, add).catchError((_) => <int>[]);
    }
    return add;
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// Products the customer opened recently (stored on the phone only).
class RecentlyViewed {
  RecentlyViewed._();
  static const _key = 'appforge_recently_viewed';
  static const _max = 20;
  static final ValueNotifier<List<int>> ids = ValueNotifier(const []);

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    ids.value = (p.getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toList();
  }

  static Future<void> add(int productId) async {
    final list = [productId, ...ids.value.where((e) => e != productId)].take(_max).toList();
    ids.value = list;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, list.map((e) => '$e').toList());
  }
}
