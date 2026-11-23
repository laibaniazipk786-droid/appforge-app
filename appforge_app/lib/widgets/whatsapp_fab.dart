import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/config_provider.dart';
import 'common.dart';

/// Opens a WhatsApp chat with the store, with [text] already typed.
Future<void> openWhatsApp(BuildContext context, String number, String text) async {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse('https://wa.me/$digits${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, tr('Could not open WhatsApp'), error: true);
}

/// Floating WhatsApp button configured in WordPress → AppForge → Marketing.
/// Pass [product] on product pages to send the product name, price and link.
class WhatsAppFab extends StatelessWidget {
  final Product? product;
  final String price;

  const WhatsAppFab({super.key, this.product, this.price = ''});

  /// Where the button sits (bottom right or left).
  static FloatingActionButtonLocation location(BuildContext context) =>
      context.read<ConfigProvider>().settings.whatsApp.left ? FloatingActionButtonLocation.startFloat : FloatingActionButtonLocation.endFloat;

  static bool visible(BuildContext context, {required bool onProduct}) {
    final wa = context.watch<ConfigProvider>().settings.whatsApp;
    return wa.enabled && (onProduct ? wa.showOnProduct : wa.showOnHome);
  }

  @override
  Widget build(BuildContext context) {
    final wa = context.watch<ConfigProvider>().settings.whatsApp;
    final p = product;
    final text = p == null ? wa.message : wa.productText(p.name, price, p.permalink);
    return FloatingActionButton(
      heroTag: 'whatsapp-fab',
      tooltip: tr('Chat on WhatsApp'),
      backgroundColor: hexColor(wa.color, const Color(0xFF25D366)),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      onPressed: () => openWhatsApp(context, wa.number, text),
      child: const Icon(Icons.whatsapp, size: 30),
    );
  }
}
