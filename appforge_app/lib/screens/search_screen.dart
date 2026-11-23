import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';

import '../models/models.dart';
import '../providers/config_provider.dart';
import '../services/repository.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  final bool isTab;
  const SearchScreen({super.key, this.isTab = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _historyKey = 'appforge_search_history';
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  List<String> _history = [];
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _history = p.getStringList(_historyKey) ?? []);
    });
  }

  @override
  void dispose() {
    // Remember what the customer searched for even if they did not press "search".
    if (_query.length >= 2 && _results.isNotEmpty && !_history.contains(_query)) {
      final list = [_query, ..._history].take(10).toList();
      SharedPreferences.getInstance().then((p) => p.setStringList(_historyKey, list));
    }
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value, {bool save = false}) async {
    final q = value.trim();
    setState(() => _query = q);
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await Repo.products(search: q, perPage: 20);
      if (!mounted || q != _query) return;
      setState(() => _results = res.items);
      if (save) _saveHistory(q);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveHistory(String q) async {
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 10) _history = _history.sublist(0, 10);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_historyKey, _history);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_query.length < 2) {
      final cfg = context.watch<ConfigProvider>().settings.search;
      final history = cfg.showRecent ? _history : const <String>[];
      final trending = cfg.showTrending ? cfg.trending : const <String>[];
      final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
      void run(String q) {
        _controller.text = q;
        _controller.selection = TextSelection.collapsed(offset: q.length);
        _search(q, save: true);
      }

      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [const Icon(Icons.history, size: 18), const SizedBox(width: 6), Text(tr('Recent searches'), style: titleStyle)]),
                TextButton(
                  onPressed: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.remove(_historyKey);
                    setState(() => _history = []);
                  },
                  child: Text(tr('Clear')),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history
                  .map((h) => InputChip(
                        label: Text(h),
                        onPressed: () => run(h),
                        onDeleted: () async {
                          setState(() => _history.remove(h));
                          final p = await SharedPreferences.getInstance();
                          await p.setStringList(_historyKey, _history);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (trending.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.trending_up, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(tr('Trending searches'), style: titleStyle),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trending
                  .map((t) => ActionChip(
                        avatar: Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade700),
                        label: Text(t),
                        onPressed: () => run(t),
                      ))
                  .toList(),
            ),
          ],
          if (history.isEmpty && trending.isEmpty)
            MessageView(icon: Icons.search, title: tr('Search the store'), subtitle: tr('Type at least 2 characters')),
        ],
      );
    } else if (_loading && _results.isEmpty) {
      body = LoadingView();
    } else if (_results.isEmpty) {
      body = MessageView(icon: Icons.search_off, title: tr('No results for "{q}"', {'q': _query}));
    } else {
      body = ListView(padding: EdgeInsets.all(16), children: [ProductGrid(products: _results)]);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: widget.isTab ? 16 : 0,
        title: TextField(
          controller: _controller,
          autofocus: !widget.isTab,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) => _search(v, save: true),
          decoration: InputDecoration(
            hintText: tr('Search products...'),
            prefixIcon: Icon(Icons.search),
            isDense: true,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
          ),
        ),
      ),
      body: body,
    );
  }
}
