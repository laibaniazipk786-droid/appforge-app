import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';

import '../models/models.dart';
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
      body = ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (_history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('Recent searches'), style: TextStyle(fontWeight: FontWeight.w600)),
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
              children: _history
                  .map((h) => ActionChip(
                        label: Text(h),
                        onPressed: () {
                          _controller.text = h;
                          _search(h, save: true);
                        },
                      ))
                  .toList(),
            ),
          ] else
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
