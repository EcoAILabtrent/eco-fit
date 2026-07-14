import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
import '../nutrition/micronutrients.dart';
import '../state/store.dart';
import '../theme/nutrient_colors.dart';
import '../theme/tokens.dart';
import '../ui/nutrition_widgets.dart';
import '../ui/ui.dart';
import 'addfood.dart';
import 'home.dart' show MealPickerHost;
import 'meallog.dart';

/// Дневник «Еда» — real per-date food diary with a day strip on top (last 7
/// days, today rightmost). Selecting a day shows that day's logged food,
/// macros and calories from the offline diary store.
class DayViewScreen extends StatefulWidget {
  const DayViewScreen({super.key});

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends State<DayViewScreen> {
  int offset = 0; // days back from today (0 = today)
  bool _hideBottomNav = false;

  // Календарная арифметика вместо Duration(days: offset): Duration — это ровно
  // N×24ч, и на переводе часов (DST) отнимание суток даёт соседнюю дату.
  // Конструктор DateTime нормализует day - offset корректно.
  DateTime get _selectedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - offset);
  }

  String get _dateKey => AppStore.ymd(_selectedDate);
  bool get _isToday => offset == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _hideBottomNav = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся только на тему, изменения дневника (diaryRevision) и цели —
    // тики шагомера/воды этот экран больше не перестраивают.
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>((s) => Object.hash(
          s.diaryRevision,
          s.goalKcal,
          s.carbGoal,
          s.fatGoal,
          s.protGoal,
        ));
    final s = context.read<AppStore>();
    final l = context.l10n;
    final consumed = s.consumedOn(_dateKey);
    final m = s.macrosOn(_dateKey);

    final bars = [
      (
        label: '',
        value: consumed.toDouble(),
        goal: s.goalKcal,
        max: (s.goalKcal * 1.4).round(),
        color: EcoColors.cal,
        soft: EcoColors.calSoft,
        head: true,
        zoneLo: s.goalKcal * 0.92,
        zoneHi: s.goalKcal * 1.05,
      ),
      (
        label: l.nutrient('carbs'),
        value: m.carbs,
        goal: s.carbGoal,
        max: (s.carbGoal * 1.6).round(),
        color: EcoColors.carb,
        soft: EcoColors.carbSoft,
        head: false,
        zoneLo: s.carbGoal * 0.85,
        zoneHi: s.carbGoal * 1.05,
      ),
      (
        label: l.nutrient('fat'),
        value: m.fat,
        goal: s.fatGoal,
        max: (s.fatGoal * 1.6).round(),
        color: EcoColors.fat,
        soft: EcoColors.fatSoft,
        head: false,
        zoneLo: s.fatGoal * 0.85,
        zoneHi: s.fatGoal * 1.05,
      ),
      (
        label: l.nutrient('protein'),
        value: m.protein,
        goal: s.protGoal,
        max: (s.protGoal * 1.6).round(),
        color: EcoColors.prot,
        soft: EcoColors.protSoft,
        head: false,
        zoneLo: s.protGoal * 0.85,
        zoneHi: s.protGoal * 1.05,
      ),
    ];

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('home.food'),
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: MealPickerHost(
        t: t,
        active: 'home',
        hidden: _hideBottomNav,
        onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onProfile: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          Navigator.of(context).pushNamed('/profile');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: 150 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Day strip: last 7 days, today rightmost ──
                _DayStrip(
                  offset: offset,
                  onSelect: (o) => setState(() => offset = o),
                  store: s,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _isToday ? l.t('common.today') : l.dayMonth(_selectedDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.sub,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Bars card ──
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    EcoPageRoute(
                      builder: (_) => NutritionDetailScreen(date: _dateKey),
                    ),
                  ),
                  child: EcoCard(
                    t: t,
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            l.t('food.nutritionSummary'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final (i, b) in bars.indexed)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i < bars.length - 1 ? 18 : 0,
                            ),
                            child: ProgressScale(
                              t: t,
                              value: b.value.toDouble(),
                              target: b.goal.toDouble(),
                              color: b.color,
                              unit: b.head ? l.unit('kcal') : l.unit('g'),
                              // Полоски появляются сразу заполненными, без роста
                              // из нуля: иначе 4 анимации 260мс конкурируют с
                              // слайдом перехода и утяжеляют первый кадр Dayview.
                              animateFromZero: false,
                              label:
                                  b.head ? l.t('common.totalAmount') : b.label,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Журнал питания (tap a meal → that day's meal log) ──
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('food.diary'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final (i, meal) in kMealsByTime.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1.5,
                            thickness: 1.5,
                            color: t.bandSoft,
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).push(
                            EcoPageRoute(
                              builder: (_) => MealLogScreen(
                                mealKey: meal.key,
                                // Всегда передаём конкретную дату дневника:
                                // «null = сегодня» разворачивается в ymd() в
                                // момент каждой операции и на границе полуночи
                                // уводит запись в новый день.
                                date: _dateKey,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                CalBadge(
                                  t: t,
                                  value: s.mealKcal(meal.key, date: _dateKey),
                                  size: 48,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    l.meal(meal.key),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).push(
                                    EcoPageRoute(
                                      builder: (_) => AddFoodScreen(
                                        mealKey: meal.key,
                                        date: _dateKey,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 10,
                                      right: 4,
                                      top: 8,
                                      bottom: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 2,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: t.bandSoft,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.add,
                                          size: 22,
                                          color: t.ink,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
}

class NutritionDetailScreen extends StatelessWidget {
  final String date;

  const NutritionDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>((s) => s.diaryRevision);
    final store = context.read<AppStore>();
    final l = context.l10n;
    final items = _itemsForDate(store);
    final totalKcal = _totalKcal(items);
    final sections = _buildSections(store, l, items);
    final parsedDate = DateTime.tryParse(date);

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('food.nutritionSummary'),
        onBack: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsedDate != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  l.dayMonth(parsedDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            EcoCard(
              t: t,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: Text(
                    l.t('food.emptyMeal'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ),
              ),
            )
          else
            EcoCard(
              t: t,
              pad: 14,
              margin: EdgeInsets.only(
                bottom: 32 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  if (totalKcal > 0) ...[
                    TotalCaloriesSummary(
                      label: l.t('common.totalAmount'),
                      total: totalKcal,
                      target: store.goalKcal.toDouble(),
                      unit: l.unit('kcal'),
                    ),
                    if (sections.isNotEmpty) const SizedBox(height: 24),
                  ],
                  for (final (i, section) in sections.indexed) ...[
                    if (i > 0) const SizedBox(height: 24),
                    _NutritionDetailSection(section: section),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<LogItem> _itemsForDate(AppStore store) {
    return (store.diary[date] ?? const <String, List<LogItem>>{})
        .values
        .expand((items) => items)
        .toList();
  }

  int _totalKcal(List<LogItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.kcal);
  }

  List<_NutritionSectionData> _buildSections(
    AppStore store,
    AppStrings l,
    List<LogItem> items,
  ) {
    if (items.isEmpty) return const [];

    final sections = <_NutritionSectionData>[
      _macroSection(
        key: 'fat',
        label: l.nutrient('fat'),
        total: items.fold(0, (sum, item) => sum + item.fat),
        target: store.fatGoal.toDouble(),
        unit: l.unit('g'),
        color: EcoColors.fat,
        items: items,
        valueFor: (item) => item.fat,
      ),
      _macroSection(
        key: 'carbs',
        label: l.nutrient('carbs'),
        total: items.fold(0, (sum, item) => sum + item.carbs),
        target: store.carbGoal.toDouble(),
        unit: l.unit('g'),
        color: EcoColors.carb,
        items: items,
        valueFor: (item) => item.carbs,
      ),
      _macroSection(
        key: 'protein',
        label: l.nutrient('protein'),
        total: items.fold(0, (sum, item) => sum + item.protein),
        target: store.protGoal.toDouble(),
        unit: l.unit('g'),
        color: EcoColors.prot,
        items: items,
        valueFor: (item) => item.protein,
      ),
    ].where((section) => section.total > 0).toList();

    final microTotals = store.microsOn(date);
    final microTargets = {
      for (final target in _microTargetsFor(store)) target.key: target,
    };
    const priority = kMicronutrientDisplayOrder;
    final orderedMicroKeys = [
      ...priority,
      for (final key in microTotals.keys)
        if (!priority.contains(key)) key,
    ];
    for (final key in orderedMicroKeys) {
      final total = microTotals[key] ?? 0;
      if (total <= 0) continue;
      final target = microTargets[key];
      final fallback = _fallbackMicroTarget(key, store);
      final unit = _microUnitLabel(target?.unit ?? fallback?.unit, l, key);
      sections.add(
        _NutritionSectionData(
          key: key,
          label: l.nutrient(key),
          total: total,
          target: target?.target ?? fallback?.target,
          unit: unit,
          color: nutrientColor(key),
          contributions: _microContributions(items, key),
        ),
      );
    }
    return sections;
  }

  _NutritionSectionData _macroSection({
    required String key,
    required String label,
    required double total,
    required double target,
    required String unit,
    required Color color,
    required List<LogItem> items,
    required double Function(LogItem item) valueFor,
  }) {
    return _NutritionSectionData(
      key: key,
      label: label,
      total: total,
      target: target,
      unit: unit,
      color: color,
      contributions: _contributions(items, valueFor),
    );
  }

  List<MicroTarget> _microTargetsFor(AppStore store) {
    final weight = store.weightKg ?? (store.weight > 0 ? store.weight : 66.0);
    final profile = NutritionProfile(
      ageYears: store.age ?? 28,
      sex: store.gender == 'f' ? ProfileSex.female : ProfileSex.male,
      weightKg: weight,
      heightCm: (store.heightCm ?? 178).toDouble(),
    );
    return calculateMicroTargets(
      profile,
      databaseNutrientKeys: FoodDb.instance.availableMicronutrientKeys,
    );
  }

  static List<_NutrientContribution> _contributions(
    List<LogItem> items,
    double Function(LogItem item) valueFor,
  ) {
    final byName = <String, double>{};
    for (final item in items) {
      final value = valueFor(item);
      if (value <= 0) continue;
      byName.update(
        item.name,
        (current) => current + value,
        ifAbsent: () => value,
      );
    }
    final out = [
      for (final entry in byName.entries)
        _NutrientContribution(name: entry.key, value: entry.value),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  static List<_NutrientContribution> _microContributions(
    List<LogItem> items,
    String key,
  ) {
    return _contributions(items, (item) => item.micros[key] ?? 0);
  }

  static _FallbackMicroTarget? _fallbackMicroTarget(
    String key,
    AppStore store,
  ) {
    final target = adultMicronutrientTarget(key, female: store.gender == 'f');
    if (target == null) return null;
    return _FallbackMicroTarget(target, microDefaultUnit(key));
  }

  static String _microUnitLabel(MicroUnit? unit, AppStrings l, String key) {
    if (key == 'fiber' || key == 'sugar') return l.unit('g');
    return switch (unit) {
      MicroUnit.mcg || MicroUnit.mcgRae || MicroUnit.mcgDfe => l.unit('mcg'),
      MicroUnit.mg || MicroUnit.mgNe => l.unit('mg'),
      MicroUnit.g => l.unit('g'),
      null => l.unit(microUnitCode(key)),
    };
  }
}

class _FallbackMicroTarget {
  final double target;
  final MicroUnit unit;

  const _FallbackMicroTarget(this.target, this.unit);
}

class _NutritionSectionData {
  final String key;
  final String label;
  final double total;
  final double? target;
  final String unit;
  final Color color;
  final List<_NutrientContribution> contributions;

  const _NutritionSectionData({
    required this.key,
    required this.label,
    required this.total,
    required this.target,
    required this.unit,
    required this.color,
    required this.contributions,
  });
}

class _NutrientContribution {
  final String name;
  final double value;

  const _NutrientContribution({required this.name, required this.value});
}

class _NutritionDetailSection extends StatelessWidget {
  final _NutritionSectionData section;

  const _NutritionDetailSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final visible = section.contributions.take(6).toList();
    final target = section.target;
    final hasTarget = target != null && target > 0;
    final overTarget = hasTarget && section.total > target;
    final headlineValue = hasTarget && !overTarget ? target : section.total;
    final headlineColor =
        hasTarget && !overTarget ? EcoColors.statusGood : t.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                section.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                  height: 1,
                ),
              ),
            ),
            Text(
              '${l.num1(headlineValue)} ${section.unit}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: headlineColor,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _NutritionDetailBar(
          value: section.total,
          target: section.target,
          color: section.color,
          unit: section.unit,
        ),
        if (visible.isNotEmpty) const SizedBox(height: 12),
        for (final (index, item) in visible.indexed)
          NutrientContributionRow(
            name: item.name,
            value: '${l.num1(item.value)} ${section.unit}',
            last: index == visible.length - 1,
          ),
      ],
    );
  }
}

class _NutritionDetailBar extends StatelessWidget {
  final double value;
  final double? target;
  final Color color;
  final String unit;

  const _NutritionDetailBar({
    required this.value,
    required this.target,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final safeTarget = target == null || target! <= 0 ? null : target;
    final over = safeTarget != null && value > safeTarget;
    final total = math.max(value, math.max(safeTarget ?? 0, 1));
    final fillEnd = safeTarget == null ? value : math.min(value, safeTarget);
    final light = Color.lerp(color, Colors.white, 0.62)!;
    final darker = Color.lerp(color, Colors.black, 0.28)!;
    final realText = '${l.num1(value)} $unit';
    final targetText = safeTarget == null ? '' : '${l.num1(safeTarget)} $unit';

    Widget valueLabel(String text, Color labelColor) => Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: labelColor,
            height: 1,
          ),
        );

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final fillW = (fillEnd / total * width).clamp(0.0, width);
        final valueX = (value / total * width).clamp(0.0, width);
        final targetX = safeTarget == null
            ? null
            : (safeTarget / total * width).clamp(0.0, width);
        Alignment atTop(double px) =>
            Alignment(((px / width) * 2 - 1).clamp(-0.96, 0.96), -1);

        return Column(
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: over ? darker : light,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // Inset-жёлоб (утоплённость) — как у ProgressScale: виден на
                  // незалитом остатке, заливка «приподнята».
                  const Positioned.fill(child: EcoInsetShadow()),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: fillW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.horizontal(
                          left: const Radius.circular(999),
                          right: Radius.circular(over ? 0 : 999),
                        ),
                      ),
                    ),
                  ),
                  if (over && targetX != null)
                    Positioned(
                      left: targetX,
                      top: 0,
                      bottom: 0,
                      width: (valueX - targetX).clamp(0.0, width),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: darker,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  if (over && targetX != null)
                    Positioned(
                      left: (targetX - 1.5).clamp(0.0, width - 3),
                      top: -1,
                      bottom: -1,
                      width: 3,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: EcoColors.statusGood),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: safeTarget == null ? 0 : 12,
              child: safeTarget == null
                  ? null
                  : Stack(
                      children: [
                        if (!over)
                          Align(
                            alignment: atTop(valueX),
                            child: valueLabel(realText, t.ink),
                          ),
                        if (over && targetX != null)
                          Align(
                            alignment: atTop(targetX),
                            child: valueLabel(
                              targetText,
                              EcoColors.statusGood,
                            ),
                          ),
                      ],
                    ),
            ),
            if (safeTarget == null)
              SizedBox(
                height: 12,
                child: Align(
                  alignment: atTop(valueX),
                  child: valueLabel(realText, t.ink),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Horizontal strip of the last 7 days — today rightmost, each cell shows the
/// weekday, date, a goal-progress ring and a fill state.
class _DayStrip extends StatefulWidget {
  final int offset;
  final ValueChanged<int> onSelect;
  final AppStore store;

  const _DayStrip({
    required this.offset,
    required this.onSelect,
    required this.store,
  });

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const _dayCount = 30;
  // 52 (не 56): 7 ячеек влезают в видимую ширину (вьюпорт EcoScreen обрезает
  // full-bleed-ленту на 16px по краям), поэтому крайние кольца — сб слева и
  // сегодня справа — помещаются целиком, а не подрезаются.
  static const _itemExtent = 52.0;
  static const _itemHeight = 120.0;

  final ScrollController _controller = ScrollController();
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSelected());
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offset != widget.offset) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, box) {
        // Full-bleed to the phone edges: cancel EcoScreen's 16px side padding
        // so the day cells run edge-to-edge and scroll off at the screen border.
        final screenWidth = MediaQuery.sizeOf(context).width;
        _viewportWidth = screenWidth;
        return SizedBox(
          height: _itemHeight,
          child: OverflowBox(
            minWidth: screenWidth,
            maxWidth: screenWidth,
            minHeight: _itemHeight,
            maxHeight: _itemHeight,
            child: NotificationListener<ScrollNotification>(
              // Contain the strip's horizontal (over)scroll so it doesn't drive
              // the page's vertical stretch overscroll.
              onNotification: (_) => true,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                // Правый отступ, чтобы сегодняшний день не упирался в край: 24 =
                // 16 (срез вьюпортом EcoScreen) + 8 видимого зазора.
                padding: const EdgeInsets.only(right: 24),
                child: SizedBox(
                  width: _dayCount * _itemExtent,
                  height: _itemHeight,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: kEcoMotionDuration,
                        curve: kEcoMotionCurve,
                        left: _selectedIndex * _itemExtent + 3,
                        top: 0,
                        bottom: 0,
                        width: _itemExtent - 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.band,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            for (var o = _dayCount - 1; o >= 0; o--)
                              SizedBox(
                                width: _itemExtent,
                                // Календарный сдвиг от единого `now` за build:
                                // Duration(days: o) на переводе часов уводит
                                // ячейку на соседнюю дату и рассинхронит
                                // подсветку с ключом данных.
                                child: _cell(
                                  DateTime(now.year, now.month, now.day - o),
                                  o,
                                  l,
                                  t,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int get _selectedIndex =>
      _dayCount - 1 - widget.offset.clamp(0, _dayCount - 1);

  Widget _cell(DateTime date, int o, AppStrings l, EcoTheme t) {
    final active = o == widget.offset;
    final key = AppStore.ymd(date);
    final m = widget.store.macrosOn(key);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(o),
      child: Container(
        height: _itemHeight,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        constraints: const BoxConstraints(minWidth: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.weekdayShort(date.weekday),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? t.ink : t.sub,
              ),
            ),
            const SizedBox(height: 6),
            // Каждая ячейка-кольца кешируется в свой слой: движение выделения
            // (AnimatedPositioned) и перестройки экрана больше не перерисовывают
            // все 30 painter'ов с MaskFilter.blur разом.
            RepaintBoundary(
              child: MacroRings(
                t: t,
                size: 44,
                data: [
                  MacroRingData(
                    value: m.carbs,
                    goal: widget.store.carbGoal.toDouble(),
                    color: EcoColors.carb,
                    soft: EcoColors.carbSoft,
                  ),
                  MacroRingData(
                    value: m.fat,
                    goal: widget.store.fatGoal.toDouble(),
                    color: EcoColors.fat,
                    soft: EcoColors.fatSoft,
                  ),
                  MacroRingData(
                    value: m.protein,
                    goal: widget.store.protGoal.toDouble(),
                    color: EcoColors.prot,
                    soft: EcoColors.protSoft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? t.ink : t.ink,
              ),
            ),
            // "today" marker dot
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color:
                    o == 0 ? (active ? t.dark : t.olive) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToSelected() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_targetScrollFor(widget.offset));
  }

  void _animateToSelected() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _targetScrollFor(widget.offset),
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
    );
  }

  double _targetScrollFor(int offset) {
    final safeOffset = offset.clamp(0, _dayCount - 1);
    final index = _dayCount - 1 - safeOffset;
    final centered = index * _itemExtent - (_viewportWidth - _itemExtent) / 2;
    final max =
        _controller.hasClients ? _controller.position.maxScrollExtent : 0.0;
    return centered.clamp(0.0, max);
  }
}
