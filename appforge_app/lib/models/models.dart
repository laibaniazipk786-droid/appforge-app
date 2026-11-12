// Plain data models parsed from the AppForge REST API.

double toDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

bool toBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String toStr(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

Map<String, dynamic> toMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> toList(dynamic v) => v is List ? v : const [];

/* ---------------- Builder ---------------- */

class ActionData {
  final String type;
  final String value;

  const ActionData({this.type = 'none', this.value = ''});

  factory ActionData.fromJson(dynamic json) {
    final m = toMap(json);
    return ActionData(type: toStr(m['type'], 'none'), value: toStr(m['value']));
  }

  bool get isNone => type == 'none' || type.isEmpty;
}

class BlockData {
  final String id;
  final String type;
  final Map<String, dynamic> props;

  BlockData({required this.id, required this.type, required this.props});

  factory BlockData.fromJson(Map<String, dynamic> json) => BlockData(
        id: toStr(json['id']),
        type: toStr(json['type']),
        props: toMap(json['props']),
      );

  String str(String key, [String fallback = '']) {
    final v = props[key];
    return v == null || v.toString().isEmpty ? fallback : v.toString();
  }

  int integer(String key, [int fallback = 0]) => props.containsKey(key) && props[key] != '' ? toInt(props[key], fallback) : fallback;
  double number(String key, [double fallback = 0]) => props.containsKey(key) && props[key] != '' ? toDouble(props[key], fallback) : fallback;
  bool flag(String key, [bool fallback = false]) => toBool(props[key], fallback);
  ActionData action(String key) => ActionData.fromJson(props[key]);
}

class ScreenLayout {
  final String slug;
  final String title;
  final List<BlockData> blocks;

  ScreenLayout({required this.slug, required this.title, required this.blocks});

  factory ScreenLayout.fromJson(String slug, Map<String, dynamic> json) => ScreenLayout(
        slug: slug,
        title: toStr(json['title'], slug),
        blocks: toList(json['blocks']).whereType<Map>().map((b) => BlockData.fromJson(Map<String, dynamic>.from(b))).toList(),
      );
}

class NavItem {
  final String label;
  final String icon;
  final ActionData action;

  NavItem({required this.label, required this.icon, required this.action});

  factory NavItem.fromJson(Map<String, dynamic> json) => NavItem(
        label: toStr(json['label']),
        icon: toStr(json['icon'], 'home'),
        action: ActionData.fromJson(json['action']),
      );
}

class Currency {
  final String code;
  final String symbol;
  final String position;
  final int decimals;
  final String decimalSeparator;
  final String thousandSeparator;

  const Currency({
    this.code = 'USD',
    this.symbol = '\$',
    this.position = 'left',
    this.decimals = 2,
    this.decimalSeparator = '.',
    this.thousandSeparator = ',',
  });

  factory Currency.fromJson(dynamic json) {
    final m = toMap(json);
    if (m.isEmpty) return const Currency();
    return Currency(
      code: toStr(m['code'], 'USD'),
      symbol: toStr(m['symbol'], '\$'),
      position: toStr(m['position'], 'left'),
      decimals: toInt(m['decimals'], 2),
      decimalSeparator: toStr(m['decimal_separator'], '.'),
      thousandSeparator: toStr(m['thousand_separator'], ','),
    );
  }
}

class AppBarConfig {
  final Map<String, dynamic> raw;
  AppBarConfig(this.raw);

  /// logo_or_name | logo | name | logo_name | custom
  String get titleType => toStr(raw['title_type'], 'logo_or_name');
  String get titleText => toStr(raw['title_text']);
  bool get center => toBool(raw['center']);
  String get bgColor => toStr(raw['bg_color'], '#FFFFFF');
  String get fgColor => toStr(raw['fg_color'], '#0F172A');
  bool get shadow => toBool(raw['shadow']);
  bool get showSearch => toBool(raw['show_search'], true);
  bool get showCart => toBool(raw['show_cart'], true);
  bool get showAccount => toBool(raw['show_account']);
  bool get searchBar => toBool(raw['search_bar']);
  String get searchText => toStr(raw['search_text'], 'Search products...');
}

class OnboardingSlide {
  final String image;
  final String title;
  final String text;
  OnboardingSlide(this.image, this.title, this.text);
}

class OnboardingConfig {
  final Map<String, dynamic> raw;
  OnboardingConfig(this.raw);

  bool get enabled => toBool(raw['enabled']);
  int get version => toInt(raw['version'], 1);
  bool get fullscreen => toStr(raw['style']) == 'fullscreen';
  String get bgColor => toStr(raw['bg_color'], '#FFFFFF');
  String get textColor => toStr(raw['text_color']);
  String get skipLabel => toStr(raw['skip_label'], 'Skip');
  String get nextLabel => toStr(raw['next_label'], 'Next');
  String get doneLabel => toStr(raw['done_label'], 'Get started');

  List<OnboardingSlide> get slides => toList(raw['slides'])
      .whereType<Map>()
      .map((s) => OnboardingSlide(toStr(s['image']), toStr(s['title']), toStr(s['text'])))
      .where((s) => s.image.isNotEmpty || s.title.isNotEmpty)
      .toList();
}

class MenuItem {
  final String label;
  final String icon;
  final ActionData action;
  MenuItem(this.label, this.icon, this.action);
}

class DrawerConfig {
  final Map<String, dynamic> raw;
  DrawerConfig(this.raw);

  bool get enabled => toBool(raw['enabled'], true);
  String get headerStyle => toStr(raw['header_style'], 'primary');
  String get headerImage => toStr(raw['header_image']);
  bool get showLogin => toBool(raw['show_login'], true);
  bool get showCategories => toBool(raw['show_categories'], true);
  String get categoriesTitle => toStr(raw['categories_title'], 'Categories');
  int get categoriesLimit => toInt(raw['categories_limit'], 12);
  bool get showLanguage => toBool(raw['show_language'], true);
  bool get showThemeToggle => toBool(raw['show_theme_toggle'], true);
  List<MenuItem> get items => toList(raw['items'])
      .whereType<Map>()
      .map((e) => MenuItem(toStr(e['label']), toStr(e['icon'], 'info'), ActionData.fromJson(e['action'])))
      .toList();
}

class ProductPageConfig {
  final Map<String, dynamic> raw;
  ProductPageConfig(this.raw);

  /// auto | chips | dropdown
  String get variationStyle => toStr(raw['variation_style'], 'auto');
  bool get showSku => toBool(raw['show_sku'], true);
  bool get showStock => toBool(raw['show_stock'], true);
  bool get showReviews => toBool(raw['show_reviews'], true);
  bool get showRelated => toBool(raw['show_related'], true);
  bool get showShare => toBool(raw['show_share'], true);
  bool get stickyBuyBar => toBool(raw['sticky_buy_bar'], true);
}

class ContactInfo {
  final Map<String, dynamic> raw;
  ContactInfo(this.raw);

  String get phone => toStr(raw['phone']);
  String get whatsapp => toStr(raw['whatsapp']);
  String get email => toStr(raw['email']);
  String get address => toStr(raw['address']);
  String get hours => toStr(raw['hours']);
  String get mapUrl => toStr(raw['map_url']);
  String get facebook => toStr(raw['facebook']);
  String get instagram => toStr(raw['instagram']);
  bool get formEnabled => toBool(raw['form_enabled'], true);
}

class AppLanguage {
  final String code;
  final String name;
  final String native;
  final bool rtl;
  AppLanguage(this.code, this.name, this.native, this.rtl);
}

class LanguagesConfig {
  final String defaultCode;
  final List<AppLanguage> list;
  final Map<String, Map<String, String>> strings;

  LanguagesConfig(this.defaultCode, this.list, this.strings);

  factory LanguagesConfig.fromJson(dynamic json) {
    final m = toMap(json);
    final list = toList(m['list'])
        .whereType<Map>()
        .map((e) => AppLanguage(toStr(e['code']), toStr(e['name']), toStr(e['native']), toBool(e['rtl'])))
        .where((l) => l.code.isNotEmpty)
        .toList();
    final strings = <String, Map<String, String>>{};
    toMap(m['strings']).forEach((code, v) {
      strings[code] = toMap(v).map((k, val) => MapEntry(k, toStr(val)));
    });
    return LanguagesConfig(
      toStr(m['default'], list.isNotEmpty ? list.first.code : 'en'),
      list.isEmpty ? [AppLanguage('en', 'English', 'English', false)] : list,
      strings,
    );
  }
}

class AppSettings {
  final Map<String, dynamic> raw;
  AppSettings(this.raw);

  String get appName => toStr(raw['app_name'], 'Store');
  String get logo => toStr(raw['logo']);
  String get primaryColor => toStr(raw['primary_color'], '#4F46E5');
  String get onPrimaryColor => toStr(raw['on_primary_color'], '#FFFFFF');
  String get secondaryColor => toStr(raw['secondary_color'], '#F59E0B');
  String get backgroundColor => toStr(raw['background_color'], '#F8FAFC');
  String get surfaceColor => toStr(raw['surface_color'], '#FFFFFF');
  String get textColor => toStr(raw['text_color'], '#0F172A');
  String get mutedColor => toStr(raw['muted_color'], '#64748B');
  String get borderColor => toStr(raw['border_color'], '#E2E8F0');
  String get priceColor => toStr(raw['price_color']);
  String get saleColor => toStr(raw['sale_color']);
  String get navBgColor => toStr(raw['nav_bg_color']);
  String get navActiveColor => toStr(raw['nav_active_color']);
  String get navInactiveColor => toStr(raw['nav_inactive_color'], '#94A3B8');
  AppBarConfig get appBar => AppBarConfig(toMap(raw['appbar']));
  OnboardingConfig get onboarding => OnboardingConfig(toMap(raw['onboarding']));
  DrawerConfig get drawer => DrawerConfig(toMap(raw['drawer']));
  ProductPageConfig get productPage => ProductPageConfig(toMap(raw['product_page']));
  ContactInfo get contact => ContactInfo(toMap(raw['contact']));

  /// light | dark | system
  String get themeMode => toStr(raw['theme_mode'], 'light');
  bool get allowThemeSwitch => toBool(raw['allow_theme_switch'], true);
  Map<String, dynamic> get dark => toMap(raw['dark']);

  /// all | selected | none
  String get navLabels => toStr(raw['nav_labels'], 'all');
  String get fontFamily => toStr(raw['font_family'], 'Roboto');
  double get cardRadius => toDouble(raw['card_radius'], 12);
  String get productCard => toStr(raw['product_card'], 'standard');
  bool get guestCheckout => toBool(raw['guest_checkout'], true);
  bool get enableRegister => toBool(raw['enable_register'], true);

  List<NavItem> get bottomNav =>
      toList(raw['bottom_nav']).whereType<Map>().map((e) => NavItem.fromJson(Map<String, dynamic>.from(e))).toList();
}

class AppConfigData {
  final AppSettings settings;
  final Map<String, ScreenLayout> screens;
  final Currency currency;
  final bool woocommerce;
  final String siteUrl;
  final int updatedAt;
  final LanguagesConfig languages;

  AppConfigData({
    required this.settings,
    required this.screens,
    required this.currency,
    required this.woocommerce,
    required this.siteUrl,
    required this.updatedAt,
    required this.languages,
  });

  factory AppConfigData.fromJson(Map<String, dynamic> json) {
    final screens = <String, ScreenLayout>{};
    toMap(json['screens']).forEach((slug, value) {
      screens[slug] = ScreenLayout.fromJson(slug, toMap(value));
    });
    return AppConfigData(
      settings: AppSettings(toMap(json['settings'])),
      screens: screens,
      currency: Currency.fromJson(json['currency']),
      woocommerce: toBool(json['woocommerce']),
      siteUrl: toStr(toMap(json['site'])['url']),
      updatedAt: toInt(json['updated_at']),
      languages: LanguagesConfig.fromJson(json['languages']),
    );
  }
}

/* ---------------- Catalog ---------------- */

class AttributeOption {
  final String value;
  final String label;
  final String color;
  final String image;
  AttributeOption(this.value, this.label, {this.color = '', this.image = ''});

  bool get hasSwatch => color.isNotEmpty || image.isNotEmpty;
}

class ProductAttribute {
  final String key;
  final String name;
  final bool variation;
  final List<AttributeOption> options;

  ProductAttribute({required this.key, required this.name, required this.variation, required this.options});

  factory ProductAttribute.fromJson(Map<String, dynamic> j) => ProductAttribute(
        key: toStr(j['key']),
        name: toStr(j['name']),
        variation: toBool(j['variation']),
        options: toList(j['options'])
            .whereType<Map>()
            .map((o) => AttributeOption(toStr(o['value']), toStr(o['label']), color: toStr(o['color']), image: toStr(o['image'])))
            .toList(),
      );
}

class ProductVariation {
  final int id;
  final Map<String, String> attributes;
  final double price;
  final double regularPrice;
  final bool onSale;
  final bool inStock;
  final String image;
  final String sku;
  final int? stockQuantity;
  final String description;

  ProductVariation({
    required this.id,
    required this.attributes,
    required this.price,
    required this.regularPrice,
    required this.onSale,
    required this.inStock,
    required this.image,
    this.sku = '',
    this.stockQuantity,
    this.description = '',
  });

  factory ProductVariation.fromJson(Map<String, dynamic> j) => ProductVariation(
        id: toInt(j['id']),
        attributes: toMap(j['attributes']).map((k, v) => MapEntry(k, toStr(v))),
        price: toDouble(j['price']),
        regularPrice: toDouble(j['regular_price']),
        onSale: toBool(j['on_sale']),
        inStock: toBool(j['in_stock'], true),
        image: toStr(j['image']),
        sku: toStr(j['sku']),
        stockQuantity: j['stock_quantity'] == null ? null : toInt(j['stock_quantity']),
        description: toStr(j['description']),
      );

  /// Empty attribute value means "any".
  bool matches(Map<String, String> selected) {
    for (final e in attributes.entries) {
      final chosen = selected[e.key];
      if (chosen == null) return false;
      if (e.value.isNotEmpty && e.value != chosen) return false;
    }
    return true;
  }
}

class Product {
  final int id;
  final String name;
  final String type;
  final double price;
  final double maxPrice;
  final double regularPrice;
  final bool onSale;
  final String image;
  final double rating;
  final int ratingCount;
  final bool inStock;
  final bool purchasable;
  final String permalink;

  // Detail fields.
  final List<String> images;
  final String description;
  final String shortDescription;
  final String sku;
  final int? stockQuantity;
  final List<ProductAttribute> attributes;
  final List<ProductVariation> variations;
  final List<int> relatedIds;
  final List<Category> categories;
  final bool reviewsAllowed;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.maxPrice,
    required this.regularPrice,
    required this.onSale,
    required this.image,
    required this.rating,
    required this.ratingCount,
    required this.inStock,
    required this.purchasable,
    required this.permalink,
    this.images = const [],
    this.description = '',
    this.shortDescription = '',
    this.sku = '',
    this.stockQuantity,
    this.attributes = const [],
    this.variations = const [],
    this.relatedIds = const [],
    this.categories = const [],
    this.reviewsAllowed = false,
  });

  bool get isVariable => type == 'variable';

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: toInt(j['id']),
        name: toStr(j['name']),
        type: toStr(j['type'], 'simple'),
        price: toDouble(j['price']),
        maxPrice: toDouble(j['max_price'], toDouble(j['price'])),
        regularPrice: toDouble(j['regular_price']),
        onSale: toBool(j['on_sale']),
        image: toStr(j['image']),
        rating: toDouble(j['rating']),
        ratingCount: toInt(j['rating_count']),
        inStock: toBool(j['in_stock'], true),
        purchasable: toBool(j['purchasable'], true),
        permalink: toStr(j['permalink']),
        images: toList(j['images']).map((e) => e.toString()).toList(),
        description: toStr(j['description']),
        shortDescription: toStr(j['short_description']),
        sku: toStr(j['sku']),
        stockQuantity: j['stock_quantity'] == null ? null : toInt(j['stock_quantity']),
        attributes: toList(j['attributes']).whereType<Map>().map((e) => ProductAttribute.fromJson(Map<String, dynamic>.from(e))).toList(),
        variations: toList(j['variations']).whereType<Map>().map((e) => ProductVariation.fromJson(Map<String, dynamic>.from(e))).toList(),
        relatedIds: toList(j['related_ids']).map((e) => toInt(e)).toList(),
        categories: toList(j['categories']).whereType<Map>().map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList(),
        reviewsAllowed: toBool(j['reviews_allowed']),
      );
}

class Category {
  final int id;
  final String name;
  final int parent;
  final int count;
  final String image;
  final String icon;
  final String iconColor;

  Category({required this.id, required this.name, this.parent = 0, this.count = 0, this.image = '', this.icon = '', this.iconColor = ''});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: toInt(j['id']),
        name: toStr(j['name']),
        parent: toInt(j['parent']),
        count: toInt(j['count']),
        image: toStr(j['image']),
        icon: toStr(j['icon']),
        iconColor: toStr(j['icon_color']),
      );
}

class WpPage {
  final int id;
  final String title;
  final String content;
  final String image;
  final String link;
  WpPage(this.id, this.title, this.content, this.image, this.link);

  factory WpPage.fromJson(Map<String, dynamic> j) =>
      WpPage(toInt(j['id']), toStr(j['title']), toStr(j['content']), toStr(j['image']), toStr(j['link']));
}

class TrackResult {
  final Order order;
  final int progress;
  final List<String> steps;
  final List<Map<String, String>> notes;
  final List<Map<String, String>> tracking;

  TrackResult(this.order, this.progress, this.steps, this.notes, this.tracking);

  factory TrackResult.fromJson(Map<String, dynamic> j) => TrackResult(
        Order.fromJson(j),
        toInt(j['progress'], -1),
        toList(j['steps']).whereType<Map>().map((s) => toStr(s['label'])).toList(),
        toList(j['notes']).whereType<Map>().map((n) => {'date': toStr(n['date']), 'content': toStr(n['content'])}).toList(),
        toList(j['tracking']).whereType<Map>().map((t) => {'provider': toStr(t['provider']), 'number': toStr(t['number']), 'url': toStr(t['url'])}).toList(),
      );
}

class Review {
  final String author;
  final String avatar;
  final int rating;
  final String content;
  final String date;
  final bool verified;

  Review({required this.author, required this.avatar, required this.rating, required this.content, required this.date, required this.verified});

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        author: toStr(j['author']),
        avatar: toStr(j['avatar']),
        rating: toInt(j['rating']),
        content: toStr(j['content']),
        date: toStr(j['date']),
        verified: toBool(j['verified']),
      );
}

class Post {
  final int id;
  final String title;
  final String excerpt;
  final String image;
  final String date;
  final String author;
  final String content;
  final String link;

  Post({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.image,
    required this.date,
    required this.author,
    required this.content,
    required this.link,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: toInt(j['id']),
        title: toStr(j['title']),
        excerpt: toStr(j['excerpt']),
        image: toStr(j['image']),
        date: toStr(j['date']),
        author: toStr(j['author']),
        content: toStr(j['content']),
        link: toStr(j['link']),
      );
}

class Paged<T> {
  final List<T> items;
  final int totalPages;
  Paged(this.items, this.totalPages);
}

/* ---------------- User ---------------- */

class AppUser {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final String avatar;
  final Map<String, String> billing;
  final Map<String, String> shipping;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.avatar,
    required this.billing,
    required this.shipping,
  });

  String get name => displayName.isNotEmpty ? displayName : '$firstName $lastName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: toInt(j['id']),
        username: toStr(j['username']),
        email: toStr(j['email']),
        firstName: toStr(j['first_name']),
        lastName: toStr(j['last_name']),
        displayName: toStr(j['display_name']),
        avatar: toStr(j['avatar']),
        billing: toMap(j['billing']).map((k, v) => MapEntry(k, toStr(v))),
        shipping: toMap(j['shipping']).map((k, v) => MapEntry(k, toStr(v))),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'display_name': displayName,
        'avatar': avatar,
        'billing': billing,
        'shipping': shipping,
      };
}

/* ---------------- Cart & orders ---------------- */

class CartLine {
  final int productId;
  final int variationId;
  int quantity;
  final Map<String, String> variation;
  final String name;
  final String image;
  final double price;

  CartLine({
    required this.productId,
    this.variationId = 0,
    required this.quantity,
    this.variation = const {},
    required this.name,
    required this.image,
    required this.price,
  });

  String get key => '$productId:$variationId:${variation.entries.map((e) => '${e.key}=${e.value}').join('&')}';

  Map<String, dynamic> toRequest() => {
        'product_id': productId,
        'variation_id': variationId,
        'quantity': quantity,
        'variation': variation,
      };

  Map<String, dynamic> toJson() => {
        ...toRequest(),
        'name': name,
        'image': image,
        'price': price,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId: toInt(j['product_id']),
        variationId: toInt(j['variation_id']),
        quantity: toInt(j['quantity'], 1),
        variation: toMap(j['variation']).map((k, v) => MapEntry(k, toStr(v))),
        name: toStr(j['name']),
        image: toStr(j['image']),
        price: toDouble(j['price']),
      );
}

class ShippingRate {
  final String id;
  final String label;
  final double cost;
  final bool selected;

  ShippingRate({required this.id, required this.label, required this.cost, required this.selected});

  factory ShippingRate.fromJson(Map<String, dynamic> j) => ShippingRate(
        id: toStr(j['id']),
        label: toStr(j['label']),
        cost: toDouble(j['cost']),
        selected: toBool(j['selected']),
      );
}

class PaymentMethod {
  final String id;
  final String title;
  final String description;
  final bool native;

  PaymentMethod({required this.id, required this.title, required this.description, required this.native});

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
        id: toStr(j['id']),
        title: toStr(j['title']),
        description: toStr(j['description']),
        native: toBool(j['native']),
      );
}

class CartTotals {
  final double subtotal;
  final double discount;
  final double shipping;
  final double tax;
  final double total;

  CartTotals({this.subtotal = 0, this.discount = 0, this.shipping = 0, this.tax = 0, this.total = 0});

  factory CartTotals.fromJson(dynamic json) {
    final j = toMap(json);
    return CartTotals(
      subtotal: toDouble(j['subtotal']),
      discount: toDouble(j['discount']),
      shipping: toDouble(j['shipping']),
      tax: toDouble(j['tax']),
      total: toDouble(j['total']),
    );
  }
}

class CartSummary {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> errors;
  final List<Map<String, dynamic>> couponErrors;
  final List<String> coupons;
  final bool needsShipping;
  final List<ShippingRate> shippingRates;
  final List<PaymentMethod> paymentMethods;
  final CartTotals totals;

  CartSummary({
    required this.items,
    required this.errors,
    required this.couponErrors,
    required this.coupons,
    required this.needsShipping,
    required this.shippingRates,
    required this.paymentMethods,
    required this.totals,
  });

  factory CartSummary.fromJson(Map<String, dynamic> j) => CartSummary(
        items: toList(j['items']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        errors: toList(j['errors']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        couponErrors: toList(j['coupon_errors']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        coupons: toList(j['coupons']).map((e) => e.toString()).toList(),
        needsShipping: toBool(j['needs_shipping']),
        shippingRates: toList(j['shipping_rates']).whereType<Map>().map((e) => ShippingRate.fromJson(Map<String, dynamic>.from(e))).toList(),
        paymentMethods: toList(j['payment_methods']).whereType<Map>().map((e) => PaymentMethod.fromJson(Map<String, dynamic>.from(e))).toList(),
        totals: CartTotals.fromJson(j['totals']),
      );

  ShippingRate? get selectedRate {
    for (final r in shippingRates) {
      if (r.selected) return r;
    }
    return shippingRates.isNotEmpty ? shippingRates.first : null;
  }
}

class OrderLine {
  final int productId;
  final String name;
  final int quantity;
  final double total;
  final String image;
  final List<String> meta;

  OrderLine({required this.productId, required this.name, required this.quantity, required this.total, required this.image, required this.meta});

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        productId: toInt(j['product_id']),
        name: toStr(j['name']),
        quantity: toInt(j['quantity']),
        total: toDouble(j['total']),
        image: toStr(j['image']),
        meta: toList(j['meta']).whereType<Map>().map((m) => '${m['key']}: ${m['value']}').toList(),
      );
}

class Order {
  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String date;
  final double total;
  final double subtotal;
  final double shippingTotal;
  final double discountTotal;
  final double taxTotal;
  final String paymentMethod;
  final String shippingMethod;
  final Map<String, String> billing;
  final Map<String, String> shipping;
  final String customerNote;
  final List<OrderLine> items;
  final bool needsPayment;
  final bool canCancel;
  final String paymentUrl;

  Order({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.date,
    required this.total,
    required this.subtotal,
    required this.shippingTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.paymentMethod,
    required this.shippingMethod,
    required this.billing,
    required this.shipping,
    required this.customerNote,
    required this.items,
    required this.needsPayment,
    required this.canCancel,
    required this.paymentUrl,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: toInt(j['id']),
        number: toStr(j['number']),
        status: toStr(j['status']),
        statusLabel: toStr(j['status_label']),
        date: toStr(j['date']),
        total: toDouble(j['total']),
        subtotal: toDouble(j['subtotal']),
        shippingTotal: toDouble(j['shipping_total']),
        discountTotal: toDouble(j['discount_total']),
        taxTotal: toDouble(j['tax_total']),
        paymentMethod: toStr(j['payment_method']),
        shippingMethod: toStr(j['shipping_method']),
        billing: toMap(j['billing']).map((k, v) => MapEntry(k, toStr(v))),
        shipping: toMap(j['shipping']).map((k, v) => MapEntry(k, toStr(v))),
        customerNote: toStr(j['customer_note']),
        items: toList(j['items']).whereType<Map>().map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e))).toList(),
        needsPayment: toBool(j['needs_payment']),
        canCancel: toBool(j['can_cancel']),
        paymentUrl: toStr(j['payment_url']),
      );
}

class CountryState {
  final String code;
  final String name;
  CountryState(this.code, this.name);
}

class Country {
  final String code;
  final String name;
  final List<CountryState> states;
  Country(this.code, this.name, this.states);

  factory Country.fromJson(Map<String, dynamic> j) => Country(
        toStr(j['code']),
        toStr(j['name']),
        toList(j['states']).whereType<Map>().map((s) => CountryState(toStr(s['code']), toStr(s['name']))).toList(),
      );
}
