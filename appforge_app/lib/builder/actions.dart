import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../screens/account_screen.dart';
import '../screens/app_settings_screen.dart';
import '../screens/auth_screens.dart';
import '../screens/builder_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/post_screens.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/search_screen.dart';
import '../screens/track_order_screen.dart';
import '../screens/webview_screen.dart';
import '../screens/wp_page_screen.dart';

/// Turns a builder "action" (set on banners, slides, buttons, nav tabs) into a page.
class AppActions {
  AppActions._();

  /// Widget for a page that can also be shown as a bottom-nav tab.
  static Widget pageFor(ActionData a, {bool asTab = false, String title = ''}) {
    switch (a.type) {
      case 'screen':
        return BuilderScreen(slug: a.value.isEmpty ? 'home' : a.value, isTab: asTab);
      case 'category':
        return ProductListScreen(title: title.isEmpty ? 'Products' : title, categoryId: toInt(a.value), isTab: asTab);
      case 'search':
        return ProductListScreen(title: '"${a.value}"', search: a.value, isTab: asTab);
      case 'product':
        return ProductDetailScreen(productId: toInt(a.value));
      case 'post':
        return PostDetailScreen(postId: toInt(a.value));
      case 'wp_page':
        return WpPageScreen(pageId: toInt(a.value), title: title);
      case 'url':
        return WebViewScreen(url: a.value, title: title, isTab: asTab);
      case 'route':
        return _route(a.value, asTab, title);
      default:
        return BuilderScreen(slug: 'home', isTab: asTab);
    }
  }

  static Widget _route(String route, bool asTab, String title) {
    switch (route) {
      case 'categories':
        return CategoriesScreen(isTab: asTab);
      case 'cart':
        return CartScreen(isTab: asTab);
      case 'account':
        return AccountScreen(isTab: asTab);
      case 'orders':
        return OrdersScreen(isTab: asTab);
      case 'posts':
        return PostsScreen(isTab: asTab);
      case 'search':
        return SearchScreen(isTab: asTab);
      case 'contact':
        return ContactScreen(isTab: asTab);
      case 'track_order':
        return TrackOrderScreen(isTab: asTab);
      case 'settings':
        return AppSettingsScreen(isTab: asTab);
      case 'login':
        return const LoginScreen();
      case 'products':
      default:
        return ProductListScreen(title: title.isEmpty ? 'All products' : title, isTab: asTab);
    }
  }

  /// Opens tel:, WhatsApp, mailto: or an external URL.
  static Future<bool> launchExternal(String type, String value) async {
    final v = value.trim();
    if (v.isEmpty) return false;
    Uri? uri;
    switch (type) {
      case 'call':
        uri = Uri(scheme: 'tel', path: v.replaceAll(RegExp(r'[^0-9+]'), ''));
        break;
      case 'whatsapp':
        uri = Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'[^0-9]'), '')}');
        break;
      case 'email':
        uri = Uri(scheme: 'mailto', path: v);
        break;
      default:
        uri = Uri.tryParse(v);
    }
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> open(BuildContext context, ActionData a, {String title = ''}) async {
    if (a.isNone) return;
    if (const ['external', 'call', 'whatsapp', 'email'].contains(a.type)) {
      await launchExternal(a.type, a.value);
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pageFor(a, title: title)));
  }
}
