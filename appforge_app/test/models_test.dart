// Parses REAL responses recorded from the WordPress + WooCommerce test site
// (see tests/api_test.py → test/fixtures) and checks the app's logic.
import 'dart:convert';
import 'dart:io';

import 'package:appforge_app/core/format.dart';
import 'package:appforge_app/core/i18n.dart';
import 'package:appforge_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Config from WordPress', () {
    final config = AppConfigData.fromJson(fixture('config'));

    test('screens, currency, languages', () {
      expect(config.woocommerce, isTrue);
      expect(config.screens['home']!.blocks, isNotEmpty);
      expect(config.currency.code, 'PKR');
      expect(config.languages.list.first.code, 'en');
      expect(config.clockOffset.abs(), lessThan(86400 * 365));
    });

    test('bottom menu + sidebar', () {
      expect(config.settings.bottomNav.length, greaterThanOrEqualTo(2));
      expect(config.settings.drawer.items, isNotEmpty);
    });

    test('WhatsApp button', () {
      final wa = config.settings.whatsApp;
      expect(wa.enabled, isTrue);
      expect(wa.number, '923001234567');
      expect(wa.left, isTrue);
      expect(wa.productText('Epson L3250', 'Rs 45,000', 'https://x.pk/p'), 'Hi! I want to order: Epson L3250 (Rs 45,000) https://x.pk/p');
      expect(wa.productText('Epson', '', 'https://x.pk/p'), 'Hi! I want to order: Epson https://x.pk/p');
    });

    test('popup (sanitized by WordPress)', () {
      final p = config.settings.popup;
      expect(p.enabled, isTrue);
      expect(p.title, 'Eid Sale');
      expect(p.image, isEmpty);
      expect(p.action.type, 'category');
      expect(p.frequency, 'daily');
      expect(p.id.length, 12);
    });

    test('app update', () {
      final u = config.settings.appUpdate;
      expect(u.status('1.4.0'), 'optional');
      expect(u.status('0.9.9'), 'required');
      expect(u.status('1.5.0'), 'none');
    });

    test('search + cart settings', () {
      expect(config.settings.search.trending, ['printer', 'camera']);
      expect(config.settings.cart.freeShippingBar, isTrue);
      expect(config.settings.cart.checkoutNote, 'Line 1\nLine 2');
    });
  });

  group('Catalog', () {
    test('variable product, swatches and variation matching', () {
      final p = Product.fromJson(fixture('product_variable'));
      expect(p.isVariable, isTrue);
      expect(p.price, 15000);
      expect(p.maxPrice, 16000);
      final color = p.attributes.firstWhere((a) => a.variation);
      expect(color.key, 'attribute_pa_color');
      expect(color.options.map((o) => o.color), containsAll(['#ff0000', '#0000ff']));
      final blue = p.variations.firstWhere((v) => v.matches({'attribute_pa_color': 'blue'}));
      expect(blue.price, 16000);
      expect(p.variations.where((v) => v.matches({'attribute_pa_color': 'green'})), isEmpty);
    });

    test('sale product', () {
      final p = Product.fromJson(fixture('product_sale'));
      expect(p.onSale, isTrue);
      expect(p.regularPrice, greaterThan(p.price));
      expect(p.sku, 'EPS-L3250');
    });

    test('product list + filters', () {
      final list = toList(fixture('products')['items']).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(list.length, greaterThanOrEqualTo(4));
      final f = FilterOptions.fromJson(fixture('filters'));
      expect(f.maxPrice, 45000);
      expect(f.attributes.first.terms.map((t) => t.slug), containsAll(['red', 'blue']));
    });

    test('filter query', () {
      final f = ProductFilter()
        ..minPrice = 1000.4
        ..maxPrice = 5000.2
        ..onSale = true
        ..rating = 4;
      f.terms['pa_color'] = {'red', 'blue'};
      f.terms['pa_size'] = {};
      expect(f.toQuery(), {'min_price': 1000, 'max_price': 5001, 'on_sale': 1, 'rating': 4, 'filter_pa_color': 'red,blue'});
      expect(f.activeCount, 4);
      final copy = f.copy()..terms['pa_color']!.add('green');
      expect(f.terms['pa_color']!.length, 2, reason: 'copy must not share sets');
      expect(copy.terms['pa_color']!.length, 3);
    });
  });

  group('Cart & orders', () {
    test('cart totals + free shipping progress', () {
      final c = CartSummary.fromJson(fixture('cart'));
      expect(c.totals.discount, 10600);
      expect(c.coupons, contains('welcome10'));
      expect(c.paymentMethods.map((m) => m.id), containsAll(['cod', 'bacs']));
      final fs = c.freeShipping!;
      expect(fs.remaining, 54600);
      expect(fs.qualified, isFalse);
      expect(fs.progress, closeTo((150000 - 54600) / 150000, 0.0001));
    });

    test('no free shipping info → null', () {
      final j = fixture('cart')..remove('free_shipping');
      expect(CartSummary.fromJson(j).freeShipping, isNull);
      expect(FreeShippingInfo(min: 100, remaining: 0, qualified: true).progress, 1);
    });

    test('Buy again turns order lines into cart lines', () {
      final o = Order.fromJson(fixture('order'));
      final camera = o.items.firstWhere((i) => i.variationId > 0);
      final line = camera.toCartLine();
      expect(line.variationId, camera.variationId);
      expect(line.variation, {'attribute_pa_color': 'blue'});
      expect(line.price, 16000, reason: 'uses the current price, not the discounted order total');
      expect(line.toRequest()['variation_id'], camera.variationId);
      final epson = o.items.firstWhere((i) => i.variationId == 0);
      expect(epson.toCartLine().quantity, 2);
    });
  });

  group('Helpers', () {
    test('version compare', () {
      expect(compareVersions('1.4.0', '1.4'), 0);
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('1.4.0+7', '1.4.1'), -1);
      expect(compareVersions('v2', '1.99'), 1);
      final none = AppUpdateConfig({});
      expect(none.status('1.0.0'), 'none');
    });

    test('popup frequency', () {
      final day = const Duration(days: 1).inMilliseconds;
      PopupConfig p(String f) => PopupConfig({'enabled': true, 'title': 'Hi', 'frequency': f, 'id': 'abc'});
      expect(p('once').shouldShow(lastId: '', lastShownMs: 0, nowMs: day), isTrue);
      expect(p('once').shouldShow(lastId: 'abc', lastShownMs: 0, nowMs: day * 30), isFalse);
      expect(p('once').shouldShow(lastId: 'old', lastShownMs: day, nowMs: day), isTrue, reason: 'edited popup shows again');
      expect(p('daily').shouldShow(lastId: 'abc', lastShownMs: day, nowMs: day + 3600000), isFalse);
      expect(p('daily').shouldShow(lastId: 'abc', lastShownMs: day, nowMs: day * 2), isTrue);
      expect(p('always').shouldShow(lastId: 'abc', lastShownMs: day, nowMs: day), isTrue);
      expect(PopupConfig({'enabled': true}).enabled, isFalse, reason: 'empty popup is not shown');
    });

    test('WhatsApp number falls back to contact number and keeps digits only', () {
      final wa = WhatsAppButtonConfig({'enabled': true}, '+92 300-1234567');
      expect(wa.number, '923001234567');
      expect(wa.enabled, isTrue);
      expect(WhatsAppButtonConfig({'enabled': true}, '').enabled, isFalse);
    });

    test('money format (PKR)', () {
      Money.currency = const Currency(code: 'PKR', symbol: 'Rs', position: 'left_space', decimals: 0);
      expect(Money.format(150000), 'Rs 150,000');
      expect(Money.format(-500), 'Rs -500');
      Money.currency = const Currency(symbol: '\$', decimals: 2);
      expect(Money.format(1234.5), '\$1,234.50');
    });

    test('translations with placeholders', () {
      I18n.load('ur', {'Add {amount} more for FREE shipping': 'مفت ڈیلیوری کے لیے مزید {amount} کی خریداری کریں'}, true);
      expect(tr('Add {amount} more for FREE shipping', {'amount': 'Rs 500'}), 'مفت ڈیلیوری کے لیے مزید Rs 500 کی خریداری کریں');
      expect(tr('Untranslated'), 'Untranslated');
      I18n.load('en', {}, false);
    });

    test('Urdu pack covers every app string', () {
      final en = jsonDecode(File('../appforge-builder/languages/en.json').readAsStringSync());
      final ur = jsonDecode(File('../appforge-builder/languages/ur.json').readAsStringSync()) as Map;
      final keys = en is Map ? en.keys : (en as List);
      final missing = keys.where((k) => (ur[k] ?? '').toString().isEmpty).toList();
      expect(missing, isEmpty);
    });
  });
}
