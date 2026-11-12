import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'auth_screens.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  /// Card data shown instantly while full details load.
  final Product? preview;

  const ProductDetailScreen({super.key, required this.productId, this.preview});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  String? _error;
  final Map<String, String> _selected = {};
  int _qty = 1;
  int _imageIndex = 0;
  final _pageController = PageController();
  Future<List<Review>>? _reviews;
  Future<Paged<Product>>? _related;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Repo.product(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = p;
        _error = null;
        // Pre-select attributes that have only one option.
        for (final a in p.attributes.where((a) => a.variation)) {
          if (a.options.length == 1) _selected[a.key] = a.options.first.value;
        }
        _reviews = Repo.reviews(p.id);
        if (p.relatedIds.isNotEmpty) _related = Repo.products(include: p.relatedIds, perPage: p.relatedIds.length);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<ProductAttribute> get _variationAttrs => _product?.attributes.where((a) => a.variation).toList() ?? const [];

  ProductVariation? get _variation {
    final p = _product;
    if (p == null || !p.isVariable) return null;
    if (!_variationAttrs.every((a) => _selected.containsKey(a.key))) return null;
    for (final v in p.variations) {
      if (v.matches(_selected)) return v;
    }
    return null;
  }

  bool get _allSelected => _variationAttrs.every((a) => _selected.containsKey(a.key));

  /// True when [value] can still lead to an in-stock variation given the other choices.
  bool _optionAvailable(ProductAttribute attr, String value) {
    final p = _product!;
    final trial = Map<String, String>.from(_selected)..[attr.key] = value;
    return p.variations.any((v) {
      if (!v.inStock) return false;
      for (final e in v.attributes.entries) {
        final chosen = trial[e.key];
        if (chosen != null && e.value.isNotEmpty && e.value != chosen) return false;
      }
      return true;
    });
  }

  void _select(ProductAttribute a, String? value) {
    setState(() {
      if (value == null || _selected[a.key] == value) {
        _selected.remove(a.key);
      } else {
        _selected[a.key] = value;
        // Drop other choices that no longer combine with this one.
        for (final other in _variationAttrs) {
          if (other.key == a.key) continue;
          final v = _selected[other.key];
          if (v != null && !_optionAvailable(other, v)) _selected.remove(other.key);
        }
      }
      _imageIndex = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }

  void _addToCart({bool buyNow = false}) {
    final p = _product!;
    final v = _variation;
    if (p.isVariable && v == null) {
      showSnack(context, _allSelected ? tr('This combination is not available') : tr('Please select all options'), error: true);
      return;
    }
    final variationAttrs = <String, String>{};
    if (v != null) {
      for (final a in _variationAttrs) {
        variationAttrs[a.key] = _selected[a.key]!;
      }
    }
    context.read<CartProvider>().add(CartLine(
          productId: p.id,
          variationId: v?.id ?? 0,
          quantity: _qty,
          variation: variationAttrs,
          name: p.name,
          image: (v != null && v.image.isNotEmpty) ? v.image : p.image,
          price: v?.price ?? p.price,
        ));
    if (buyNow) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(tr('Added to cart')),
          action: SnackBarAction(
            label: tr('View cart'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product ?? widget.preview;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? MessageView(icon: Icons.error_outline, title: tr('Could not load product'), subtitle: _error, actionLabel: tr('Retry'), onAction: _load)
            : const LoadingView(),
      );
    }

    final cfg = context.watch<ConfigProvider>().settings.productPage;
    final colors = AppColors.of(context);
    final v = _variation;
    final images = <String>[
      if (v != null && v.image.isNotEmpty) v.image,
      ...(p.images.isNotEmpty ? p.images : [p.image]),
    ];
    final inStock = v?.inStock ?? p.inStock;
    final stockQty = v != null ? v.stockQuantity : p.stockQuantity;
    final sku = (v != null && v.sku.isNotEmpty) ? v.sku : p.sku;
    final theme = Theme.of(context);

    final buyBar = _product == null
        ? null
        : SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: theme.colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: inStock && p.purchasable ? () => _addToCart() : null,
                    child: Text(tr('Add to cart')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: inStock && p.purchasable ? () => _addToCart(buyNow: true) : null,
                    child: Text(inStock ? tr('Buy now') : tr('Sold out')),
                  ),
                ),
              ]),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (cfg.showShare && p.permalink.isNotEmpty)
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => Share.share('${p.name}\n${p.permalink}')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _imageIndex = i),
                  itemBuilder: (_, i) => NetImage(images[i], fit: BoxFit.contain),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _imageIndex ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _imageIndex ? theme.colorScheme.primary : Colors.black26,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (p.ratingCount > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                      Text(' ${p.rating.toStringAsFixed(1)} (${p.ratingCount})', style: TextStyle(color: colors.muted)),
                    ]),
                  if (cfg.showStock)
                    Text(
                      !inStock
                          ? tr('Out of stock')
                          : (stockQty != null && stockQty > 0 && stockQty <= 10 ? tr('Only {n} left', {'n': stockQty}) : tr('In stock')),
                      style: TextStyle(color: inStock ? Colors.green.shade600 : Colors.red.shade400, fontWeight: FontWeight.w600),
                    ),
                  if (cfg.showSku && sku.isNotEmpty) Text('${tr('SKU')}: $sku', style: TextStyle(color: colors.muted, fontSize: 12)),
                ]),
                const SizedBox(height: 10),
                v != null
                    ? PriceView(price: v.price, regularPrice: v.regularPrice, onSale: v.onSale, fontSize: 22)
                    : PriceView(price: p.price, regularPrice: p.regularPrice, maxPrice: p.maxPrice, onSale: p.onSale, fontSize: 22),
                if (_product == null) const Padding(padding: EdgeInsets.only(top: 24), child: LoadingView()),
                if (_product != null) ...[
                  if (p.shortDescription.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    HtmlWidget(p.shortDescription, textStyle: TextStyle(color: colors.muted, height: 1.5)),
                  ],
                  ..._variationAttrs.map((a) => _attributeSelector(a, cfg.variationStyle)),
                  if (v != null && v.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(v.description, style: TextStyle(color: colors.muted)),
                  ],
                  if (p.isVariable && _allSelected && v == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(tr('This combination is not available'), style: TextStyle(color: Colors.red.shade400)),
                    ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text(tr('Quantity'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    QuantityStepper(value: _qty, onChanged: (q) => setState(() => _qty = q)),
                  ]),
                  if (!cfg.stickyBuyBar && buyBar != null) Padding(padding: const EdgeInsets.only(top: 16), child: buyBar),
                  if (p.description.trim().isNotEmpty) ...[
                    const Divider(height: 40),
                    Text(tr('Description'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    HtmlWidget(p.description, textStyle: const TextStyle(height: 1.5)),
                  ],
                  _specs(p),
                  if (cfg.showReviews) _reviewsSection(p),
                  if (cfg.showRelated) _relatedSection(),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: cfg.stickyBuyBar ? buyBar : null,
    );
  }

  /* ---------- variation selectors ---------- */

  Widget _attributeSelector(ProductAttribute a, String style) {
    final selectedValue = _selected[a.key];
    final selectedLabel = a.options.where((o) => o.value == selectedValue).map((o) => o.label).join();
    final useSwatches = style == 'auto' && a.options.any((o) => o.hasSwatch);

    Widget body;
    if (style == 'dropdown') {
      body = DropdownButtonFormField<String>(
        value: selectedValue,
        isExpanded: true,
        hint: Text(tr('Choose {name}', {'name': a.name})),
        items: a.options
            .map((o) => DropdownMenuItem(
                  value: o.value,
                  enabled: _optionAvailable(a, o.value),
                  child: Text(
                    _optionAvailable(a, o.value) ? o.label : '${o.label} — ${tr('Out of stock')}',
                    style: TextStyle(color: _optionAvailable(a, o.value) ? null : AppColors.of(context).muted),
                  ),
                ))
            .toList(),
        onChanged: (v) => _select(a, v),
      );
    } else if (useSwatches) {
      body = Wrap(
        spacing: 10,
        runSpacing: 10,
        children: a.options.map((o) => _swatch(a, o, selectedValue == o.value)).toList(),
      );
    } else {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: a.options.map((o) {
          final available = _optionAvailable(a, o.value);
          return ChoiceChip(
            label: Text(o.label, style: TextStyle(decoration: available ? null : TextDecoration.lineThrough)),
            selected: selectedValue == o.value,
            onSelected: (_) => _select(a, o.value),
          );
        }).toList(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${a.name}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: selectedLabel.isEmpty ? tr('Select') : selectedLabel, style: TextStyle(color: AppColors.of(context).muted)),
          ])),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  Widget _swatch(ProductAttribute a, AttributeOption o, bool selected) {
    final theme = Theme.of(context);
    final available = _optionAvailable(a, o.value);
    final border = selected ? theme.colorScheme.primary : AppColors.of(context).border;
    Widget inner;
    if (o.image.isNotEmpty) {
      inner = ClipOval(child: NetImage(o.image, width: 34, height: 34));
    } else if (o.color.isNotEmpty) {
      inner = Container(width: 34, height: 34, decoration: BoxDecoration(color: hexColor(o.color), shape: BoxShape.circle, border: Border.all(color: Colors.black12)));
    } else {
      inner = SizedBox(width: 34, height: 34, child: Center(child: Text(o.label, maxLines: 1, style: const TextStyle(fontSize: 11))));
    }
    return Tooltip(
      message: o.label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _select(a, o.value),
        child: Stack(alignment: Alignment.center, children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: border, width: selected ? 2.2 : 1)),
            child: Opacity(opacity: available ? 1 : 0.35, child: inner),
          ),
          if (!available) Transform.rotate(angle: -0.75, child: Container(width: 40, height: 1.5, color: Colors.red.shade400)),
        ]),
      ),
    );
  }

  /* ---------- sections ---------- */

  Widget _specs(Product p) {
    final visible = p.attributes.where((a) => !a.variation).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Text(tr('Details'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...visible.map((a) => _specRow(a.name, a.options.map((o) => o.label).join(', '))),
      ],
    );
  }

  Widget _specRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: AppColors.of(context).muted))),
          Expanded(child: Text(v)),
        ]),
      );

  Widget _reviewsSection(Product p) {
    return FutureBuilder<List<Review>>(
      future: _reviews,
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 40),
            Row(children: [
              Expanded(
                child: Text(tr('Reviews ({n})', {'n': p.ratingCount}), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (p.reviewsAllowed) TextButton(onPressed: () => _writeReview(p), child: Text(tr('Write a review'))),
            ]),
            if (snap.connectionState != ConnectionState.done) const LoadingView(),
            if (snap.connectionState == ConnectionState.done && reviews.isEmpty)
              Text(tr('No reviews yet.'), style: TextStyle(color: AppColors.of(context).muted)),
            ...reviews.take(5).map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundImage: r.avatar.isNotEmpty ? NetworkImage(r.avatar) : null),
                  title: Row(children: [
                    Flexible(child: Text(r.author, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    ...List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 14, color: const Color(0xFFFBBF24))),
                  ]),
                  subtitle: Text(r.content),
                )),
          ],
        );
      },
    );
  }

  Future<void> _writeReview(Product p) async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (!auth.loggedIn || !mounted) return;
    }
    int rating = 5;
    final controller = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Your review'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFBBF24), size: 32),
                    onPressed: () => setSheet(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(controller: controller, maxLines: 4, decoration: InputDecoration(hintText: tr('What did you like or dislike?'))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Submit')))),
            ],
          ),
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    try {
      await Repo.addReview(p.id, rating, controller.text);
      if (!mounted) return;
      showSnack(context, tr('Thanks! Your review was submitted.'));
      setState(() => _reviews = Repo.reviews(p.id));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Widget _relatedSection() {
    if (_related == null) return const SizedBox.shrink();
    return FutureBuilder<Paged<Product>>(
      future: _related,
      builder: (context, snap) {
        final items = snap.data?.items ?? const <Product>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 40),
            Text(tr('You may also like'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ProductCard(product: items[i], mode: ProductCardMode.horizontal, width: 150),
              ),
            ),
          ],
        );
      },
    );
  }
}
