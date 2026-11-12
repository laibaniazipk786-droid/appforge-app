import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../builder/actions.dart';
import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../providers/prefs_provider.dart';
import '../screens/account_screen.dart';
import '../screens/app_settings_screen.dart';
import '../screens/auth_screens.dart';
import '../screens/product_list_screen.dart';
import '../services/repository.dart';
import 'common.dart';

/// Sidebar built from WordPress → AppForge → Menus → Sidebar.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static Future<List<Category>>? _categories;

  @override
  void initState() {
    super.initState();
    final dr = context.read<ConfigProvider>().settings.drawer;
    if (dr.showCategories) {
      _categories ??= Repo.categories(parent: 0, limit: dr.categoriesLimit);
    }
  }

  void _go(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<PrefsProvider>();
    final s = config.settings;
    final dr = s.drawer;
    final theme = Theme.of(context);
    final user = auth.user;
    final isDark = theme.brightness == Brightness.dark;
    final langs = config.config?.languages;

    // ---- header
    final onHeader = dr.headerStyle == 'plain' ? theme.colorScheme.onSurface : (dr.headerStyle == 'image' ? Colors.white : AppColors.of(context).onPrimary);
    final header = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
      decoration: BoxDecoration(
        color: dr.headerStyle == 'primary' ? theme.colorScheme.primary : (dr.headerStyle == 'plain' ? theme.colorScheme.surface : Colors.black),
        image: dr.headerStyle == 'image' && dr.headerImage.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(dr.headerImage),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.logo.isNotEmpty)
            NetImage(s.logo, height: 34, fit: BoxFit.contain)
          else
            Text(s.appName, style: TextStyle(color: onHeader, fontSize: 20, fontWeight: FontWeight.w800)),
          if (dr.showLogin) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: () => _go(user == null ? const LoginScreen() : const AccountScreen()),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: onHeader.withOpacity(0.2),
                  backgroundImage: user != null && user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                  child: user == null ? Icon(Icons.person, color: onHeader) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      user == null ? tr('Hello, guest') : tr('Hi, {name}', {'name': user.firstName.isNotEmpty ? user.firstName : user.name}),
                      style: TextStyle(color: onHeader, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      user == null ? tr('Login / Sign up') : tr('My account'),
                      style: TextStyle(color: onHeader.withOpacity(0.8), fontSize: 12),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right, color: onHeader.withOpacity(0.8)),
              ]),
            ),
          ],
        ],
      ),
    );

    Widget tile(IconData icon, String label, VoidCallback onTap, {Widget? trailing, Color? iconColor}) => ListTile(
          leading: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.75)),
          title: Text(label),
          trailing: trailing,
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          onTap: onTap,
        );

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
          child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: theme.colorScheme.onSurface.withOpacity(0.55))),
        );

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                ...dr.items.map((item) => tile(iconFor(item.icon), tr(item.label), () {
                      Navigator.of(context).pop();
                      AppActions.open(context, item.action, title: tr(item.label));
                    })),
                if (dr.showCategories) ...[
                  const Divider(),
                  sectionTitle(tr(dr.categoriesTitle)),
                  FutureBuilder<List<Category>>(
                    future: _categories,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
                      }
                      final cats = snap.data ?? const <Category>[];
                      return Column(
                        children: cats.map((c) {
                          final color = hexColor(c.iconColor, theme.colorScheme.primary);
                          Widget leading;
                          if (c.icon.isNotEmpty && hasIcon(c.icon)) {
                            leading = Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Icon(iconFor(c.icon, selected: true), size: 20, color: color),
                            );
                          } else if (c.image.isNotEmpty) {
                            leading = NetImage(c.image, width: 34, height: 34, radius: BorderRadius.circular(10));
                          } else {
                            leading = Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                            );
                          }
                          return ListTile(
                            leading: leading,
                            title: Text(c.name),
                            dense: true,
                            trailing: Text('${c.count}', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.45), fontSize: 12)),
                            onTap: () => _go(ProductListScreen(title: c.name, categoryId: c.id)),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                if ((dr.showLanguage && (langs?.list.length ?? 0) > 1) || (dr.showThemeToggle && s.allowThemeSwitch)) const Divider(),
                if (dr.showLanguage && (langs?.list.length ?? 0) > 1)
                  tile(Icons.language, tr('Language'), () => showLanguagePicker(context), trailing: Text(prefs.language(langs).native)),
                if (dr.showThemeToggle && s.allowThemeSwitch)
                  SwitchListTile(
                    secondary: Icon(Icons.dark_mode_outlined, color: theme.colorScheme.onSurface.withOpacity(0.75)),
                    title: Text(tr('Dark mode')),
                    dense: true,
                    value: isDark,
                    onChanged: (v) => prefs.setTheme(v ? 'dark' : 'light'),
                  ),
                if (user != null) tile(Icons.logout, tr('Sign out'), () => auth.logout()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
