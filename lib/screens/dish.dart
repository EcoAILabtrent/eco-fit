import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Карточка блюда — port of foodscreens.jsx::Dish, showing the product's real
/// macros + micronutrients from the offline DB, scaled to the chosen portion.
class DishScreen extends StatefulWidget {
  final Product product;
  final String mealKey;
  final String? date; // null = today
  const DishScreen({
    super.key,
    required this.product,
    required this.mealKey,
    this.date,
  });

  @override
  State<DishScreen> createState() => _DishScreenState();
}

/// Micronutrient key → unit key. Labels are localized through AppStrings.
const _microUnits = {
  'protein': 'g',
  'fat': 'g',
  'carbs': 'g',
  'fe': 'mg',
  'mg': 'mg',
  'ca': 'mg',
  'p': 'mg',
  'k': 'mg',
  'na': 'mg',
  'zn': 'mg',
  'vit_c': 'mg',
  'vit_a': 'mcg',
  'vit_d': 'mcg',
};

class _DishScreenState extends State<DishScreen> {
  static const t = EcoTheme.meadow;
  late int grams = 100;

  Product get p => widget.product;
  double _scaled(num per100) => per100 * grams / 100;
  int get kcal => _scaled(p.kcal).round();

  Meal get meal => kMeals.firstWhere(
    (m) => m.key == widget.mealKey,
    orElse: () => kMeals[1],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Macro split for the bar (by calories of the scaled portion).
    final pKcal = _scaled(p.protein) * 4;
    final cKcal = _scaled(p.carbs) * 4;
    final fKcal = _scaled(p.fat) * 9;
    final totalKcal = (pKcal + cKcal + fKcal).clamp(1, double.infinity);
    final segs = [
      (
        pct: (cKcal / totalKcal * 100).round(),
        color: EcoColors.carb,
        label: l.nutrient('carbs'),
      ),
      (
        pct: (pKcal / totalKcal * 100).round(),
        color: EcoColors.prot,
        label: l.nutrient('protein'),
      ),
      (
        pct: (fKcal / totalKcal * 100).round(),
        color: EcoColors.fat,
        label: l.nutrient('fat'),
      ),
    ];

    // Nutrient rows: macros first, then micros from the DB.
    final rows = <({String label, String unit, double value})>[
      (
        label: l.nutrient('protein'),
        unit: l.unit('g'),
        value: _scaled(p.protein),
      ),
      (label: l.nutrient('fat'), unit: l.unit('g'), value: _scaled(p.fat)),
      (label: l.nutrient('carbs'), unit: l.unit('g'), value: _scaled(p.carbs)),
      for (final e in p.micros.entries)
        (
          label: l.nutrient(e.key),
          unit: l.unit(_microUnits[e.key] ?? 'mg'),
          value: _scaled(e.value),
        ),
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
            context.read<AppStore>().addFood(
              widget.mealKey,
              LogItem(
                p.name,
                kcal,
                protein: _scaled(p.protein),
                carbs: _scaled(p.carbs),
                fat: _scaled(p.fat),
                micros: p.microsForGrams(grams),
              ),
              date: widget.date,
            );
            // Return to the food list (keep adding); list shows confirmation.
            Navigator.of(context).pop(p.name);
          },
          child: Text(l.addToMeal(l.meal(meal.key))),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('food.dishes'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcoCard(
                  t: t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _DishVisual(product: p)),
                      const SizedBox(height: 14),
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.category.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            p.category,
                            style: const TextStyle(
                              fontSize: 13,
                              color: EcoColors.sub,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickPortion,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: t.band,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$kcal ${l.unit('kcal')}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: t.dark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$grams ${p.displayUnit(l.language)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: t.dark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          l.t('food.portionSize'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: EcoColors.sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('food.macronutrients'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final g in segs)
                            Padding(
                              padding: const EdgeInsets.only(right: 18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: g.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    g.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l.unit('kcal'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 16,
                          child: Row(
                            children: [
                              for (final g in segs)
                                if (g.pct > 0)
                                  Expanded(
                                    flex: g.pct,
                                    child: Container(color: g.color),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final g in segs)
                            if (g.pct > 0)
                              Expanded(
                                flex: g.pct,
                                child: Text(
                                  '${g.pct}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: EcoColors.sub,
                                  ),
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final (i, n) in rows.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1.5,
                            thickness: 1.5,
                            color: t.bandSoft,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${_fmt(n.value, l)} ${n.unit}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v, AppStrings l) {
    if (v >= 100) return v.round().toString();
    final decimal =
        l.language == AppLanguage.ru || l.language == AppLanguage.uzCyrl
        ? ','
        : '.';
    return v.toStringAsFixed(1).replaceAll('.', decimal);
  }

  void _pickPortion() {
    final l = context.l10nRead;
    final gramsValues = [for (var g = 10; g <= 1000; g += 5) g];
    var idx = gramsValues.indexOf(grams);
    if (idx < 0) idx = gramsValues.indexOf(100);
    final kcalCtrl = FixedExtentScrollController(initialItem: idx);
    final gramsCtrl = FixedExtentScrollController(initialItem: idx);
    var syncing = false;

    void sync(FixedExtentScrollController other, int i) {
      if (syncing) return;
      syncing = true;
      idx = i;
      if (other.hasClients) other.jumpToItem(i);
      syncing = false;
    }

    showEcoSheet(
      context: context,
      t: t,
      title: l.t('food.portionSize'),
      onDone: () => setState(() => grams = gramsValues[idx]),
      body: SizedBox(
        height: 130,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController: kcalCtrl,
                itemExtent: 44,
                onSelectedItemChanged: (i) => sync(gramsCtrl, i),
                children: [
                  for (final g in gramsValues)
                    Center(
                      child: Text(
                        '${(g * p.kcal / 100).round()} ${l.unit('kcal')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                    Center(
                      child: Text(
                        '$g ${p.displayUnit(l.language)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishVisual extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final Product product;

  const _DishVisual({required this.product});

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imageAssetPath;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: t.bandSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imagePath != null
          ? Image.asset(
              imagePath,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final emoji = product.emoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Text(emoji, style: const TextStyle(fontSize: 44));
    }
    return Icon(
      product.isDrink ? Icons.local_drink_outlined : Icons.restaurant_menu,
      size: 44,
      color: t.dark,
    );
  }
}
