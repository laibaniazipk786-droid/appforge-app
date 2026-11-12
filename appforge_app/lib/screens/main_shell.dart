import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../builder/actions.dart';
import '../core/i18n.dart';
import '../core/icons.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';

/// Bottom navigation built from the "Navigation" tab of the WordPress builder.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final Map<String, Widget> _pages = {};

  String _keyFor(NavItem item) => '${item.action.type}:${item.action.value}';

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    var nav = config.settings.bottomNav;
    if (nav.length < 2) {
      // Fallback so the app is always usable.
      nav = [
        NavItem(label: tr('Home'), icon: 'home', action: const ActionData(type: 'screen', value: 'home')),
        NavItem(label: tr('Cart'), icon: 'cart', action: const ActionData(type: 'route', value: 'cart')),
      ];
    }
    if (_index >= nav.length) _index = 0;

    final cartCount = context.watch<CartProvider>().count;
    final children = nav.map((item) {
      final key = _keyFor(item);
      return _pages.putIfAbsent(key, () => AppActions.pageFor(item.action, asTab: true, title: item.label));
    }).toList();

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: children),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          height: config.settings.navLabels == 'none' ? 58 : 66,
          labelBehavior: switch (config.settings.navLabels) {
            'none' => NavigationDestinationLabelBehavior.alwaysHide,
            'selected' => NavigationDestinationLabelBehavior.onlyShowSelected,
            _ => NavigationDestinationLabelBehavior.alwaysShow,
          },
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: nav.map((item) {
            final isCart = item.action.type == 'route' && item.action.value == 'cart';
            Widget icon(bool selected) {
              final i = Icon(iconFor(item.icon, selected: selected));
              return isCart && cartCount > 0 ? Badge(label: Text('$cartCount'), child: i) : i;
            }

            return NavigationDestination(icon: icon(false), selectedIcon: icon(true), label: tr(item.label));
          }).toList(),
        ),
      ),
    );
  }
}
