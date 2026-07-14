import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
import '../nutrition/micronutrients.dart';
import '../state/store.dart';
import '../theme/nutrient_colors.dart';
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
  final double? pieces; // выбранное число штук (для штучных продуктов)

  const DishSelectionResult({
    required this.product,
    required this.grams,
    this.pieces,
  });

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
      pieces: pieces,
    );
  }
}

/// Display unit code for the macro rows shown above the micronutrient list.
/// Micronutrient units are resolved from the DB-backed [microUnitCode] helper.
const _macroUnits = {
  'protein': 'g',
  'fat': 'g',
  'carbs': 'g',
};

const _heroPillHeight = 42.0;

class _DishScreenState extends State<DishScreen> {
  late int grams;
  late final int _initialGrams;

  // Штучный режим: размер (индекс 0/1/2 → масса одной штуки) и число штук
  // выбираются НЕЗАВИСИМО. grams = штуки × масса_размера — канон хранения.
  static const _pieceSteps = <double>[
    0.5,
    1,
    1.5,
    2,
    2.5,
    3,
    3.5,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
  ];
  late List<int> _pieceSizes; // [маленький, средний, большой], г
  int _sizeIdx = 1; // выбранный размер (по умолчанию — средний)
  double _pieces = 1; // выбранное число штук

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
    if (p.isPieceUnit) {
      // Штучные: размер по умолчанию — средний, число штук выводим из массы.
      _pieceSizes = p.pieceSizeGrams();
      _sizeIdx = 1;
      final start = (widget.initialGrams ?? _pieceSizes[_sizeIdx]).toDouble();
      _pieces = _snapPieces(start / _pieceSizes[_sizeIdx]);
      grams = (_pieces * _pieceSizes[_sizeIdx]).round();
    } else {
      _pieceSizes = const [];
      grams = (widget.initialGrams ?? 100).clamp(10, 1000).toInt();
    }
    _initialGrams = grams;
  }

  static double _snapPieces(double raw) => _pieceSteps[_nearestStepIndex(raw)];

  static int _nearestStepIndex(double pieces) {
    var best = 0;
    var bestDelta = (_pieceSteps.first - pieces).abs();
    for (var i = 1; i < _pieceSteps.length; i++) {
      final delta = (_pieceSteps[i] - pieces).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  bool get _hasPortionChanges => grams != _initialGrams;

  void _cancelOrResetPortion() {
    if (_hasPortionChanges) {
      setState(() {
        grams = _initialGrams;
        if (p.isPieceUnit) {
          _sizeIdx = 1;
          _pieces = _snapPieces(_initialGrams / _pieceSizes[_sizeIdx]);
        }
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _savePortion() {
    Navigator.of(context).pop(
      DishSelectionResult(
        product: p,
        grams: grams,
        pieces: p.isPieceUnit ? _pieces : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    // Подписываемся только на «избранность» этого продукта, а не на весь стор —
    // тик шагомера/воды больше не перестраивает экран блюда.
    final isFavorite =
        context.select<AppStore, bool>((s) => s.isFavoriteProduct(p.slug));
    final store = context.read<AppStore>();
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

    // Штучные продукты: в плашке — число штук, под ней — «Масса: N г» (граммы
    // остаются каноном хранения и пересчитываются при смене размера/штук).
    final portionText = p.isPieceUnit
        ? '${formatPieceCount(_pieces, l.language)} ${p.displayUnit(l.language)}'
        : '$grams ${p.displayUnit(l.language)}';
    final portionSubtitle = p.isPieceUnit
        ? '${l.t('food.mass')}: $grams ${l.unit('g')}'
        : l.t('food.portionSize');

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
          unit: l.unit(_macroUnits[e.key] ?? microUnitCode(e.key)),
          value: _scaled(e.value),
          pct: null,
          color: nutrientColor(e.key),
        ),
    ];

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('food.dishes'),
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: Row(
          children: [
            Expanded(
              child: EcoBtn(
                t: t,
                frosted: true,
                bg: t.dark,
                fg: t.onDark,
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
                frosted: true,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 106),
            // Подложка блюда — СТАНДАРТНАЯ карточка: фон t.card, радиус t.r и
            // мягкая светлая тень-ореол, как у всех карточек (например «Еда»).
            // Без своих borderRadius/shadows, чтобы вид совпадал в обеих темах.
            child: EcoGlassSurface(
              t: t,
              padding: EdgeInsets.zero,
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
                            // Сводка ккал/порции — стандартная стеклянная кнопка
                            // (press-эффект), открывает выбор порции.
                            child: EcoGlassButton(
                              width: double.infinity,
                              height: 46,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              onTap: _pickPortion,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$kcal ${l.unit('kcal')}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      portionText,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            portionSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.sub,
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
                        _MacroPercentLabels(t: t, segments: activeSegs),
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
                                  '${l.num1(n.value)} ${n.unit}',
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

  static String _nutrientBadgeLabel(String key) => switch (key) {
        'protein' => 'P',
        'fat' => 'F',
        'carbs' => 'C',
        'fiber' => 'Fib',
        'sugar' => 'Sug',
        // Minerals — element symbols.
        'fe' => 'Fe',
        'mg' => 'Mg',
        'ca' => 'Ca',
        'p' => 'P',
        'k' => 'K',
        'na' => 'Na',
        'zn' => 'Zn',
        'cl' => 'Cl',
        's' => 'S',
        'mn' => 'Mn',
        'cu' => 'Cu',
        'se' => 'Se',
        'i' => 'I',
        'f' => 'F',
        'cr' => 'Cr',
        'mo' => 'Mo',
        'co' => 'Co',
        // Vitamins.
        'vit_c' => 'C',
        'vit_a' => 'A',
        'vit_d' => 'D',
        'vit_e' => 'E',
        'vit_k' => 'K',
        'vit_h' => 'B7',
        'vit_b1' => 'B1',
        'vit_b2' => 'B2',
        'vit_b3' => 'B3',
        'vit_b4' => 'B4',
        'vit_b5' => 'B5',
        'vit_b6' => 'B6',
        'vit_b9' => 'B9',
        'vit_b12' => 'B12',
        _ => key.isEmpty ? '' : key.substring(0, 1).toUpperCase(),
      };

  void _pickPortion() {
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    if (p.isPieceUnit) {
      _pickPiecePortion(t, l);
    } else {
      _pickGramsPortion(t, l);
    }
  }

  /// Граммовый выбор (не штучные продукты): вкладки маленький/средний/большой —
  /// это КОЛИЧЕСТВО (100/150/200 или 200/300/400 для напитков), колесо — граммы.
  void _pickGramsPortion(EcoTheme t, AppStrings l) {
    final gramsValues = [for (var g = 10; g <= 1000; g += 5) g];
    final standardValues =
        p.isDrink ? const [200, 300, 400] : const [100, 150, 200];
    final standardLabels = _portionStandardLabels(l);
    var idx = gramsValues.indexOf(grams);
    if (idx < 0) idx = _nearestIndex(gramsValues, grams);
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
                          selectionOverlay: EcoPickerSelectionOverlay(t: t),
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
                          selectionOverlay: EcoPickerSelectionOverlay(t: t),
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
    ).whenComplete(() {
      kcalCtrl.dispose();
      gramsCtrl.dispose();
    });
  }

  /// Штучный выбор: вкладки маленький/средний/большой — это РАЗМЕР одной штуки
  /// (её масса), правое колесо — число штук (выбираем сами). Смена размера
  /// меняет только массу и ккал, число штук не трогает.
  void _pickPiecePortion(EcoTheme t, AppStrings l) {
    final sizes = _pieceSizes; // [маленький, средний, большой], г
    // Значения на момент открытия — чтобы откатить по «Отмена»/закрытию.
    final startGrams = grams;
    final startPieces = _pieces;
    final startSize = _sizeIdx;
    var sizeIdx = _sizeIdx;
    var pieceIdx = _nearestStepIndex(_pieces);
    final kcalCtrl = FixedExtentScrollController(initialItem: pieceIdx);
    final pieceCtrl = FixedExtentScrollController(initialItem: pieceIdx);
    var syncing = false;
    var applied = false;

    int gramsFor(int pIdx, int sIdx) =>
        (_pieceSteps[pIdx] * sizes[sIdx]).round();

    // Живой предпросмотр: экран блюда (плашка, ккал, «Масса») обновляется сразу
    // при смене размера/штук, а не только по «Готово».
    void applyLive() {
      setState(() {
        _sizeIdx = sizeIdx;
        _pieces = _pieceSteps[pieceIdx];
        grams = gramsFor(pieceIdx, sizeIdx);
      });
    }

    void syncWheels(
      FixedExtentScrollController other,
      int i,
      StateSetter setSheetState,
    ) {
      if (syncing) return;
      syncing = true;
      pieceIdx = i;
      if (other.hasClients) other.jumpToItem(i);
      syncing = false;
      applyLive();
      setSheetState(() {});
    }

    showEcoSheet(
      context: context,
      t: t,
      title: l.t('food.size'),
      onDone: () => applied = true, // уже применено вживую в applyLive()
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return SizedBox(
            height: 186,
            child: Column(
              children: [
                _PortionStandardTabs(
                  t: t,
                  labels: _portionStandardLabels(l),
                  value: sizeIdx,
                  // Размер меняет массу штуки; число штук (колесо) не трогаем.
                  onChanged: (i) {
                    sizeIdx = i;
                    applyLive();
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: kcalCtrl,
                          itemExtent: 44,
                          selectionOverlay: EcoPickerSelectionOverlay(t: t),
                          onSelectedItemChanged: (i) =>
                              syncWheels(pieceCtrl, i, setSheetState),
                          children: [
                            for (var i = 0; i < _pieceSteps.length; i++)
                              Center(
                                child: Text(
                                  '${(gramsFor(i, sizeIdx) * p.kcal / 100).round()}'
                                  ' ${l.unit('kcal')}',
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
                          scrollController: pieceCtrl,
                          itemExtent: 44,
                          selectionOverlay: EcoPickerSelectionOverlay(t: t),
                          onSelectedItemChanged: (i) =>
                              syncWheels(kcalCtrl, i, setSheetState),
                          children: [
                            for (final s in _pieceSteps)
                              Center(
                                child: Text(
                                  '${formatPieceCount(s, l.language)}'
                                  ' ${p.displayUnit(l.language)}',
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
    ).then((_) {
      // Если закрыли без «Готово» — откатываем живой предпросмотр.
      if (!applied && mounted) {
        setState(() {
          grams = startGrams;
          _pieces = startPieces;
          _sizeIdx = startSize;
        });
      }
    }).whenComplete(() {
      kcalCtrl.dispose();
      pieceCtrl.dispose();
    });
  }

  /// Индекс ближайшего значения списка к [target] — для случая, когда сохранённая
  /// порция (например, старая запись в граммах) не попадает точно в шаг колеса.
  static int _nearestIndex(List<int> values, int target) {
    var best = 0;
    var bestDelta = (values.first - target).abs();
    for (var i = 1; i < values.length; i++) {
      final delta = (values[i] - target).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  static int? _standardIndexFor(int value, List<int> standards) {
    final index = standards.indexOf(value);
    return index == -1 ? null : index;
  }

  static List<String> _portionStandardLabels(AppStrings l) => [
        l.t('dish.portionSmall'),
        l.t('dish.portionMedium'),
        l.t('dish.portionLarge'),
      ];
}

class _PortionStandardTabs extends StatefulWidget {
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
  State<_PortionStandardTabs> createState() => _PortionStandardTabsState();
}

class _PortionStandardTabsState extends State<_PortionStandardTabs> {
  // Последний выбранный индекс: при исчезновении (value == null) таблетка гаснет
  // НА ЭТОМ месте, а не уезжает к нулевой позиции.
  int _lastIndex = 0;
  // Слайд включаем ТОЛЬКО при переключении между вкладками (оба значения != null).
  // Появление (null→index) и исчезновение (index→null) — без слайда: позиция
  // меняется мгновенно (пока таблетка невидима), видно только фейд.
  bool _slide = false;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) _lastIndex = widget.value!;
  }

  @override
  void didUpdateWidget(_PortionStandardTabs old) {
    super.didUpdateWidget(old);
    _slide = old.value != null &&
        widget.value != null &&
        old.value != widget.value;
    if (widget.value != null) _lastIndex = widget.value!;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final labels = widget.labels;
    final value = widget.value;
    final activeIndex = value ?? _lastIndex;
    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          // Подложка = «нажатая» стеклянная кнопка (glass sunken, макет
          // EcoSegmented 66:7 с эффектом BACKGROUND_BLUR): тень снаружи контура +
          // backdrop-blur искажение фона + inset-тёмная тень + белая кайма —
          // ровно как pressed EcoGlassButton (Variant2), а не плоское frosted-
          // стекло (у него drop-тень просвечивала сквозь заливку и подложка
          // серела — не читалась «вдавленной»).
          const Positioned.fill(child: EcoGlassSunken(radius: 999)),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  // Переключение между вкладками — плавный СЛАЙД (AnimatedAlign).
                  // Появление/исчезновение — ФЕЙД (AnimatedOpacity): при value==null
                  // таблетка гаснет на своём месте (alignment = _lastIndex, без съезда
                  // влево), при возврате позиция ставится мгновенно (_slide=false →
                  // duration 0) и таблетка проявляется — «въезда» сбоку не видно.
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      opacity: value == null ? 0 : 1,
                      child: AnimatedAlign(
                        duration: _slide
                            ? const Duration(milliseconds: 160)
                            : Duration.zero,
                        curve: Curves.easeOutCubic,
                        alignment: _alignmentFor(activeIndex),
                        child: FractionallySizedBox(
                          widthFactor: 1 / labels.length,
                          heightFactor: 1,
                          child: Stack(
                            children: [
                              // Ползунок — петроль #045157 + drop-тень 2/2/2 α25.
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF045157),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x40000000),
                                        offset: Offset(2, 2),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Inset-белый хайлайт (glass-объём).
                              const Positioned.fill(
                                child: EcoGlassHighlight(radius: 999),
                              ),
                            ],
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
                            onTap: () => widget.onChanged(i),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 85),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: i == value ? t.onDark : t.ink,
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
            ),
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(int index) {
    if (widget.labels.length <= 1) return Alignment.center;
    final x = -1 + 2 * (index / (widget.labels.length - 1));
    return Alignment(x, 0);
  }
}

class _MacroPercentLabels extends StatelessWidget {
  final EcoTheme t;
  final List<({int pct, Color color, String label})> segments;

  const _MacroPercentLabels({required this.t, required this.segments});

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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.sub,
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
            // Верхние углы = радиус стандартной карточки (t.r = 20), чтобы
            // картинка точно вписывалась в подложку.
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
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
      // Искажение (backdrop-blur σ8) под пилюлей-названием и кнопкой избранного:
      // фото-герой преломляется сквозь стекло — «жидкое стекло», как у кнопок/
      // навбара. Экран блюда в SingleChildScrollView, поэтому размытие семплирует
      // кадр-буфер на каждой прокрутке; здесь эффект важнее этой цены (две мелкие
      // области). Ниже — полупрозрачная заливка + градиент + белая кайма поверх.
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fillColor ?? Colors.white.withValues(alpha: 0.16),
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
            // Иконки из Figma: 117:604 (контур-звезда с листом) — не в избранном,
            // 299:2337 (залитая звезда с листом-вырезом) — добавлено. Невыбранная
            // тонируется в БЕЛЫЙ (лежит на матовом стекле поверх фото); выбранная —
            // в родном цвете макета (#555F3B), т.к. кнопка при выборе почти белая.
            child: Center(
              child: SvgPicture.asset(
                selected
                    ? 'assets/icons/fav_star_added.svg'
                    : 'assets/icons/fav_star.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                colorFilter: selected
                    ? null
                    : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DishHeroImage extends StatelessWidget {
  final Product product;

  const _DishHeroImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final imagePath = product.imageAssetPath;
    if (imagePath != null) {
      final media = MediaQuery.of(context);
      final cacheWidth = (media.size.width * media.devicePixelRatio).round();
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _fallback(t),
      );
    }
    return _fallback(t);
  }

  Widget _fallback(EcoTheme t) {
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
                color: t.ink,
              ),
      ),
    );
  }
}
