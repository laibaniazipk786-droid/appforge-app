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
      child: const WhatsAppIcon(size: 30),
    );
  }
}

/// WhatsApp-style logo (speech bubble with a phone), drawn so no icon font is needed.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;
  const WhatsAppIcon({super.key, this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BubblePainter(color),
        child: Center(child: Icon(Icons.phone, size: size * 0.48, color: color)),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  _BubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    final c = Offset(w * 0.53, w * 0.47);
    final r = w * 0.40;
    // Bubble: almost a full circle, open at the bottom-left where the tail goes.
    final path = Path()..addArc(Rect.fromCircle(center: c, radius: r), 2.35, 5.6);
    canvas.drawPath(path, paint);
    final tail = Path()
      ..moveTo(c.dx + r * -0.70, c.dy + r * 0.70)
      ..lineTo(w * 0.06, w * 0.95)
      ..lineTo(c.dx + r * -0.15, c.dy + r * 0.98);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.color != color;
}
