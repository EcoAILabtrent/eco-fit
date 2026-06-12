import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'dish.dart';

/// Добавление еды в приём — port of foodscreens.jsx::AddFood.
class AddFoodScreen extends StatefulWidget {
  final String mealKey;
  const AddFoodScreen({super.key, required this.mealKey});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  static const t = EcoTheme.meadow;
  int tab = 1;
  final sel = <String>{};
  String query = '';

  Meal get meal => kMeals.firstWhere((m) => m.key == widget.mealKey, orElse: () => kMeals.first);

  List<Product> get list {
    var base = switch (tab) {
      0 => kProducts.where((p) => p.fav),
      2 => kProducts.where((p) => p.name.contains('Салат') || p.kcal > 150),
      _ => kProducts,
    };
    if (query.isNotEmpty) {
      base = base.where((p) => p.name.toLowerCase().contains(query.toLowerCase()));
    }
    return base.toList();
  }

  void _addSelected() {
    final store = context.read<AppStore>();
    for (final p in kProducts.where((p) => sel.contains(p.name))) {
      store.addFood(widget.mealKey, LogItem(p.name, p.kcal));
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
              // Способ записи
              EcoCard(
                t: t,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(children: [
                  const Text('Выберите способ записи еды',
                      style: TextStyle(fontSize: 14, color: EcoColors.sub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _MethodBtn(icon: 'search', label: 'Найти продукт', active: query.isNotEmpty, onTap: _search),
                    _MethodBtn(icon: 'food', label: 'Добавить калории', onTap: _quickKcal),
                  ]),
                ]),
              ),

              FolderTabs(
                t: t,
                tabs: const ['Избранное', 'Мои продукты', 'Мои блюда'],
                active: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
              EcoCard(
                t: t,
                pad: 18,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 320),
                  child: Column(children: [
                    if (query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text('Поиск: «$query»',
                                style: const TextStyle(fontSize: 13, color: EcoColors.sub, fontWeight: FontWeight.w600)),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => query = ''),
                            child: Icon(Icons.close, size: 18, color: t.dark),
                          ),
                        ]),
                      ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Ничего не найдено', style: TextStyle(fontSize: 14, color: EcoColors.sub)),
                      ),
                    for (final (i, p) in items.indexed) ...[
                      if (i > 0) Divider(height: 1.5, thickness: 1.5, color: t.bandSoft),
                      _ProductRow(
                        p: p,
                        selected: sel.contains(p.name),
                        onToggle: () => setState(() => sel.contains(p.name) ? sel.remove(p.name) : sel.add(p.name)),
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

  Future<void> _search() async {
    final c = TextEditingController(text: query);
    final result = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.r)),
        title: const Text('Найти продукт', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название продукта'),
          onSubmitted: (v) => Navigator.of(dCtx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(''), child: const Text('Сброс')),
          TextButton(onPressed: () => Navigator.of(dCtx).pop(c.text), child: const Text('Искать')),
        ],
      ),
    );
    if (result != null) setState(() => query = result);
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

class _MethodBtn extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MethodBtn({required this.icon, required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: active ? t.olive : t.dark, shape: BoxShape.circle),
            child: Icon(ecoIcon(icon), size: 24, color: t.pill),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
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
              Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(p.desc, style: const TextStyle(fontSize: 12.5, color: EcoColors.sub)),
            ]),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${p.kcal}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('ккал/100 г', style: TextStyle(fontSize: 10, color: EcoColors.sub)),
        ]),
      ]),
    );
  }
}
