import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repository.dart';
import 'common.dart';

/// Opens the filter sheet. Returns the new filter, or null when dismissed.
Future<ProductFilter?> showFilterSheet(BuildContext context, {required ProductFilter current, int? categoryId}) {
  return showModalBottomSheet<ProductFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: current.copy(), categoryId: categoryId),
  );
}

class _FilterSheet extends StatefulWidget {
  final ProductFilter initial;
  final int? categoryId;
  const _FilterSheet({required this.initial, this.categoryId});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilter f = widget.initial;
  late final Future<FilterOptions> _options = Repo.filterOptions(category: (widget.categoryId ?? 0) > 0 ? widget.categoryId : null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => FutureBuilder<FilterOptions>(
        future: _options,
        builder: (context, snap) {
          final opt = snap.data;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(children: [
                Expanded(child: Text(tr('Filter'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => setState(() => f = ProductFilter()), child: Text(tr('Clear all'))),
              ]),
            ),
            Expanded(
              child: snap.connectionState != ConnectionState.done
                  ? const LoadingView()
                  : ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                      if (opt?.minPrice != null && opt?.maxPrice != null && opt!.maxPrice! > opt.minPrice!) _price(opt),
                      _section(tr('Availability')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('On sale')),
                        value: f.onSale,
                        onChanged: (v) => setState(() => f.onSale = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('In stock only')),
                        value: f.inStock,
                        onChanged: (v) => setState(() => f.inStock = v),
                      ),
                      _section(tr('Rating')),
                      Wrap(spacing: 8, children: [
                        for (final r in [4, 3, 2])
                          ChoiceChip(
                            avatar: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                            label: Text(tr('{n} & up', {'n': r})),
                            selected: f.rating == r,
                            onSelected: (sel) => setState(() => f.rating = sel ? r : 0),
                          ),
                      ]),
                      ...?opt?.attributes.map(_attribute),
                    ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, f),
                    child: Text(f.activeCount > 0 ? tr('Show results ({n} filters)', {'n': f.activeCount}) : tr('Show results')),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  Widget _price(FilterOptions opt) {
    final lo = opt.minPrice!, hi = opt.maxPrice!;
    final values = RangeValues((f.minPrice ?? lo).clamp(lo, hi).toDouble(), (f.maxPrice ?? hi).clamp(lo, hi).toDouble());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(tr('Price')),
      Row(children: [
        Text(Money.format(values.start), style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(Money.format(values.end), style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      RangeSlider(
        min: lo,
        max: hi,
        divisions: (hi - lo) > 100 ? 100 : null,
        values: values,
        onChanged: (v) => setState(() {
          f.minPrice = v.start <= lo ? null : v.start;
          f.maxPrice = v.end >= hi ? null : v.end;
        }),
      ),
    ]);
  }

  Widget _attribute(FilterAttribute a) {
    final selected = f.terms[a.taxonomy] ?? <String>{};
    void toggle(String slug) => setState(() {
          final set = f.terms.putIfAbsent(a.taxonomy, () => <String>{});
          set.contains(slug) ? set.remove(slug) : set.add(slug);
        });
    final isColor = a.terms.every((t) => t.color.isNotEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(a.name),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: a.terms.map((t) {
          final on = selected.contains(t.slug);
          if (isColor) {
            return Tooltip(
              message: '${t.name} (${t.count})',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => toggle(t.slug),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: on ? Theme.of(context).colorScheme.primary : AppColors.of(context).border, width: on ? 2.2 : 1),
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: hexColor(t.color),
                    child: on ? Icon(Icons.check, size: 16, color: hexColor(t.color).computeLuminance() > 0.6 ? Colors.black : Colors.white) : null,
                  ),
                ),
              ),
            );
          }
          return FilterChip(label: Text('${t.name} (${t.count})'), selected: on, onSelected: (_) => toggle(t.slug));
        }).toList(),
      ),
    ]);
  }
}
