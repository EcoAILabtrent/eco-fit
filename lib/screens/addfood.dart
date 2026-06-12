import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'dish.dart';
import 'meallog.dart';

/// Добавление еды — port of foodscreens.jsx::AddFood, wired to the offline
/// product database (FoodDb / assets/foods.json, 1122 products).
class AddFoodScreen extends StatefulWidget {
  final String mealKey;
  final String? date; // null = today
  const AddFoodScreen({super.key, required this.mealKey, this.date});

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

  // No cap — the full database is shown and scrolled lazily.
  List<Product> get list => FoodDb.instance.search(query, recipesOnly: tab == 2, limit: 100000);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Bulk quick-add the checkbox-selected products at 100 г, then stay on the
  /// list (top-app pattern) so the user can keep adding.
  void _addSelected() {
    final store = context.read<AppStore>();
    var added = 0;
    for (final slug in sel) {
      final p = FoodDb.instance.bySlug(slug);
      if (p == null) continue;
      store.addFood(widget.mealKey, LogItem(p.name, p.kcal, protein: p.protein, carbs: p.carbs, fat: p.fat), date: widget.date);
      added++;
    }
    setState(() => sel.clear());
    _toast('Добавлено: $added');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: TextStyle(color: t.pill, fontWeight: FontWeight.w600)),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.dark,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final items = list;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final store = context.watch<AppStore>();
    final mealCount = store.itemsFor(widget.mealKey, date: widget.date).length;
    final mealKcal = store.mealKcal(widget.mealKey, date: widget.date);
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcoTopBar(t: t, title: meal.label, onBack: () => Navigator.of(context).pop()),

                // Search field
                Container(
                  height: 52,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(ecoIcon('search'), size: 20, color: t.dark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(hintText: 'Найти продукт', border: InputBorder.none, isDense: true),
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

                // Running total already in this meal — feedback as you add.
                if (mealCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 16, color: t.dark),
                      const SizedBox(width: 6),
                      Text('В приёме: $mealCount · $mealKcal ккал',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.dark)),
                    ]),
                  ),

                // Lazy, fully-scrollable product list filling the rest.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.r)),
                    clipBehavior: Clip.antiAlias,
                    child: (tab == 0)
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('Избранное появится после добавления продуктов',
                                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: EcoColors.sub)),
                            ),
                          )
                        : items.isEmpty
                            ? const Center(child: Text('Ничего не найдено', style: TextStyle(fontSize: 14, color: EcoColors.sub)))
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(18, 6, 18, 100 + bottomInset),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(height: 1.5, thickness: 1.5, color: t.bandSoft),
                                itemBuilder: (ctx, i) {
                                  final p = items[i];
                                  return _ProductRow(
                                    p: p,
                                    selected: sel.contains(p.slug),
                                    onToggle: () => setState(() => sel.contains(p.slug) ? sel.remove(p.slug) : sel.add(p.slug)),
                                    onOpen: () async {
                                      // Open portion detail; on add, return here
                                      // and keep adding (Yazio/Lifesum pattern).
                                      final added = await Navigator.of(context).push<String>(MaterialPageRoute(
                                        builder: (_) => DishScreen(product: p, mealKey: widget.mealKey, date: widget.date),
                                      ));
                                      if (added != null && mounted) _toast('«$added» добавлено');
                                    },
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pinned action buttons + fade so the list slides under them.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 86 + bottomInset,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg.withValues(alpha: 0), t.bg],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18 + bottomInset,
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
                bg: mealCount > 0 ? t.dark : t.band,
                fg: mealCount > 0 ? t.pill : t.dark,
                onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => MealLogScreen(mealKey: widget.mealKey, date: widget.date),
                )),
                child: Text(mealCount > 0 ? 'Готово · $mealCount' : 'Готово'),
              ),
            ),
          ]),
        ),
      ]),
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
        context.read<AppStore>().addFood(widget.mealKey, LogItem('Быстрое добавление', v), date: widget.date);
        _toast('Добавлено: $v ккал');
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
