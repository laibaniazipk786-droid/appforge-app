import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../providers/config_provider.dart';
import '../providers/wishlist_provider.dart';

/// Heart button. `compact` = small round button for product cards.
class WishlistButton extends StatelessWidget {
  final int productId;
  final bool compact;

  const WishlistButton({super.key, required this.productId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<ConfigProvider>().settings.productPage.showWishlist) return const SizedBox.shrink();
    final wishlist = context.watch<WishlistProvider>();
    final active = wishlist.contains(productId);
    final color = active ? Colors.red.shade500 : (compact ? Colors.black87 : null);

    void onTap() {
      final added = wishlist.toggle(productId);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(added ? tr('Added to wishlist') : tr('Removed from wishlist')),
        ));
    }

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Icon(active ? Icons.favorite : Icons.favorite_border, key: ValueKey(active), color: color, size: compact ? 18 : 24),
    );

    if (!compact) {
      return IconButton(tooltip: tr('Wishlist'), onPressed: onTap, icon: icon);
    }
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: icon),
      ),
    );
  }
}
