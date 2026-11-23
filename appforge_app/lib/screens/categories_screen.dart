import 'package:flutter/material.dart';

import '../core/i18n.dart';

import '../models/models.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import 'product_list_screen.dart';

/// Two-pane category browser: parents on the left, children on the right.
class CategoriesScreen extends StatefulWidget {
  final bool isTab;
  const CategoriesScreen({super.key, this.isTab = false});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _future = Repo.categories();
  int _selected = 0;

  void _open(Category c) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(title: c.name, categoryId: c.id)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Categories'))),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return LoadingView();
          if (snap.hasError) {
            return MessageView.error(snap.error, title: tr('Could not load categories'), onRetry: () => setState(() => _future = Repo.categories()));
          }
          final all = snap.data ?? <Category>[];
          final parents = all.where((c) => c.parent == 0).toList();
          if (parents.isEmpty) return MessageView(icon: Icons.category_outlined, title: tr('No categories yet'));
          if (_selected >= parents.length) _selected = 0;
          final current = parents[_selected];
          final children = all.where((c) => c.parent == current.id).toList();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 110,
                color: theme.colorScheme.surface,
                child: ListView.builder(
                  itemCount: parents.length,
                  itemBuilder: (_, i) {
                    final active = i == _selected;
                    return InkWell(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                        decoration: BoxDecoration(
                          color: active ? theme.scaffoldBackgroundColor : null,
                          border: Border(left: BorderSide(color: active ? theme.colorScheme.primary : Colors.transparent, width: 3)),
                        ),
                        child: Text(
                          parents[i].name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? theme.colorScheme.primary : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    GestureDetector(
                      onTap: () => _open(current),
                      child: Stack(
                        children: [
                          NetImage(current.image, height: 110, width: double.infinity, radius: BorderRadius.circular(12)),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: [Colors.black.withOpacity(0.55), Colors.transparent]),
                              ),
                              padding: EdgeInsets.all(16),
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(current.name, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                                  Text(tr('{n} products · Shop all', {'n': current.count}), style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    if (children.isNotEmpty)
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.78,
                        children: children
                            .map((c) => InkWell(
                                  onTap: () => _open(c),
                                  child: Column(children: [
                                    AspectRatio(aspectRatio: 1, child: NetImage(c.image, radius: BorderRadius.circular(12))),
                                    SizedBox(height: 6),
                                    Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                                  ]),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
