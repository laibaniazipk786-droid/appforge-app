import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../providers/config_provider.dart';
import '../providers/prefs_provider.dart';

/// Language + light/dark mode.
class AppSettingsScreen extends StatelessWidget {
  final bool isTab;
  const AppSettingsScreen({super.key, this.isTab = false});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final prefs = context.watch<PrefsProvider>();
    final s = config.settings;
    final langs = config.config?.languages;
    final current = prefs.language(langs);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((langs?.list.length ?? 0) > 1)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text(tr('Language')),
                subtitle: Text(current.native),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLanguagePicker(context),
              ),
            ),
          if (s.allowThemeSwitch) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Appearance'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode_outlined), label: Text(tr('Light'))),
                      ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode_outlined), label: Text(tr('Dark'))),
                      ButtonSegment(value: 'system', icon: const Icon(Icons.phone_android), label: Text(tr('System'))),
                    ],
                    selected: {prefs.themeChoice(s)},
                    onSelectionChanged: (v) => prefs.setTheme(v.first),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet listing the languages enabled in WordPress → AppForge → Languages.
Future<void> showLanguagePicker(BuildContext context) async {
  final config = context.read<ConfigProvider>();
  final prefs = context.read<PrefsProvider>();
  final langs = config.config?.languages;
  if (langs == null) return;
  final current = prefs.language(langs).code;
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('Choose language'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          ...langs.list.map((l) => ListTile(
                title: Text(l.native),
                subtitle: l.native == l.name ? null : Text(l.name),
                trailing: l.code == current ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary) : null,
                onTap: () => Navigator.pop(ctx, l.code),
              )),
        ],
      ),
    ),
  );
  if (picked != null && picked != current) {
    await prefs.setLanguage(picked);
  }
}
