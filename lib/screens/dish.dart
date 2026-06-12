import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Карточка блюда — port of foodscreens.jsx::Dish.
class DishScreen extends StatefulWidget {
  final Product product;
  final String mealKey;
  const DishScreen({super.key, required this.product, required this.mealKey});

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  static const t = EcoTheme.meadow;
  late int grams = 120;

  int get kcal => (grams * widget.product.kcal / 100).round();

  Meal get meal => kMeals.firstWhere((m) => m.key == widget.mealKey, orElse: () => kMeals[1]);

  @override
  Widget build(BuildContext context) {
    const segs = [
      (pct: 50, color: EcoColors.carb, label: 'Углеводы'),
      (pct: 37, color: EcoColors.prot, label: 'Белки'),
      (pct: 13, color: EcoColors.fat, label: 'Жиры'),
    ];
    const nutrients = [
      (pct: '8%', label: 'Жиры', val: '5,6 г'),
      (pct: '6%', label: 'Углеводы', val: '4 г'),
      (pct: '5,5%', label: 'Витамин C', val: '3,2 г'),
      (pct: '23%', label: 'Белки', val: '43 г'),
      (pct: '1,2%', label: 'Кальций', val: '1 г'),
      (pct: '3%', label: 'Железо', val: '2,3 г'),
    ];

    return EcoScreen(
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(
          t: t,
          onTap: () {
            context.read<AppStore>().addFood(widget.mealKey, LogItem(widget.product.name, kcal));
            Navigator.of(context).pushReplacementNamed('/meallog', arguments: widget.mealKey);
          },
          child: Text('Добавить в «${meal.label}»'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(t: t, title: 'Блюда', onBack: () => Navigator.of(context).pop()),
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Порция
              EcoCard(
                t: t,
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.product.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickPortion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(color: t.band, borderRadius: BorderRadius.circular(999)),
                      child: Row(children: [
                        Expanded(
                          child: Text('$kcal ккал',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.dark)),
                        ),
                        Expanded(
                          child: Text('$grams г',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.dark)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Размер порции', style: TextStyle(fontSize: 13, color: EcoColors.sub)),
                  ),
                ]),
              ),

              // Макронутриенты
              EcoCard(
                t: t,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Макронутриенты', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final g in segs)
                      Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Row(children: [
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: g.color, shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          Text(g.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 18),
                  const Text('Ккал', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 16,
                      child: Row(children: [
                        for (final g in segs) Expanded(flex: g.pct, child: Container(color: g.color)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final g in segs)
                      Expanded(
                        flex: g.pct,
                        child: Text('${g.pct}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EcoColors.sub)),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  for (final (i, n) in nutrients.indexed) ...[
                    if (i > 0) Divider(height: 1.5, thickness: 1.5, color: t.bandSoft),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: t.pill, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: Text(n.pct, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.dark)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(n.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        Text(n.val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Two synced wheels: kcal (derived) and grams — as in the design's
  /// PortionPicker, both driven by the grams value.
  void _pickPortion() {
    final gramsValues = [for (var g = 10; g <= 500; g += 5) g];
    var idx = gramsValues.indexOf(grams).clamp(0, gramsValues.length - 1);
    final kcalCtrl = FixedExtentScrollController(initialItem: idx);
    final gramsCtrl = FixedExtentScrollController(initialItem: idx);
    var syncing = false;

    void sync(FixedExtentScrollController other, int i) {
      if (syncing) return;
      syncing = true;
      idx = i;
      other.jumpToItem(i);
      syncing = false;
    }

    showEcoSheet(
      context: context,
      t: t,
      title: 'Размер порции',
      onDone: () => setState(() => grams = gramsValues[idx]),
      body: SizedBox(
        height: 130,
        child: Row(children: [
          Expanded(
            child: CupertinoPicker(
              scrollController: kcalCtrl,
              itemExtent: 44,
              onSelectedItemChanged: (i) => sync(gramsCtrl, i),
              children: [
                for (final g in gramsValues)
                  Center(
                    child: Text('${(g * widget.product.kcal / 100).round()} ккал',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController: gramsCtrl,
              itemExtent: 44,
              onSelectedItemChanged: (i) => sync(kcalCtrl, i),
              children: [
                for (final g in gramsValues)
                  Center(child: Text('$g г', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
