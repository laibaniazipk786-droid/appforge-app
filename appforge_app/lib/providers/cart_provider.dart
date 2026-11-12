import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/repository.dart';

/// Local cart. Totals, shipping, tax and coupons are calculated by WooCommerce
/// via POST /cart/calculate so they always match the website.
class CartProvider extends ChangeNotifier {
  static const _key = 'appforge_cart';
  static const _couponKey = 'appforge_coupons';

  final List<CartLine> lines = [];
  final List<String> coupons = [];

  int get count => lines.fold(0, (sum, l) => sum + l.quantity);
  double get estimatedSubtotal => lines.fold(0.0, (sum, l) => sum + l.price * l.quantity);
  bool get isEmpty => lines.isEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        lines
          ..clear()
          ..addAll((jsonDecode(raw) as List).whereType<Map>().map((e) => CartLine.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
    coupons
      ..clear()
      ..addAll(prefs.getStringList(_couponKey) ?? const []);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lines.map((l) => l.toJson()).toList()));
    await prefs.setStringList(_couponKey, coupons);
  }

  void add(CartLine line) {
    final existing = lines.where((l) => l.key == line.key);
    if (existing.isNotEmpty) {
      existing.first.quantity += line.quantity;
    } else {
      lines.add(line);
    }
    _persist();
    notifyListeners();
  }

  void setQuantity(CartLine line, int qty) {
    if (qty <= 0) {
      lines.remove(line);
    } else {
      line.quantity = qty;
    }
    _persist();
    notifyListeners();
  }

  void remove(CartLine line) {
    lines.remove(line);
    _persist();
    notifyListeners();
  }

  void addCoupon(String code) {
    final c = code.trim().toLowerCase();
    if (c.isEmpty || coupons.contains(c)) return;
    coupons.add(c);
    _persist();
    notifyListeners();
  }

  void removeCoupon(String code) {
    coupons.remove(code);
    _persist();
    notifyListeners();
  }

  void clear() {
    lines.clear();
    coupons.clear();
    _persist();
    notifyListeners();
  }

  Map<String, dynamic> requestBody({
    Map<String, String>? billing,
    Map<String, String>? shipping,
    String? shippingMethod,
    String? paymentMethod,
  }) =>
      {
        'items': lines.map((l) => l.toRequest()).toList(),
        'coupons': coupons,
        if (billing != null) 'billing': billing,
        if (shipping != null) 'shipping': shipping,
        if (shippingMethod != null) 'shipping_method': shippingMethod,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      };

  Future<CartSummary> calculate({
    Map<String, String>? billing,
    Map<String, String>? shipping,
    String? shippingMethod,
    String? paymentMethod,
  }) async {
    final summary = await Repo.calculate(requestBody(
      billing: billing,
      shipping: shipping,
      shippingMethod: shippingMethod,
      paymentMethod: paymentMethod,
    ));
    // Drop coupons WooCommerce rejected so the user isn't stuck with them.
    if (summary.couponErrors.isNotEmpty) {
      for (final e in summary.couponErrors) {
        coupons.remove(toStr(e['code']));
      }
      _persist();
      notifyListeners();
    }
    return summary;
  }
}
