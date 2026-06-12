import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'dish.dart';

/// Добавление еды — port of foodscreens.jsx::AddFood, wired to the offline
/// product database (FoodDb / assets/foods.json, 1122 products).
class AddFoodScreen extends StatefulWidget {
  final String mealKey;
  const AddFoodScreen({super.key, required this.mealKey});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  static const t = EcoTheme.meadow;
  int tab = 1; // 0 favourites · 1 all products · 2 dishes (recipes)
  final sel = <String>{}; // selected slugs
  String query = '';
  final _searchCtrl = TextEditingController();

  Meal get meal => kMeals.firstWhere((m) => m.key == widget.mealKey, orElse: () => kMeals.first);

  List<Product> get list => FoodDb.instance.search(query, recipesOnly: tab == 2, limit: 80);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addSelected() {
    final store = context.read<AppStore>();
    for (final slug in sel) {
      final p = FoodDb.instance.bySlug(slug);
      if (p == null) continue;
      // Default portion = 100 г (matches "ккал/100 г" shown in the row).
      store.addFood(widget.mealKey, LogItem(p.name, p.kcal, protein: p.protein, carbs: p.carbs, fat: p.fat));
    }
    Navigator.of(context).pushReplacementNamed('/meallog', arguments: widget.mealKey);
  }

  @override
  Widget build(BuildContext context) {
    final items = list;
    return EcoScreen(
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: Row(children: [
          Expanded(
            child: EcoBtn(
              t: t,
              disabled: sel.isEmpty,
              onTap: _addSelected,
              child: Text(sel.isNotEmpty ? 'Добавить · ${sel.length}' : 'Добавить'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: EcoBtn(
              t: t,
              bg: t.band,
              fg: t.dark,
              onTap: () => Navigator.of(context).pushReplacementNamed('/meallog', arguments: widget.mealKey),
              child: const Text('Следующая'),
            ),
          ),
        ]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(t: t, title: meal.label, onBack: () => Navigator.of(context).pop()),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Search field
              Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(ecoIcon('search'), size: 20, color: t.dark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        hintText: 'Найти продукт',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => query = '');
                      },
                      child: Icon(Icons.close, size: 18, color: t.dark),
                    ),
                ]),
              ),

              // Quick "Добавить калории"
              GestureDetector(
                onTap: _quickKcal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(ecoIcon('cutlery'), size: 18, color: t.dark),
                    const SizedBox(width: 8),
                    Text('Добавить калории вручную', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.dark)),
                  ]),
                ),
              ),

              FolderTabs(
                t: t,
                tabs: const ['Избранное', 'Все продукты', 'Блюда'],
                active: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
              EcoCard(
                t: t,
                pad: 18,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 320),
                  child: Column(children: [
                    if (tab == 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Избранное появится после добавления продуктов',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: EcoColors.sub)),
                      )
                    else if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Ничего не найдено', style: TextStyle(fontSize: 14, color: EcoColors.sub)),
                      )
                    else
                      for (final (i, p) in items.indexed) ...[
                        if (i > 0) Divider(height: 1.5, thickness: 1.5, color: t.bandSoft),
                        _ProductRow(
                          p: p,
                          selected: sel.contains(p.slug),
                          onToggle: () => setState(() => sel.contains(p.slug) ? sel.remove(p.slug) : sel.add(p.slug)),
                          onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DishScreen(product: p, mealKey: widget.mealKey),
                          )),
                        ),
                      ],
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _quickKcal() {
    var v = 210;
    final values = [for (var i = 10; i <= 1500; i += 10) i];
    showEcoSheet(
      context: context,
      t: t,
      title: 'Добавить калории',
      onDone: () {
        context.read<AppStore>().addFood(widget.mealKey, LogItem('Быстрое добавление', v));
        Navigator.of(context).pushReplacementNamed('/meallog', arguments: widget.mealKey);
      },
      body: SizedBox(
        height: 130,
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: values.indexOf(210)),
          itemExtent: 44,
          onSelectedItemChanged: (i) => v = values[i],
          children: [
            for (final n in values)
              Center(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$n', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                  const TextSpan(text: '  ккал', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final Product p;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ProductRow({required this.p, required this.selected, required this.onToggle, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: selected ? t.dark : t.bandSoft, shape: BoxShape.circle),
            child: selected ? Icon(Icons.check, size: 14, color: t.pill) : null,
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 2, height: 34, color: t.olive.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(p.category, style: const TextStyle(fontSize: 12.5, color: EcoColors.sub)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${p.kcal}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('ккал/100 г', style: TextStyle(fontSize: 10, color: EcoColors.sub)),
        ]),
      ]),
    );
  }
}
