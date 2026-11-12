import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final bool isTab;
  const CartScreen({super.key, this.isTab = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  CartSummary? _summary;
  bool _calculating = false;
  String _lastSignature = '';
  final _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  String _signature(CartProvider cart) =>
      '${cart.lines.map((l) => '${l.key}x${l.quantity}').join('|')}#${cart.coupons.join(',')}';

  Future<void> _recalculate(CartProvider cart) async {
    if (cart.isEmpty) {
      setState(() => _summary = null);
      return;
    }
    setState(() => _calculating = true);
    try {
      final s = await cart.calculate();
      if (!mounted) return;
      setState(() => _summary = s);
      for (final e in s.couponErrors) {
        showSnack(context, toStr(e['message'], 'Coupon is not valid'), error: true);
      }
      for (final e in s.errors) {
        showSnack(context, toStr(e['message']), error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  void _checkout() async {
    final settings = context.read<ConfigProvider>().settings;
    final auth = context.read<AuthProvider>();
    if (!settings.guestCheckout && !auth.loggedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen()));
      if (!auth.loggedIn || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final sig = _signature(cart);
    if (sig != _lastSignature) {
      _lastSignature = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recalculate(cart);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Cart ({n})', {'n': cart.count}))),
      body: cart.isEmpty
          ? MessageView(
              icon: Icons.shopping_bag_outlined,
              title: tr('Your cart is empty'),
              subtitle: tr('Browse products and add your favourites.'),
              actionLabel: widget.isTab ? null : tr('Continue shopping'),
              onAction: widget.isTab ? null : () => Navigator.of(context).popUntil((r) => r.isFirst),
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                ...cart.lines.map((l) => _lineTile(cart, l)),
                SizedBox(height: 8),
                _couponBox(cart),
                SizedBox(height: 16),
                _totals(),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _calculating ? null : _checkout,
                  child: Text('${tr('Checkout')} · ${Money.format(_summary?.totals.total ?? cart.estimatedSubtotal)}'),
                ),
              ),
            ),
    );
  }

  Widget _lineTile(CartProvider cart, CartLine l) {
    final attrs = l.variation.values.where((v) => v.isNotEmpty).join(' · ');
    return Dismissible(
      key: ValueKey(l.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => cart.remove(l),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            NetImage(l.image, width: 76, height: 76, radius: BorderRadius.circular(10)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                  if (attrs.isNotEmpty) Text(attrs, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(Money.format(l.price), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      QuantityStepper(value: l.quantity, min: 0, onChanged: (q) => cart.setQuantity(l, q)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _couponBox(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _couponController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: tr('Coupon code'), prefixIcon: Icon(Icons.local_offer_outlined), isDense: true),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: Size(80, 48)),
              onPressed: () {
                cart.addCoupon(_couponController.text);
                _couponController.clear();
                FocusScope.of(context).unfocus();
              },
              child: Text(tr('Apply')),
            ),
          ),
        ]),
        if (cart.coupons.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: cart.coupons.map((c) => InputChip(label: Text(c.toUpperCase()), onDeleted: () => cart.removeCoupon(c))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _totals() {
    final s = _summary;
    if (s == null) return _calculating ? LoadingView() : SizedBox.shrink();
    final t = s.totals;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        _row('Subtotal', Money.format(t.subtotal)),
        if (t.discount > 0) _row('Discount', '-${Money.format(t.discount)}', color: Colors.green.shade700),
        if (s.needsShipping) _row('Shipping', tr('Calculated at checkout'), muted: true),
        if (t.tax > 0) _row('Tax', Money.format(t.tax)),
        Divider(height: 24),
        _row('Total', Money.format(t.total), bold: true),
        if (_calculating) Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool muted = false, Color? color}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(tr(label), style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 16 : 14)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: bold ? 16 : 14,
                color: color ?? (muted ? Colors.grey.shade600 : null),
              )),
        ]),
      );
}
