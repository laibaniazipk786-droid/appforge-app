import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../models/models.dart';
import '../services/repository.dart';
import '../providers/config_provider.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/product_card.dart';

/// Paginated product list for a category, search keyword, or all products.
class ProductListScreen extends StatefulWidget {
  final String title;
  final int? categoryId;
  final String? search;
  final bool isTab;

  const ProductListScreen({super.key, required this.title, this.categoryId, this.search, this.isTab = false});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const _sorts = {
    'date': 'Newest',
    'popularity': 'Popular',
    'rating': 'Top rated',
    'price': 'Price: low to high',
    'price-desc': 'Price: high to low',
  };

  final List<Product> _items = [];
  final _scroll = ScrollController();
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  Object? _error;
  String _sort = 'date';
  bool _gridView = true;
  ProductFilter _filter = ProductFilter();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _page > _totalPages) return;
    if (reset) {
      _page = 1;
      _totalPages = 1;
    }
    setState(() => _loading = true);
    try {
      final res = await Repo.products(
        page: _page,
        perPage: 12,
        category: (widget.categoryId ?? 0) > 0 ? widget.categoryId : null,
        search: widget.search,
        orderby: (widget.search ?? '').isNotEmpty && _sort == 'date' ? null : _sort,
        filters: _filter.toQuery(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(res.items);
        _totalPages = res.totalPages;
        _page++;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final picked = await showFilterSheet(context, current: _filter, categoryId: widget.categoryId);
    if (picked != null) {
      setState(() => _filter = picked);
      _load(reset: true);
    }
  }

  void _chooseSort() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _sorts.entries
              .map((e) => ListTile(
                    title: Text(tr(e.value)),
                    trailing: e.key == _sort ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                    onTap: () => Navigator.pop(ctx, e.key),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null && picked != _sort) {
      _sort = picked;
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items.isEmpty && _loading) {
      body = LoadingView();
    } else if (_items.isEmpty && _error != null) {
      body = MessageView.error(_error, title: tr('Something went wrong'), onRetry: () => _load(reset: true));
    } else if (_items.isEmpty) {
      body = MessageView(icon: Icons.inventory_2_outlined, title: tr('No products found'));
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.all(16),
          children: [
            if (_gridView)
              ProductGrid(products: _items)
            else
              ..._items.map((p) => Padding(padding: EdgeInsets.only(bottom: 12), child: ProductCard(product: p, mode: ProductCardMode.list))),
            if (_loading) LoadingView(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (context.watch<ConfigProvider>().settings.productPage.showFilters)
            IconButton(
              tooltip: tr('Filter'),
              icon: Badge(
                isLabelVisible: _filter.activeCount > 0,
                label: Text('${_filter.activeCount}'),
                child: const Icon(Icons.tune),
              ),
              onPressed: _openFilters,
            ),
          IconButton(icon: Icon(Icons.sort), tooltip: tr('Sort'), onPressed: _chooseSort),
          IconButton(
            icon: Icon(_gridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: body,
    );
  }
}
