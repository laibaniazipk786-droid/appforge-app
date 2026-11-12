import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../builder/actions.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

/// Track any order with order number + billing email (works for guests).
class TrackOrderScreen extends StatefulWidget {
  final bool isTab;
  const TrackOrderScreen({super.key, this.isTab = false});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final _order = TextEditingController();
  final _email = TextEditingController();
  TrackResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email.text = context.read<AuthProvider>().user?.email ?? '';
  }

  @override
  void dispose() {
    _order.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (_order.text.trim().isEmpty || _email.text.trim().isEmpty) {
      showSnack(context, tr('Enter your order number and email'), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await Repo.track(_order.text.trim(), _email.text.trim());
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) {
        setState(() => _result = null);
        showSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Track order'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('Enter the order number from your confirmation email and the email used at checkout.'),
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 16),
          TextField(
            controller: _order,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: tr('Order number'), prefixIcon: const Icon(Icons.tag)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: tr('Email'), prefixIcon: const Icon(Icons.mail_outline)),
            onSubmitted: (_) => _track(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _track,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(tr('Track')),
          ),
          if (_result != null) ...[const SizedBox(height: 24), _resultView(_result!)],
        ],
      ),
    );
  }

  Widget _resultView(TrackResult r) {
    final theme = Theme.of(context);
    final o = r.order;
    final cancelled = r.progress < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(tr('Order #{n}', {'n': o.number}), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Chip(label: Text(o.statusLabel), visualDensity: VisualDensity.compact),
          ]),
          Text('${formatDate(o.date)} · ${Money.format(o.total)}', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 16),
          if (cancelled)
            Text(tr('This order is {s}.', {'s': o.statusLabel.toLowerCase()}), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600))
          else
            ...List.generate(r.steps.length, (i) {
              final done = i <= r.progress;
              final last = i == r.steps.length - 1;
              return IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Column(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: done ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary) : null,
                    ),
                    if (!last)
                      Expanded(
                        child: Container(width: 2, color: i < r.progress ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest),
                      ),
                  ]),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Text(tr(r.steps[i]), style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.w400)),
                  ),
                ]),
              );
            }),
          if (r.tracking.isNotEmpty) ...[
            const Divider(height: 24),
            Text(tr('Shipment'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ...r.tracking.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(t['provider'] ?? ''),
                  subtitle: Text(t['number'] ?? ''),
                  trailing: (t['url'] ?? '').isEmpty ? null : const Icon(Icons.open_in_new),
                  onTap: (t['url'] ?? '').isEmpty ? null : () => AppActions.launchExternal('external', t['url']!),
                )),
          ],
          if (r.notes.isNotEmpty) ...[
            const Divider(height: 24),
            Text(tr('Updates'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...r.notes.map((n) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${formatDate(n['date'] ?? '')} — ${n['content']}'),
                )),
          ],
          const Divider(height: 24),
          ...o.items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${i.name} × ${i.quantity}')),
                  Text(Money.format(i.total)),
                ]),
              )),
        ],
      ),
    );
  }
}
