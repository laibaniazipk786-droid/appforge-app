import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';

class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? radius;

  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius});

  @override
  Widget build(BuildContext context) {
    final ph = Theme.of(context).colorScheme.surfaceContainerHighest;
    final placeholder = Container(
      width: width,
      height: height,
      color: ph,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
    final Widget img = url.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) => Container(width: width, height: height, color: ph),
            errorWidget: (_, __, ___) => placeholder,
          );
    return radius == null ? img : ClipRRect(borderRadius: radius!, child: img);
  }
}

class PriceView extends StatelessWidget {
  final double price;
  final double regularPrice;
  final double maxPrice;
  final bool onSale;
  final double fontSize;

  const PriceView({
    super.key,
    required this.price,
    this.regularPrice = 0,
    this.maxPrice = 0,
    this.onSale = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final main = maxPrice > price ? '${Money.format(price)} – ${Money.format(maxPrice)}' : Money.format(price);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(main, style: TextStyle(fontWeight: FontWeight.w700, color: colors.price, fontSize: fontSize)),
        if (onSale && regularPrice > price)
          Text(
            Money.format(regularPrice),
            style: TextStyle(color: colors.muted, decoration: TextDecoration.lineThrough, fontSize: fontSize - 2),
          ),
      ],
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
}

class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  /// Error screen with a retry button; shows a friendly "no internet" message when offline.
  factory MessageView.error(Object? error, {String? title, VoidCallback? onRetry}) {
    final offline = error is ApiException && error.isOffline;
    return MessageView(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline,
      title: offline ? tr('No internet connection') : (title ?? '$error'),
      subtitle: offline ? tr('Check your connection and try again.') : (title != null ? '$error' : null),
      actionLabel: onRetry != null ? tr('Retry') : null,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
}

/// Slim bar shown while the phone is offline (saved content is still shown).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Api.online,
      builder: (context, online, _) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: online
            ? const SizedBox(width: double.infinity)
            : Material(
                color: Colors.grey.shade800,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr('You are offline — showing saved content'), style: const TextStyle(color: Colors.white, fontSize: 13))),
                  ]),
                ),
              ),
      ),
    );
  }
}

/// "Add Rs 1,200 more for FREE shipping" with a progress bar.
class FreeShippingBar extends StatelessWidget {
  final FreeShippingInfo info;
  const FreeShippingBar({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final done = info.qualified;
    final color = done ? Colors.green.shade600 : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.check_circle : Icons.local_shipping_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              done ? tr('You get FREE shipping!') : tr('Add {amount} more for FREE shipping', {'amount': Money.format(info.remaining)}),
              style: TextStyle(fontWeight: FontWeight.w600, color: done ? color : null),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: info.progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.15)),
          ),
        ),
      ]),
    );
  }
}
