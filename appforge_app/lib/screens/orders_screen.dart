import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'webview_screen.dart';

Color statusColor(String status) {
  switch (status) {
    case 'completed':
      return Colors.green;
    case 'processing':
      return Colors.blue;
    case 'on-hold':
    case 'pending':
      return Colors.orange;
    case 'cancelled':
    case 'failed':
    case 'refunded':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class OrdersScreen extends StatefulWidget {
  final bool isTab;
  const OrdersScreen({super.key, this.isTab = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<Paged<Order>>? _future;

  void _load() => setState(() => _future = Repo.orders());

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.loggedIn) {
      _future = null;
      return Scaffold(
        appBar: AppBar(title: Text(tr('My orders'))),
        body: MessageView(
          icon: Icons.lock_outline,
          title: tr('Sign in to see your orders'),
          actionLabel: tr('Sign in'),
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen())),
        ),
      );
    }
    _future ??= Repo.orders();
    return Scaffold(
      appBar: AppBar(title: Text(tr('My orders'))),
      body: FutureBuilder<Paged<Order>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return LoadingView();
          if (snap.hasError) {
            return MessageView(icon: Icons.wifi_off, title: tr('Could not load orders'), subtitle: '${snap.error}', actionLabel: tr('Retry'), onAction: _load);
          }
          final orders = snap.data?.items ?? <Order>[];
          if (orders.isEmpty) return MessageView(icon: Icons.receipt_long_outlined, title: tr('No orders yet'));
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = orders[i];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Text(tr('Order #{n}', {'n': o.number}), style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${formatDate(o.date)} · ${tr('{n} item(s)', {'n': o.items.length})}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Money.format(o.total), style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text(o.statusLabel, style: TextStyle(color: statusColor(o.status), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));
                      _load();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Order> _future = Repo.order(widget.orderId);

  void _reload() => setState(() => _future = Repo.order(widget.orderId));

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Cancel this order?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Yes, cancel'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Repo.cancelOrder(widget.orderId);
      if (!mounted) return;
      showSnack(context, tr('Order cancelled'));
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _pay(Order o) async {
    final paid = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PaymentWebViewScreen(url: o.paymentUrl)));
    if (paid == true && mounted) showSnack(context, tr('Payment received. Thank you!'));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Order details'))),
      body: FutureBuilder<Order>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return LoadingView();
          if (snap.hasError) return MessageView(icon: Icons.error_outline, title: '${snap.error}', actionLabel: tr('Retry'), onAction: _reload);
          final o = snap.data!;
          final surface = Theme.of(context).colorScheme.surface;
          Widget card(List<Widget> children) => Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              );
          Widget row(String l, String v, {bool bold = false}) => Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(tr(l), style: TextStyle(fontWeight: bold ? FontWeight.w700 : null)),
                  const Spacer(),
                  Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
                ]),
              );
          final address = [o.shipping['address_1'], o.shipping['city'], o.shipping['state'], o.shipping['country']]
              .where((e) => (e ?? '').isNotEmpty)
              .join(', ');

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              card([
                Row(children: [
                  Text(tr('Order #{n}', {'n': o.number}), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor(o.status).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(o.statusLabel, style: TextStyle(color: statusColor(o.status), fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ]),
                SizedBox(height: 4),
                Text(formatDate(o.date), style: TextStyle(color: Colors.grey.shade600)),
              ]),
              card([
                ...o.items.map((i) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        NetImage(i.image, width: 56, height: 56, radius: BorderRadius.circular(8)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.name, style: TextStyle(fontWeight: FontWeight.w500)),
                            ...i.meta.map((m) => Text(m, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                            Text(tr('Qty {n}', {'n': i.quantity}), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ]),
                        ),
                        Text(Money.format(i.total)),
                      ]),
                    )),
                Divider(height: 24),
                row('Subtotal', Money.format(o.subtotal)),
                if (o.discountTotal > 0) row('Discount', '-${Money.format(o.discountTotal)}'),
                if (o.shippingMethod.isNotEmpty) row('${tr('Shipping')} (${o.shippingMethod})', Money.format(o.shippingTotal)),
                if (o.taxTotal > 0) row('Tax', Money.format(o.taxTotal)),
                row('Total', Money.format(o.total), bold: true),
              ]),
              card([
                Text(tr('Payment'), style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(o.paymentMethod.isEmpty ? '—' : o.paymentMethod),
                if (address.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(tr('Shipping to'), style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('${o.shipping['first_name'] ?? ''} ${o.shipping['last_name'] ?? ''}\n$address'),
                ],
                if (o.customerNote.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(tr('Note'), style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(o.customerNote),
                ],
              ]),
              if (o.needsPayment && o.paymentUrl.isNotEmpty && o.status != 'cancelled')
                ElevatedButton(onPressed: () => _pay(o), child: Text(tr('Pay now'))),
              if (o.canCancel) ...[
                SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red)),
                  onPressed: _cancel,
                  child: Text(tr('Cancel order')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
