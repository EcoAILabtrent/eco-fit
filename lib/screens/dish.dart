import 'dart:math' as math;
import 'dart:ui' as ui;

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
  final int? initialGrams;
  const DishScreen({
    super.key,
    required this.product,
    required this.mealKey,
    this.date,
    this.initialGrams,
  });

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class DishSelectionResult {
  final Product product;
  final int grams;

  const DishSelectionResult({required this.product, required this.grams});

  LogItem toLogItem() {
    double scaled(num per100) => per100 * grams / 100;
    return LogItem(
      product.name,
      scaled(product.kcal).round(),
      protein: scaled(product.protein),
      carbs: scaled(product.carbs),
      fat: scaled(product.fat),
      micros: product.microsForGrams(grams),
      productSlug: product.slug,
      grams: grams,
    );
  }
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

const _heroPillHeight = 42.0;

class _DishScreenState extends State<DishScreen> {
  static const t = EcoTheme.meadow;
  late int grams = 100;
  late final int _initialGrams;

  Product get p => widget.product;
  double _scaled(num per100) => per100 * grams / 100;
  int get kcal => _scaled(p.kcal).round();

  Meal get meal => kMeals.firstWhere(
        (m) => m.key == widget.mealKey,
        orElse: () => kMeals[1],
      );

  @override
  void initState() {
    super.initState();
    _initialGrams = (widget.initialGrams ?? 100).clamp(10, 1000).toInt();
    grams = _initialGrams;
  }

  bool get _hasPortionChanges => grams != _initialGrams;

  void _cancelOrResetPortion() {
    if (_hasPortionChanges) {
      setState(() => grams = _initialGrams);
      return;
    }
    Navigator.of(context).pop();
  }

  void _savePortion() {
    Navigator.of(context).pop(
      DishSelectionResult(product: p, grams: grams),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = context.watch<AppStore>();
    final isFavorite = store.isFavoriteProduct(p.slug);
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
    final activeSegs = segs.where((g) => g.pct > 0).toList();

    // Nutrient rows: macros first, then micros from the DB.
    final rows = <({
      String key,
      String label,
      String unit,
      double value,
      int? pct,
      Color? color,
    })>[
      (
        key: 'protein',
        label: l.nutrient('protein'),
        unit: l.unit('g'),
        value: _scaled(p.protein),
        pct: segs[1].pct,
        color: segs[1].color,
      ),
      (
        key: 'fat',
        label: l.nutrient('fat'),
        unit: l.unit('g'),
        value: _scaled(p.fat),
        pct: segs[2].pct,
        color: segs[2].color,
      ),
      (
        key: 'carbs',
        label: l.nutrient('carbs'),
        unit: l.unit('g'),
        value: _scaled(p.carbs),
        pct: segs[0].pct,
        color: segs[0].color,
      ),
      for (final e in p.micros.entries)
        (
          key: e.key,
          label: l.nutrient(e.key),
          unit: l.unit(_microUnits[e.key] ?? 'mg'),
          value: _scaled(e.value),
          pct: null,
          color: _nutrientColor(e.key),
        ),
    ];

    return EcoScreen(
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: Row(
          children: [
            Expanded(
              child: EcoBtn(
                t: t,
                bg: t.dark,
                fg: t.pill,
                onTap: _cancelOrResetPortion,
                child: Text(
                  l.t('common.cancel'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EcoBtn(
                t: t,
                onTap: _savePortion,
                child: Text(
                  l.t('common.save'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
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
            padding: const EdgeInsets.only(bottom: 106),
            child: EcoGlassSurface(
              t: t,
              padding: EdgeInsets.zero,
              bg: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(26),
              shadows: const [
                BoxShadow(
                  color: Color(0x3A000000),
                  blurRadius: 24,
                  offset: Offset(6, 12),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DishHero(
                    product: p,
                    title: p.name,
                    selected: isFavorite,
                    tooltip: l.t(
                      isFavorite ? 'food.removeFavorite' : 'food.addFavorite',
                    ),
                    onFavorite: () => store.toggleFavoriteProduct(p.slug),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 288),
                            child: GestureDetector(
                              onTap: _pickPortion,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: t.bandSoft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.44),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$kcal ${l.unit('kcal')}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: t.dark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '$grams ${p.displayUnit(l.language)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: t.dark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            l.t('food.portionSize'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: EcoColors.sub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.t('food.macronutrients'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: t.track,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              if (activeSegs.isEmpty)
                                Expanded(
                                  child: Container(color: Colors.transparent),
                                )
                              else
                                for (final g in activeSegs)
                                  Expanded(
                                    flex: g.pct,
                                    child: Container(color: g.color),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MacroPercentLabels(segments: activeSegs),
                        const SizedBox(height: 14),
                        for (final (i, n) in rows.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1.5,
                              thickness: 1.5,
                              color: t.olive.withValues(alpha: 0.42),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              children: [
                                _NutrientBadge(
                                  t: t,
                                  percent: n.pct,
                                  label: n.pct == null
                                      ? _nutrientBadgeLabel(n.key)
                                      : null,
                                  color: n.color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    n.label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_fmt(n.value, l)} ${n.unit}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
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

  static String _nutrientBadgeLabel(String key) => switch (key) {
        'protein' => 'P',
        'fat' => 'F',
        'carbs' => 'C',
        'fe' => 'Fe',
        'mg' => 'Mg',
        'ca' => 'Ca',
        'p' => 'P',
        'k' => 'K',
        'na' => 'Na',
        'zn' => 'Zn',
        'vit_c' => 'C',
        'vit_a' => 'A',
        'vit_d' => 'D',
        _ => key.isEmpty ? '' : key.substring(0, 1).toUpperCase(),
      };

  static Color _nutrientColor(String key) => switch (key) {
        'fe' => const Color(0xFFB85B3C),
        'mg' => const Color(0xFF4F8F7A),
        'ca' => const Color(0xFF5E86B8),
        'p' => const Color(0xFF8A6FB4),
        'k' => const Color(0xFF54A866),
        'na' => const Color(0xFFB59349),
        'zn' => const Color(0xFF6A8A90),
        'vit_c' => const Color(0xFF3F9E74),
        'vit_a' => const Color(0xFFE08B3E),
        'vit_d' => const Color(0xFF7A77C8),
        _ => const Color(0xFF6D8B7B),
      };

  void _pickPortion() {
    final l = context.l10nRead;
    final gramsValues = [for (var g = 10; g <= 1000; g += 5) g];
    final standardValues =
        p.isDrink ? const [200, 300, 400] : const [100, 150, 200];
    final standardLabels = _portionStandardLabels(l.language);
    var idx = gramsValues.indexOf(grams);
    if (idx < 0) idx = gramsValues.indexOf(100);
    final kcalCtrl = FixedExtentScrollController(initialItem: idx);
    final gramsCtrl = FixedExtentScrollController(initialItem: idx);
    int? activeStandard = _standardIndexFor(gramsValues[idx], standardValues);
    var syncing = false;

    void sync(
      FixedExtentScrollController other,
      int i,
      StateSetter setSheetState,
    ) {
      if (syncing) return;
      syncing = true;
      idx = i;
      if (other.hasClients) other.jumpToItem(i);
      activeStandard = _standardIndexFor(gramsValues[idx], standardValues);
      syncing = false;
      setSheetState(() {});
    }

    void selectStandard(int i, StateSetter setSheetState) {
      final nextIdx = gramsValues.indexOf(standardValues[i]);
      if (nextIdx < 0) return;
      syncing = true;
      idx = nextIdx;
      activeStandard = i;
      if (kcalCtrl.hasClients) kcalCtrl.jumpToItem(nextIdx);
      if (gramsCtrl.hasClients) gramsCtrl.jumpToItem(nextIdx);
      syncing = false;
      setSheetState(() {});
    }

    showEcoSheet(
      context: context,
      t: t,
      title: l.t('food.portionSize'),
      onDone: () => setState(() => grams = gramsValues[idx]),
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return SizedBox(
            height: 186,
            child: Column(
              children: [
                _PortionStandardTabs(
                  t: t,
                  labels: standardLabels,
                  value: activeStandard,
                  onChanged: (i) => selectStandard(i, setSheetState),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: kcalCtrl,
                          itemExtent: 44,
                          selectionOverlay:
                              const EcoPickerSelectionOverlay(t: t),
                          onSelectedItemChanged: (i) =>
                              sync(gramsCtrl, i, setSheetState),
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
                          selectionOverlay:
                              const EcoPickerSelectionOverlay(t: t),
                          onSelectedItemChanged: (i) =>
                              sync(kcalCtrl, i, setSheetState),
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
              ],
            ),
          );
        },
      ),
    );
  }

  static int? _standardIndexFor(int value, List<int> standards) {
    final index = standards.indexOf(value);
    return index == -1 ? null : index;
  }

  static List<String> _portionStandardLabels(AppLanguage language) {
    return switch (language) {
      AppLanguage.en => const ['small', 'medium', 'large'],
      AppLanguage.uzLatn => const ['kichik', "o'rtacha", 'katta'],
      AppLanguage.uzCyrl => const ['кичик', 'ўртача', 'катта'],
      AppLanguage.ru => const ['маленький', 'средний', 'большой'],
    };
  }
}

class _PortionStandardTabs extends StatelessWidget {
  final EcoTheme t;
  final List<String> labels;
  final int? value;
  final ValueChanged<int> onChanged;

  const _PortionStandardTabs({
    required this.t,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              opacity: value == null ? 0 : 1,
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                alignment: _alignmentFor(value ?? 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / labels.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.dark.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: i == value ? t.pill : t.dark,
                        ),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(int index) {
    if (labels.length <= 1) return Alignment.center;
    final x = -1 + 2 * (index / (labels.length - 1));
    return Alignment(x, 0);
  }
}

class _MacroPercentLabels extends StatelessWidget {
  final List<({int pct, Color color, String label})> segments;

  const _MacroPercentLabels({required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox(height: 18);
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width <= 0) return const SizedBox.shrink();
          final count = segments.length;
          final maxLeft = math.max(0.0, width - _labelWidth(width, count));
          final labelWidth = math.min(_labelWidth(width, count), width);
          final minGap = _minGap(width, count, labelWidth);
          final total = segments.fold<int>(0, (sum, s) => sum + s.pct);
          if (total <= 0) return const SizedBox.shrink();

          final lefts = <double>[];
          var cursor = 0.0;
          for (final segment in segments) {
            final center = (cursor + segment.pct / 2) / total * width;
            lefts.add((center - labelWidth / 2).clamp(0.0, maxLeft));
            cursor += segment.pct;
          }

          for (var i = 1; i < lefts.length; i++) {
            lefts[i] = math.max(lefts[i], lefts[i - 1] + labelWidth + minGap);
          }
          if (lefts.isNotEmpty && lefts.last > maxLeft) {
            lefts[lefts.length - 1] = maxLeft;
            for (var i = lefts.length - 2; i >= 0; i--) {
              lefts[i] = math.min(lefts[i], lefts[i + 1] - labelWidth - minGap);
            }
          }
          if (lefts.isNotEmpty && lefts.first < 0) {
            final shift = -lefts.first;
            for (var i = 0; i < lefts.length; i++) {
              lefts[i] = math.min(maxLeft, lefts[i] + shift);
            }
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < segments.length; i++)
                Positioned(
                  left: lefts[i].clamp(0.0, maxLeft),
                  top: 0,
                  width: labelWidth,
                  child: Text(
                    '${segments[i].pct}%',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: EcoColors.sub,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static double _labelWidth(double width, int count) {
    if (count <= 0) return 0;
    const desiredWidth = 38.0;
    const desiredGap = 8.0;
    final available = width - desiredGap * math.max(0, count - 1);
    if (available >= desiredWidth * count) return desiredWidth;
    return math.max(24.0, available / count);
  }

  static double _minGap(double width, int count, double labelWidth) {
    if (count <= 1) return 0;
    const desiredGap = 8.0;
    final free = width - labelWidth * count;
    return math.max(0.0, math.min(desiredGap, free / (count - 1)));
  }
}

class _NutrientBadge extends StatelessWidget {
  final EcoTheme t;
  final int? percent;
  final String? label;
  final Color? color;

  const _NutrientBadge({
    required this.t,
    required this.percent,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percent;
    final text = pct == null ? label : '$pct%';
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (color ?? t.dark).withValues(alpha: pct == null ? 0.72 : 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: text == null || text.isEmpty
          ? null
          : Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: pct != null && pct >= 100 ? 10 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _DishHero extends StatelessWidget {
  final Product product;
  final String title;
  final bool selected;
  final String tooltip;
  final VoidCallback onFavorite;

  const _DishHero({
    required this.product,
    required this.title,
    required this.selected,
    required this.tooltip,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final heroHeight = (box.maxWidth * 0.72).clamp(220.0, 306.0);
        return SizedBox(
          height: heroHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(26),
              bottom: Radius.circular(22),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _DishHeroImage(product: product)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _DishTitleGlass(title: title),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FavoriteButton(
                        selected: selected,
                        tooltip: tooltip,
                        onTap: onFavorite,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DishTitleGlass extends StatelessWidget {
  final String title;

  const _DishTitleGlass({required this.title});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: _HeroGlassSurface(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: _heroPillHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.16,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 7,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? fillColor;
  final List<Color>? gradientColors;

  const _HeroGlassSurface({
    required this.child,
    required this.borderRadius,
    this.fillColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fillColor ?? Colors.white.withValues(alpha: 0.06),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.02),
                    ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _HeroGlassSurface(
        borderRadius: BorderRadius.circular(999),
        fillColor: selected ? Colors.white.withValues(alpha: 0.82) : null,
        gradientColors: selected
            ? [
                Colors.white.withValues(alpha: 0.94),
                Colors.white.withValues(alpha: 0.68),
              ]
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _heroPillHeight,
            height: _heroPillHeight,
            child: Icon(
              selected ? Icons.star_rounded : Icons.star_border_rounded,
              size: 22,
              color: selected ? EcoColors.ink : Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 7,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DishHeroImage extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final Product product;

  const _DishHeroImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imageAssetPath;
    if (imagePath != null) {
      final media = MediaQuery.of(context);
      final cacheWidth = (media.size.width * media.devicePixelRatio).round();
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final emoji = product.emoji;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.bandSoft, t.cardAlt, t.band],
        ),
      ),
      child: Center(
        child: emoji != null && emoji.isNotEmpty
            ? Text(emoji, style: const TextStyle(fontSize: 72))
            : Icon(
                product.isDrink
                    ? Icons.local_drink_outlined
                    : Icons.restaurant_menu,
                size: 72,
                color: t.dark,
              ),
      ),
    );
  }
}
