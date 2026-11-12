import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/config_provider.dart';
import '../screens/product_detail_screen.dart';
import 'common.dart';

enum ProductCardMode { grid, horizontal, list }

/// Product card. The style (standard / bordered / minimal) and corner radius come from the builder theme.
class ProductCard extends StatelessWidget {
  final Product product;
  final ProductCardMode mode;
  final double? width;

  const ProductCard({super.key, required this.product, this.mode = ProductCardMode.grid, this.width});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ConfigProvider>().settings;
    final radius = BorderRadius.circular(settings.cardRadius);
    final style = settings.productCard;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    BoxDecoration deco;
    switch (style) {
      case 'bordered':
        deco = BoxDecoration(color: theme.colorScheme.surface, borderRadius: radius, border: Border.all(color: colors.border));
        break;
      case 'minimal':
        deco = BoxDecoration(borderRadius: radius);
        break;
      default:
        deco = BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: Offset(0, 3))],
        );
    }

    final image = Stack(
      children: [
        Positioned.fill(
          child: NetImage(
            product.image,
            radius: style == 'minimal' ? radius : BorderRadius.only(topLeft: radius.topLeft, topRight: radius.topRight),
          ),
        ),
        if (product.onSale)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: colors.sale, borderRadius: BorderRadius.circular(6)),
              child: Text(tr('SALE'), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        if (!product.inStock)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
              child: Text(tr('Out of stock'), style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );

    final info = Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3)),
          if (product.rating > 0) ...[
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
              SizedBox(width: 2),
              Text(product.rating.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ],
          SizedBox(height: 4),
          PriceView(
            price: product.price,
            regularPrice: product.regularPrice,
            maxPrice: product.maxPrice,
            onSale: product.onSale,
            fontSize: 13,
          ),
        ],
      ),
    );

    Widget child;
    if (mode == ProductCardMode.list) {
      child = Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: NetImage(product.image, radius: BorderRadius.only(topLeft: radius.topLeft, bottomLeft: radius.bottomLeft)),
          ),
          Expanded(child: info),
        ],
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [AspectRatio(aspectRatio: 1, child: image), info],
      );
    }

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id, preview: product))),
          child: Ink(decoration: deco, child: child),
        ),
      ),
    );
  }
}

/// Grid that sizes cards by content (no fixed aspect ratio overflow).
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final int columns;
  final double spacing;
  final bool shrinkWrap;

  const ProductGrid({super.key, required this.products, this.columns = 2, this.spacing = 12, this.shrinkWrap = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = columns.clamp(1, 4).toInt();
      final w = (constraints.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: products.map((p) => ProductCard(product: p, width: w)).toList(),
      );
    });
  }
}
