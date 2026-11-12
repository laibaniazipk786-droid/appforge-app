import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../widgets/common.dart';
import 'app_settings_screen.dart';
import 'auth_screens.dart';
import 'contact_screen.dart';
import 'orders_screen.dart';
import 'post_screens.dart';
import 'track_order_screen.dart';

class AccountScreen extends StatelessWidget {
  final bool isTab;
  const AccountScreen({super.key, this.isTab = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<ConfigProvider>().settings;
    final theme = Theme.of(context);
    final user = auth.user;

    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Account'))),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(settings.cardRadius + 4)),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                backgroundImage: user != null && user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                child: user == null ? Icon(Icons.person, color: theme.colorScheme.onPrimary, size: 30) : null,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name.isNotEmpty == true ? user!.name : (user?.username ?? tr('Hello, guest')),
                      style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text(user?.email ?? tr('Sign in to track orders and checkout faster'), style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.75), fontSize: 13)),
                ]),
              ),
            ]),
          ),
          SizedBox(height: 16),
          if (user == null)
            ElevatedButton(onPressed: () => push(LoginScreen()), child: Text(tr('Sign in / Register')))
          else ...[
            _tile(context, Icons.receipt_long_outlined, 'My orders', () => push(OrdersScreen())),
            _tile(context, Icons.person_outline, 'Edit profile', () => push(EditProfileScreen())),
            _tile(context, Icons.location_on_outlined, 'Addresses', () => push(EditProfileScreen(addressesOnly: true))),
            _tile(context, Icons.lock_outline, 'Change password', () => push(ChangePasswordScreen())),
          ],
          _tile(context, Icons.local_shipping_outlined, 'Track order', () => push(TrackOrderScreen())),
          _tile(context, Icons.support_agent, 'Contact us', () => push(ContactScreen())),
          _tile(context, Icons.article_outlined, 'Blog', () => push(PostsScreen())),
          _tile(context, Icons.settings_outlined, 'Settings', () => push(AppSettingsScreen())),
          if (user != null) ...[
            _tile(context, Icons.logout, 'Sign out', () => auth.logout()),
            _tile(context, Icons.delete_outline, 'Delete account', () => push(DeleteAccountScreen()), danger: true),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool danger = false}) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: Icon(icon, color: danger ? Colors.red : null),
        title: Text(tr(title), style: TextStyle(color: danger ? Colors.red : null)),
        trailing: Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final bool addressesOnly;
  const EditProfileScreen({super.key, this.addressesOnly = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _addressFields = {
    'first_name': 'First name',
    'last_name': 'Last name',
    'phone': 'Phone',
    'address_1': 'Address',
    'address_2': 'Apartment, suite',
    'city': 'City',
    'state': 'State code',
    'postcode': 'Postcode',
    'country': 'Country code (e.g. PK)',
  };

  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _display;
  final Map<String, TextEditingController> _billing = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _first = TextEditingController(text: u.firstName);
    _last = TextEditingController(text: u.lastName);
    _display = TextEditingController(text: u.displayName);
    for (final k in _addressFields.keys) {
      _billing[k] = TextEditingController(text: u.billing[k] ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _display, ..._billing.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().updateProfile({
        if (!widget.addressesOnly) ...{
          'first_name': _first.text.trim(),
          'last_name': _last.text.trim(),
          'display_name': _display.text.trim(),
        },
        'billing': _billing.map((k, c) => MapEntry(k, c.text.trim())),
      });
      if (!mounted) return;
      showSnack(context, tr('Saved'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label) =>
        Padding(padding: EdgeInsets.only(bottom: 12), child: TextField(controller: c, decoration: InputDecoration(labelText: tr(label))));
    return Scaffold(
      appBar: AppBar(title: Text(widget.addressesOnly ? 'Billing address' : 'Edit profile')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (!widget.addressesOnly) ...[
            field(_first, 'First name'),
            field(_last, 'Last name'),
            field(_display, 'Display name'),
            Divider(height: 32),
            Text(tr('Billing address'), style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
          ],
          ..._addressFields.entries.map((e) => field(_billing[e.key]!, e.value)),
          SizedBox(height: 8),
          ElevatedButton(onPressed: _busy ? null : _save, child: Text(tr('Save'))),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_new.text.length < 6) {
      showSnack(context, tr('New password must be at least 6 characters'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().changePassword(_old.text, _new.text);
      if (!mounted) return;
      showSnack(context, tr('Password changed'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Change password'))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        TextField(controller: _old, obscureText: true, decoration: InputDecoration(labelText: tr('Current password'))),
        SizedBox(height: 12),
        TextField(controller: _new, obscureText: true, decoration: InputDecoration(labelText: tr('New password'))),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _busy ? null : _save, child: Text(tr('Update password'))),
      ]),
    );
  }
}

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().deleteAccount(_pass.text);
      if (!mounted) return;
      showSnack(context, tr('Your account has been deleted'));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Delete account'))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Text(tr('This permanently deletes your account and personal data. Past orders stay with the store for legal records.')),
        SizedBox(height: 16),
        TextField(controller: _pass, obscureText: true, decoration: InputDecoration(labelText: tr('Confirm with your password'))),
        SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy ? null : _delete,
          child: Text(tr('Delete my account')),
        ),
      ]),
    );
  }
}
