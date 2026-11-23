import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../models/models.dart';
import '../providers/wishlist_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  final bool isTab;
  const WishlistScreen({super.key, this.isTab = false});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  Future<Paged<Product>>? _future;
  String _loadedFor = '';

  void _load(List<int> ids) {
    _loadedFor = ids.join(',');
    _future = ids.isEmpty ? null : Repo.products(include: ids, perPage: ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<WishlistProvider>().ids;
    if (ids.join(',') != _loadedFor) _load(ids);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Wishlist'))),
      body: ids.isEmpty
          ? MessageView(
              icon: Icons.favorite_border,
              title: tr('Your wishlist is empty'),
              subtitle: tr('Tap the heart on any product to save it here.'),
            )
          : FutureBuilder<Paged<Product>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return MessageView.error(snap.error, title: tr('Something went wrong'), onRetry: () => setState(() => _load(ids)));
                }
                // Keep the wishlist order (newest first) and hide removed products.
                final byId = {for (final p in snap.data?.items ?? const <Product>[]) p.id: p};
                final items = ids.map((id) => byId[id]).whereType<Product>().toList();
                return RefreshIndicator(
                  onRefresh: () async => setState(() => _load(ids)),
                  child: ListView(padding: const EdgeInsets.all(16), children: [ProductGrid(products: items)]),
                );
              },
            ),
    );
  }
}
