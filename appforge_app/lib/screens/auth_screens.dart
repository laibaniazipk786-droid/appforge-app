import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().login(_user.text.trim(), _pass.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ConfigProvider>().settings;
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(24),
          children: [
            if (settings.logo.isNotEmpty) Center(child: NetImage(settings.logo, height: 56, fit: BoxFit.contain)),
            SizedBox(height: 16),
            Text(tr('Welcome back'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(tr('Sign in to {name}', {'name': settings.appName}), style: TextStyle(color: Colors.grey.shade600)),
            SizedBox(height: 28),
            TextFormField(
              controller: _user,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('Email or username'), prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('Required') : null,
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: tr('Password'),
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
              ),
              validator: (v) => (v ?? '').isEmpty ? tr('Required') : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ForgotPasswordScreen())),
                child: Text(tr('Forgot password?')),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(tr('Sign in')),
            ),
            if (settings.enableRegister) ...[
              SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(tr("Don't have an account?")),
                TextButton(
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RegisterScreen()));
                    if (ok == true && context.mounted) Navigator.of(context).pop(true);
                  },
                  child: Text(tr('Create one')),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().register(
            email: _email.text.trim(),
            password: _pass.text,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Create account'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(24),
          children: [
            Row(children: [
              Expanded(child: TextFormField(controller: _first, decoration: InputDecoration(labelText: tr('First name')))),
              SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _last, decoration: InputDecoration(labelText: tr('Last name')))),
            ]),
            SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('Email *'), prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : tr('Enter a valid email'),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('Password *'), prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) => (v ?? '').length < 6 ? tr('At least 6 characters') : null,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(tr('Create account')),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _login = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final msg = await Repo.forgot(_login.text.trim());
      if (!mounted) return;
      showSnack(context, msg);
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
      appBar: AppBar(title: Text(tr('Reset password'))),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Text(tr('Enter your email or username and we\'ll email you a link to reset your password.'), style: TextStyle(color: Colors.grey.shade700)),
          SizedBox(height: 20),
          TextField(controller: _login, decoration: InputDecoration(labelText: tr('Email or username'), prefixIcon: Icon(Icons.email_outlined))),
          SizedBox(height: 20),
          ElevatedButton(onPressed: _busy ? null : _submit, child: Text(tr('Send reset link'))),
        ],
      ),
    );
  }
}
