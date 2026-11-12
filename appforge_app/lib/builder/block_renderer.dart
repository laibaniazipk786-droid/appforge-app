import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/config_provider.dart';
import '../screens/contact_screen.dart';
import '../screens/post_screens.dart';
import '../screens/product_list_screen.dart';
import '../screens/search_screen.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'actions.dart';

/// Renders a list of builder blocks — the same blocks dragged in WordPress.
class BlockList extends StatelessWidget {
  final List<BlockData> blocks;
  const BlockList({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks.map((b) => BlockView(key: ValueKey(b.id), block: b)).toList(),
    );
  }
}

class BlockView extends StatelessWidget {
  final BlockData block;
  const BlockView({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final child = _content();
    if (child == null) return const SizedBox.shrink();
    final bg = block.str('bg_color');
    return Container(
      color: bg.isEmpty ? null : hexColor(bg),
      padding: EdgeInsets.symmetric(
        horizontal: block.number('padding_h', 16),
        vertical: block.number('padding_v', 8),
      ),
      child: child,
    );
  }

  Widget? _content() {
    switch (block.type) {
      case 'search':
        return _SearchBlock(block);
      case 'slider':
        return _SliderBlock(block);
      case 'banner':
        return _BannerBlock(block);
      case 'heading':
        return _HeadingBlock(block);
      case 'text':
        return _TextBlock(block);
      case 'categories':
        return _CategoriesBlock(block);
      case 'products':
        return _ProductsBlock(block);
      case 'button':
        return _ButtonBlock(block);
      case 'posts':
        return _PostsBlock(block);
      case 'html':
        return _HtmlBlock(block);
      case 'links':
        return _LinksBlock(block);
      case 'faq':
        return _FaqBlock(block);
      case 'contact_info':
        return _ContactBlock(block);
      case 'spacer':
        return SizedBox(height: block.number('height', 16));
      case 'divider':
        return Divider(height: block.number('thickness', 1), thickness: block.number('thickness', 1), color: hexColor(block.str('color', '#E2E8F0')));
      default:
        return null; // Unknown block from a newer plugin version: skip gracefully.
    }
  }
}

TextAlign _align(String a) => a == 'center' ? TextAlign.center : (a == 'right' ? TextAlign.right : TextAlign.left);

/* ---------------- simple blocks ---------------- */

class _SearchBlock extends StatelessWidget {
  final BlockData b;
  const _SearchBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Row(children: [
          Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 10),
          Text(tr(b.str('placeholder', 'Search products...')), style: TextStyle(color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}

class _BannerBlock extends StatelessWidget {
  final BlockData b;
  const _BannerBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final image = b.str('image');
    if (image.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => AppActions.open(context, b.action('action')),
      child: NetImage(image, height: b.number('height', 140), width: double.infinity, radius: BorderRadius.circular(b.number('radius', 12))),
    );
  }
}

class _HeadingBlock extends StatelessWidget {
  final BlockData b;
  const _HeadingBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final color = b.str('color');
    final align = b.str('align', 'left');
    final text = Text(
      tr(b.str('text')),
      textAlign: _align(align),
      style: TextStyle(fontSize: b.number('size', 18), fontWeight: FontWeight.w700, color: color.isEmpty ? null : hexColor(color)),
    );
    final viewAll = b.flag('show_view_all') && !b.action('action').isNone;
    if (!viewAll) return SizedBox(width: double.infinity, child: text);
    return Row(
      mainAxisAlignment: align == 'center' ? MainAxisAlignment.center : (align == 'right' ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween),
      children: [
        Flexible(child: text),
        TextButton(onPressed: () => AppActions.open(context, b.action('action'), title: b.str('text')), child: Text(tr('View all'))),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  final BlockData b;
  const _TextBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final color = b.str('color');
    return Text(
      tr(b.str('content')),
      textAlign: _align(b.str('align', 'left')),
      style: TextStyle(fontSize: b.number('size', 14), height: 1.5, color: color.isEmpty ? null : hexColor(color)),
    );
  }
}

class _ButtonBlock extends StatelessWidget {
  final BlockData b;
  const _ButtonBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final color = b.str('color');
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.isEmpty ? null : hexColor(color),
        foregroundColor: hexColor(b.str('text_color', '#FFFFFF'), Colors.white),
      ),
      onPressed: () => AppActions.open(context, b.action('action'), title: b.str('label')),
      child: Text(tr(b.str('label', 'Shop now'))),
    );
    return b.flag('full_width', true) ? SizedBox(width: double.infinity, child: button) : Center(child: button);
  }
}

/* ---------------- slider ---------------- */

class _SliderBlock extends StatefulWidget {
  final BlockData b;
  const _SliderBlock(this.b);

  @override
  State<_SliderBlock> createState() => _SliderBlockState();
}

class _SliderBlockState extends State<_SliderBlock> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  List<Map<String, dynamic>> get _items =>
      toList(widget.b.props['items']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => toStr(e['image']).isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    if (widget.b.flag('autoplay', true)) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        final count = _items.length;
        if (count < 2 || !_controller.hasClients) return;
        _controller.animateToPage((_index + 1) % count, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();
    final radius = BorderRadius.circular(widget.b.number('radius', 12));
    return SizedBox(
      height: widget.b.number('height', 170),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => AppActions.open(context, ActionData.fromJson(items[i]['action'])),
              child: NetImage(toStr(items[i]['image']), radius: radius, width: double.infinity),
            ),
          ),
          if (items.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(i == _index ? 1 : 0.6), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------- data blocks ---------------- */

class _CategoriesBlock extends StatefulWidget {
  final BlockData b;
  const _CategoriesBlock(this.b);

  @override
  State<_CategoriesBlock> createState() => _CategoriesBlockState();
}

class _CategoriesBlockState extends State<_CategoriesBlock> {
  late final Future<List<Category>> _future =
      Repo.categories(parent: widget.b.integer('parent', 0), limit: widget.b.integer('limit', 10));
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _open(Category c) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(title: c.name, categoryId: c.id)));

  Widget _visual(Category c, double size, bool circle, bool useIcon) {
    final theme = Theme.of(context);
    final color = hexColor(c.iconColor, theme.colorScheme.primary);
    final showIcon = (useIcon || c.image.isEmpty) && c.icon.isNotEmpty && hasIcon(c.icon);
    Widget inner;
    if (!showIcon && c.image.isNotEmpty) {
      inner = NetImage(c.image);
    } else if (showIcon) {
      inner = Center(child: Icon(iconFor(c.icon, selected: true), color: color, size: size * 0.46));
    } else {
      inner = Center(
        child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
            style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w700, color: color)),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: showIcon || c.image.isEmpty ? color.withOpacity(0.12) : theme.colorScheme.surface,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final circle = b.str('shape', 'circle') == 'circle';
    final showName = b.flag('show_name', true);
    final showCount = b.flag('show_count');
    final useIcon = b.str('display') == 'icon';
    final size = b.number('item_size', 64).clamp(36, 120).toDouble();
    final layout = b.str('layout', 'horizontal');
    return FutureBuilder<List<Category>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 90, child: LoadingView());
        final cats = snap.data ?? const <Category>[];
        if (cats.isEmpty) return const SizedBox.shrink();

        Widget cell(Category c, double sz) => InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _open(c),
              child: SizedBox(
                width: sz + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _visual(c, sz, circle, useIcon),
                    if (showName) ...[
                      const SizedBox(height: 6),
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ],
                    if (showCount)
                      Text(tr('{n} items', {'n': c.count}), style: TextStyle(fontSize: 10, color: AppColors.of(context).muted)),
                  ],
                ),
              ),
            );
        final cellHeight = size + (showName ? 24 : 4) + (showCount ? 14 : 0);

        switch (layout) {
          case 'grid':
            return LayoutBuilder(builder: (context, box) {
              final cols = b.integer('columns', 4).clamp(2, 5).toInt();
              final w = box.maxWidth / cols;
              final sz = size > w - 16 ? (w - 16 > 24 ? w - 16 : 24.0) : size;
              return Wrap(
                runSpacing: 12,
                children: cats.map((cat) => SizedBox(width: w, child: Center(child: cell(cat, sz)))).toList(),
              );
            });
          case 'grid_slider':
            return LayoutBuilder(builder: (context, box) {
              final cols = b.integer('columns', 4).clamp(2, 5).toInt();
              final rows = b.integer('rows', 2).clamp(1, 3).toInt();
              final perPage = cols * rows;
              final pages = (cats.length / perPage).ceil();
              final w = box.maxWidth / cols;
              final sz = size > w - 16 ? (w - 16 > 24 ? w - 16 : 24.0) : size;
              final rowH = sz + (showName ? 24 : 4) + (showCount ? 14 : 0) + 10;
              return Column(children: [
                SizedBox(
                  height: rowH * rows,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, p) {
                      final slice = cats.skip(p * perPage).take(perPage).toList();
                      return Wrap(
                        children: slice.map((cat) => SizedBox(width: w, height: rowH, child: Align(alignment: Alignment.topCenter, child: cell(cat, sz)))).toList(),
                      );
                    },
                  ),
                ),
                if (pages > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? Theme.of(context).colorScheme.primary : AppColors.of(context).border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ]);
            });
          case 'cards_slider':
            final radius = BorderRadius.circular(context.read<ConfigProvider>().settings.cardRadius);
            return SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  return GestureDetector(
                    onTap: () => _open(c),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: SizedBox(
                        width: 180,
                        child: Stack(fit: StackFit.expand, children: [
                          c.image.isNotEmpty
                              ? NetImage(c.image)
                              : Container(color: Theme.of(context).colorScheme.surface, child: Center(child: _visual(c, 70, true, true))),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xAA000000)],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 12,
                            end: 12,
                            bottom: 10,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                              if (showCount) Text(tr('{n} items', {'n': c.count}), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            );
          default:
            return SizedBox(
              height: cellHeight + 4,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) => cell(cats[i], size),
              ),
            );
        }
      },
    );
  }
}

class _ProductsBlock extends StatefulWidget {
  final BlockData b;
  const _ProductsBlock(this.b);

  @override
  State<_ProductsBlock> createState() => _ProductsBlockState();
}

class _ProductsBlockState extends State<_ProductsBlock> {
  late final Future<Paged<Product>> _future = _load();

  Future<Paged<Product>> _load() {
    final b = widget.b;
    final source = b.str('source', 'latest');
    return Repo.products(
      perPage: b.integer('limit', 8),
      source: source == 'category' ? null : source,
      category: source == 'category' ? b.integer('category') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    return FutureBuilder<Paged<Product>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 200, child: LoadingView());
        final items = snap.data?.items ?? const <Product>[];
        if (items.isEmpty) return const SizedBox.shrink();
        switch (b.str('layout', 'grid')) {
          case 'horizontal':
            return SizedBox(
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ProductCard(product: items[i], mode: ProductCardMode.horizontal, width: 150),
              ),
            );
          case 'list':
            return Column(
              children: items
                  .map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: ProductCard(product: p, mode: ProductCardMode.list)))
                  .toList(),
            );
          default:
            return ProductGrid(products: items, columns: b.integer('columns', 2));
        }
      },
    );
  }
}

class _PostsBlock extends StatefulWidget {
  final BlockData b;
  const _PostsBlock(this.b);

  @override
  State<_PostsBlock> createState() => _PostsBlockState();
}

class _PostsBlockState extends State<_PostsBlock> {
  late final Future<Paged<Post>> _future = Repo.posts(perPage: widget.b.integer('limit', 5));

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.b.str('layout') == 'horizontal';
    return FutureBuilder<Paged<Post>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 120, child: LoadingView());
        final posts = snap.data?.items ?? const <Post>[];
        if (posts.isEmpty) return const SizedBox.shrink();
        if (horizontal) {
          return SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 230, child: PostCard(post: posts[i], vertical: true)),
            ),
          );
        }
        return Column(
          children: posts.map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: PostCard(post: p))).toList(),
        );
      },
    );
  }
}

/* ---------------- content blocks ---------------- */

class _HtmlBlock extends StatelessWidget {
  final BlockData b;
  const _HtmlBlock(this.b);

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      b.str('content'),
      textStyle: const TextStyle(height: 1.55, fontSize: 15),
      onTapUrl: (url) => AppActions.launchExternal('external', url),
    );
  }
}

class _LinksBlock extends StatelessWidget {
  final BlockData b;
  const _LinksBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = toList(b.props['items']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final primary = theme.colorScheme.primary;
    Widget icon(String name, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(size * 0.3)),
          child: Icon(iconFor(toStr(name, 'info')), color: primary, size: size * 0.55),
        );

    if (b.str('layout') == 'grid') {
      return LayoutBuilder(builder: (context, box) {
        final cols = b.integer('columns', 4).clamp(2, 5).toInt();
        final w = box.maxWidth / cols;
        return Wrap(
          runSpacing: 14,
          children: items
              .map((it) => SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => AppActions.open(context, ActionData.fromJson(it['action']), title: tr(toStr(it['label']))),
                      child: Column(children: [
                        icon(toStr(it['icon']), 50),
                        const SizedBox(height: 6),
                        Text(tr(toStr(it['label'])), maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ))
              .toList(),
        );
      });
    }
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: AppColors.of(context).border),
            ListTile(
              leading: icon(toStr(items[i]['icon']), 36),
              title: Text(tr(toStr(items[i]['label']))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppActions.open(context, ActionData.fromJson(items[i]['action']), title: tr(toStr(items[i]['label']))),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqBlock extends StatelessWidget {
  final BlockData b;
  const _FaqBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = toList(b.props['items']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return Column(
      children: items
          .map((q) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(toStr(q['question']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [HtmlWidget(toStr(q['answer']), textStyle: const TextStyle(height: 1.5))],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ContactBlock extends StatelessWidget {
  final BlockData b;
  const _ContactBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final contact = context.watch<ConfigProvider>().settings.contact;
    return ContactCard(contact: contact, title: tr(b.str('title')), showFormButton: b.flag('show_form_button', true));
  }
}
