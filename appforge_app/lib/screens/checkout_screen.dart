import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import 'orders_screen.dart';
import 'webview_screen.dart';

/// Native checkout. WooCommerce calculates shipping/tax/coupons; offline gateways
/// (COD, bank transfer, cheque) complete in-app, online gateways open the secure
/// WooCommerce payment page in an in-app browser.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _AddressForm {
  final Map<String, TextEditingController> c = {
    for (final k in ['first_name', 'last_name', 'company', 'email', 'phone', 'address_1', 'address_2', 'city', 'postcode', 'state'])
      k: TextEditingController(),
  };
  String country = '';

  void fill(Map<String, String> data) {
    data.forEach((k, v) {
      if (c.containsKey(k) && v.isNotEmpty) c[k]!.text = v;
    });
    if ((data['country'] ?? '').isNotEmpty) country = data['country']!;
  }

  Map<String, String> toMap({bool contact = true}) {
    final m = <String, String>{'country': country};
    c.forEach((k, ctrl) {
      if (!contact && (k == 'email' || k == 'phone')) return;
      m[k] = ctrl.text.trim();
    });
    return m;
  }

  void dispose() {
    for (final ctrl in c.values) {
      ctrl.dispose();
    }
  }
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billing = _AddressForm();
  final _shipping = _AddressForm();
  final _note = TextEditingController();
  bool _shipDifferent = false;
  List<Country> _countries = [];
  CartSummary? _summary;
  String? _shippingMethod;
  String? _paymentMethod;
  bool _calculating = false;
  bool _placing = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _billing.fill({'first_name': user.firstName, 'last_name': user.lastName, 'email': user.email});
      _billing.fill(user.billing);
      _shipping.fill(user.shipping);
    }
    _init();
  }

  Future<void> _init() async {
    try {
      final countries = await Repo.countries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        if (_billing.country.isEmpty && countries.isNotEmpty) _billing.country = countries.first.code;
        if (_shipping.country.isEmpty && countries.isNotEmpty) _shipping.country = _billing.country;
      });
    } catch (_) {}
    _recalculate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _billing.dispose();
    _shipping.dispose();
    _note.dispose();
    super.dispose();
  }

  Map<String, String> get _shippingAddress => _shipDifferent ? _shipping.toMap(contact: false) : _billing.toMap(contact: false);

  void _scheduleRecalc() {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 700), _recalculate);
  }

  Future<void> _recalculate() async {
    if (!mounted) return;
    setState(() => _calculating = true);
    try {
      final s = await context.read<CartProvider>().calculate(
            billing: _billing.toMap(),
            shipping: _shippingAddress,
            shippingMethod: _shippingMethod,
            paymentMethod: _paymentMethod,
          );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _shippingMethod = s.selectedRate?.id;
        if (_paymentMethod == null || !s.paymentMethods.any((p) => p.id == _paymentMethod)) {
          _paymentMethod = s.paymentMethods.isNotEmpty ? s.paymentMethods.first.id : null;
        }
      });
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      showSnack(context, tr('Please fill in the required fields'), error: true);
      return;
    }
    final s = _summary;
    if (s == null) return;
    if (s.needsShipping && _shippingMethod == null) {
      showSnack(context, tr('No shipping method is available for your address'), error: true);
      return;
    }
    if (s.totals.total > 0 && _paymentMethod == null) {
      showSnack(context, tr('Please choose a payment method'), error: true);
      return;
    }

    final cart = context.read<CartProvider>();
    setState(() => _placing = true);
    try {
      final body = cart.requestBody(
        billing: _billing.toMap(),
        shipping: _shippingAddress,
        shippingMethod: _shippingMethod,
        paymentMethod: _paymentMethod,
      )..['customer_note'] = _note.text.trim();
      final res = await Repo.checkout(body);
      if (!mounted) return;
      final order = Order.fromJson(toMap(res['order']));
      final status = toStr(res['status']);

      if (status == 'pending_payment') {
        cart.clear();
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PaymentWebViewScreen(url: toStr(res['payment_url']))),
        );
        if (!mounted) return;
        _finish(order, paid == true);
      } else {
        cart.clear();
        _finish(order, true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _finish(Order order, bool paid) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order, paid: paid)));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Checkout'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (context.watch<ConfigProvider>().settings.cart.checkoutNote.isNotEmpty)
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 10),
                  Expanded(child: Text(context.watch<ConfigProvider>().settings.cart.checkoutNote)),
                ]),
              ),
            if (s?.freeShipping != null && !s!.freeShipping!.qualified && context.watch<ConfigProvider>().settings.cart.freeShippingBar)
              Padding(padding: EdgeInsets.only(bottom: 8), child: FreeShippingBar(info: s.freeShipping!)),
            _section('Billing details'),
            ..._addressFields(_billing, contact: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _shipDifferent,
              title: Text(tr('Ship to a different address')),
              onChanged: (v) {
                setState(() => _shipDifferent = v);
                _scheduleRecalc();
              },
            ),
            if (_shipDifferent) ...[
              _section('Shipping address'),
              ..._addressFields(_shipping, contact: false),
            ],
            if (s != null && s.needsShipping) ...[
              _section('Shipping method'),
              if (s.shippingRates.isEmpty)
                Text(tr('No shipping options for this address yet. Check your country / city / postcode.'), style: TextStyle(color: Colors.orange.shade800)),
              ...s.shippingRates.map((r) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: r.id,
                    groupValue: _shippingMethod,
                    title: Text(r.label),
                    secondary: Text(r.cost > 0 ? Money.format(r.cost) : tr('Free'), style: TextStyle(fontWeight: FontWeight.w600)),
                    onChanged: (v) {
                      setState(() => _shippingMethod = v);
                      _recalculate();
                    },
                  )),
            ],
            if (s != null && s.totals.total > 0) ...[
              _section('Payment'),
              if (s.paymentMethods.isEmpty) Text(tr('No payment methods are enabled in WooCommerce.')),
              ...s.paymentMethods.map((p) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: p.id,
                    groupValue: _paymentMethod,
                    title: Text(p.title),
                    subtitle: p.description.isEmpty ? null : Text(p.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                    secondary: p.native ? null : Icon(Icons.lock_outline, size: 18),
                    onChanged: (v) => setState(() => _paymentMethod = v),
                  )),
            ],
            _section('Order notes (optional)'),
            TextField(controller: _note, maxLines: 3, decoration: InputDecoration(hintText: tr('Notes about your order, e.g. delivery instructions'))),
            SizedBox(height: 20),
            _summaryBox(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _placing || _calculating || s == null ? null : _placeOrder,
            child: _placing
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('${tr('Place order')}${s != null ? ' · ${Money.format(s.totals.total)}' : ''}'),
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: EdgeInsets.only(top: 18, bottom: 10),
        child: Text(tr(t), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? tr('Required') : null;

  Widget _field(TextEditingController c, String label, {bool required = false, TextInputType? type, bool recalc = false}) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: required ? '${tr(label)} *' : tr(label)),
          validator: required ? _required : null,
          onChanged: recalc ? (_) => _scheduleRecalc() : null,
        ),
      );

  List<Widget> _addressFields(_AddressForm f, {required bool contact}) {
    final country = _countries.where((c) => c.code == f.country).toList();
    final states = country.isNotEmpty ? country.first.states : <CountryState>[];
    return [
      Row(children: [
        Expanded(child: _field(f.c['first_name']!, 'First name', required: true)),
        SizedBox(width: 12),
        Expanded(child: _field(f.c['last_name']!, 'Last name', required: true)),
      ]),
      if (contact) ...[
        _field(f.c['email']!, 'Email', required: true, type: TextInputType.emailAddress),
        _field(f.c['phone']!, 'Phone', required: true, type: TextInputType.phone),
      ],
      if (_countries.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _countries.any((c) => c.code == f.country) ? f.country : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Country *')),
            validator: (v) => v == null ? tr('Required') : null,
            items: _countries.map((c) => DropdownMenuItem(value: c.code, child: Text(c.name))).toList(),
            onChanged: (v) {
              setState(() {
                f.country = v ?? '';
                f.c['state']!.clear();
              });
              _scheduleRecalc();
            },
          ),
        ),
      if (states.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: states.any((s) => s.code == f.c['state']!.text) ? f.c['state']!.text : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('State / Province *')),
            validator: (v) => v == null ? tr('Required') : null,
            items: states.map((s) => DropdownMenuItem(value: s.code, child: Text(s.name))).toList(),
            onChanged: (v) {
              setState(() => f.c['state']!.text = v ?? '');
              _scheduleRecalc();
            },
          ),
        ),
      _field(f.c['address_1']!, 'Street address', required: true),
      _field(f.c['address_2']!, 'Apartment, suite, etc.'),
      Row(children: [
        Expanded(child: _field(f.c['city']!, 'City', required: true, recalc: true)),
        SizedBox(width: 12),
        Expanded(child: _field(f.c['postcode']!, 'Postcode', recalc: true)),
      ]),
    ];
  }

  Widget _summaryBox() {
    final s = _summary;
    if (s == null) return LoadingView();
    final t = s.totals;
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(tr(l), style: TextStyle(fontWeight: bold ? FontWeight.w700 : null, fontSize: bold ? 16 : 14)),
            const Spacer(),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 16 : 14)),
          ]),
        );
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        ...s.items.map((i) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${i['name']} × ${i['quantity']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                Text(Money.format(toDouble(i['line_total']))),
              ]),
            )),
        Divider(height: 20),
        row('Subtotal', Money.format(t.subtotal)),
        if (t.discount > 0) row('Discount', '-${Money.format(t.discount)}'),
        if (s.needsShipping) row('Shipping', t.shipping > 0 ? Money.format(t.shipping) : tr('Free')),
        if (t.tax > 0) row('Tax', Money.format(t.tax)),
        Divider(height: 20),
        row('Total', Money.format(t.total), bold: true),
        if (_calculating) Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      ]),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final Order order;
  final bool paid;
  const OrderSuccessScreen({super.key, required this.order, required this.paid});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.read<AuthProvider>().loggedIn;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(paid ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 96, color: paid ? Colors.green : Colors.orange),
              SizedBox(height: 20),
              Text(
                paid ? tr('Thank you for your order!') : tr('Order placed — payment pending'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                paid
                    ? tr('Order #{n} has been received. We have emailed you the details.', {'n': order.number})
                    : tr('Order #{n} was created but the payment was not completed. You can pay later from My orders.', {'n': order.number}),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              SizedBox(height: 32),
              if (loggedIn)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
                  child: Text(tr('View order')),
                ),
              SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text(tr('Continue shopping'))),
            ],
          ),
        ),
      ),
    );
  }
}
