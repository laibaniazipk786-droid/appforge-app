import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';

import '../builder/block_renderer.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'search_screen.dart';

/// A screen designed in the WordPress builder (Home or any custom screen).
class BuilderScreen extends StatefulWidget {
  final String slug;
  final bool isTab;

  const BuilderScreen({super.key, required this.slug, this.isTab = false});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  int _generation = 0;

  Future<void> _refresh() async {
    await context.read<ConfigProvider>().refresh();
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final settings = config.settings;
    final screen = config.screen(widget.slug);
    final isHome = widget.slug == 'home';
    final cartCount = context.watch<CartProvider>().count;

    final ab = settings.appBar;
    final hasLogo = settings.logo.isNotEmpty;
    Widget logo() => NetImage(settings.logo, height: 32, fit: BoxFit.contain);
    Widget name(String t) => Text(t, overflow: TextOverflow.ellipsis);

    // App bar title — chosen in WordPress → AppForge → App bar.
    Widget title;
    if (!isHome) {
      title = name(screen?.title ?? '');
    } else {
      switch (ab.titleType) {
        case 'logo':
          title = hasLogo ? logo() : name(settings.appName);
          break;
        case 'name':
          title = name(settings.appName);
          break;
        case 'logo_name':
          title = Row(mainAxisSize: MainAxisSize.min, children: [
            if (hasLogo) ...[NetImage(settings.logo, height: 28, fit: BoxFit.contain), SizedBox(width: 8)],
            Flexible(child: name(settings.appName)),
          ]);
          break;
        case 'custom':
          title = name(ab.titleText.isNotEmpty ? ab.titleText : settings.appName);
          break;
        default:
          title = hasLogo ? logo() : name(settings.appName);
      }
    }
    final showSearchBar = isHome && ab.searchBar;

    return Scaffold(
      drawer: isHome && settings.drawer.enabled ? AppDrawer() : null,
      appBar: AppBar(
        title: title,
        centerTitle: ab.center,
        actions: [
          if (ab.showSearch && !showSearchBar)
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen())),
            ),
          if (ab.showAccount)
            IconButton(
              icon: Icon(Icons.person_outline),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen())),
            ),
          if (ab.showCart)
            IconButton(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: Icon(Icons.shopping_bag_outlined),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CartScreen())),
            ),
          SizedBox(width: 4),
        ],
        bottom: showSearchBar
            ? PreferredSize(
                preferredSize: Size.fromHeight(58),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen())),
                    child: Container(
                      height: 44,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text(ab.searchText, style: TextStyle(color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: screen == null
          ? MessageView(icon: Icons.layers_clear_outlined, title: tr('Screen not found'), subtitle: tr('It may have been deleted in the builder.'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  if (screen.blocks.isEmpty)
                    MessageView(icon: Icons.dashboard_customize_outlined, title: tr('This screen is empty'), subtitle: tr('Add blocks in WordPress → AppForge.')),
                  BlockList(key: ValueKey('${widget.slug}-$_generation-${config.config?.updatedAt}'), blocks: screen.blocks),
                ],
              ),
            ),
    );
  }
}
