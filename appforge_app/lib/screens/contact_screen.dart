import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../builder/actions.dart';
import '../core/i18n.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

/// Contact details (call / WhatsApp / email / map) + in-app contact form.
class ContactScreen extends StatefulWidget {
  final bool isTab;
  const ContactScreen({super.key, this.isTab = false});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user;
    if (u != null) {
      _name.text = u.name;
      _email.text = u.email;
      _phone.text = u.billing['phone'] ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final msg = await Repo.contact({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      showSnack(context, msg.isNotEmpty ? msg : tr('Thank you! We will get back to you soon.'));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConfigProvider>().settings.contact;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Contact us'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContactCard(contact: c),
          if (c.formEnabled) ...[
            const SizedBox(height: 24),
            Text(tr('Send us a message'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: tr('Your name')),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('Required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: tr('Email')),
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : tr('Enter a valid email'),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Phone'))),
                const SizedBox(height: 12),
                TextFormField(controller: _subject, decoration: InputDecoration(labelText: tr('Subject'))),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _message,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: tr('Message'), alignLabelWithHint: true),
                  validator: (v) => (v ?? '').trim().length < 5 ? tr('Please write a message') : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _send,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(tr('Send message')),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable contact details card (also used by the "Contact info" block).
class ContactCard extends StatelessWidget {
  final ContactInfo contact;
  final String? title;
  final bool showFormButton;

  const ContactCard({super.key, required this.contact, this.title, this.showFormButton = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    void add(IconData icon, String label, String value, VoidCallback? onTap) {
      if (value.trim().isEmpty) return;
      rows.add(ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
          foregroundColor: theme.colorScheme.primary,
          child: Icon(icon, size: 20),
        ),
        title: Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
        subtitle: Text(value, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ));
    }

    add(Icons.call, tr('Phone'), contact.phone, () => AppActions.launchExternal('call', contact.phone));
    add(Icons.chat, tr('WhatsApp'), contact.whatsapp, () => AppActions.launchExternal('whatsapp', contact.whatsapp));
    add(Icons.mail_outline, tr('Email'), contact.email, () => AppActions.launchExternal('email', contact.email));
    add(Icons.location_on_outlined, tr('Address'), contact.address,
        contact.mapUrl.isEmpty ? null : () => AppActions.launchExternal('external', contact.mapUrl));
    add(Icons.schedule, tr('Opening hours'), contact.hours, null);
    add(Icons.facebook, 'Facebook', contact.facebook.isEmpty ? '' : 'Facebook', () => AppActions.launchExternal('external', contact.facebook));
    add(Icons.camera_alt_outlined, 'Instagram', contact.instagram.isEmpty ? '' : 'Instagram', () => AppActions.launchExternal('external', contact.instagram));

    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(title!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          if (rows.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(tr('Contact details are not available yet.'))),
          ...rows,
          if (showFormButton && contact.formEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(tr('Send us a message')),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
              ),
            ),
        ],
      ),
    );
  }
}
