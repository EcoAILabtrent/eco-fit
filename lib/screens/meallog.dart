import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'addfood.dart';
import 'dish.dart';

/// Журнал питания — port of logscreens.jsx::MealLog.
class MealLogScreen extends StatefulWidget {
  final String mealKey;
  final String? date; // null = today
  const MealLogScreen({super.key, required this.mealKey, this.date});

  @override
  State<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends State<MealLogScreen> {
  static const t = EcoTheme.meadow;
  final _mealTitleKey = GlobalKey();
  late String mealKey = widget.mealKey;
  String? get date => widget.date;

  Meal get meal =>
      kMeals.firstWhere((m) => m.key == mealKey, orElse: () => kMeals[1]);

  Future<void> _editItem(int index, LogItem item) async {
    final slug = item.productSlug;
    if (slug == null) return;
    final product = FoodDb.instance.bySlug(slug);
    if (product == null) return;
    final result = await Navigator.of(context).push<DishSelectionResult>(
      MaterialPageRoute(
        builder: (_) => DishScreen(
          product: product,
          mealKey: mealKey,
          date: date,
          initialGrams: item.grams ?? 100,
        ),
      ),
    );
    if (result == null || !mounted) return;
    context
        .read<AppStore>()
        .updateFood(mealKey, index, result.toLogItem(), date: date);
  }

  String? _portionLabel(LogItem item, AppStrings l) {
    final grams = item.grams;
    if (grams == null) return null;
    final product = item.productSlug == null
        ? null
        : FoodDb.instance.bySlug(item.productSlug!);
    final unit = product?.displayUnit(l.language) ?? l.unit('g');
    return '$grams $unit';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final items = s.itemsFor(mealKey, date: date);
    final time = s.mealTime(mealKey);

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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddFoodScreen(mealKey: mealKey, date: date),
                  ),
                ),
                child: Text(l.t('common.add')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EcoBtn(
                t: t,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(l.t('common.done')),
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
            title: l.t('food.diary'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              children: [
                // meal dropdown + time pill
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        key: _mealTitleKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickMeal(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l.meal(meal.key),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.keyboard_arrow_down, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickTime(context, time),
                        child: EcoPill(
                          t: t,
                          bg: t.band,
                          text: time,
                          fontSize: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                EcoCard(
                  t: t,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 320),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.t('food.products'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (items.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 50),
                                child: Center(
                                  child: Text(
                                    l.t('food.emptyMeal'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: EcoColors.sub,
                                    ),
                                  ),
                                ),
                              ),
                            for (final (i, it) in items.indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1.5,
                                  thickness: 1.5,
                                  color: t.bandSoft,
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _editItem(i, it),
                                        child: Row(
                                          children: [
                                            CalBadge(
                                                t: t, value: it.kcal, size: 48),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    it.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (_portionLabel(it, l) !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 2),
                                                      child: Text(
                                                        _portionLabel(it, l)!,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: EcoColors.sub,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context
                                          .read<AppStore>()
                                          .removeFood(mealKey, i, date: date),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: t.band,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: 20,
                                          color: t.dark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: EcoBtn(
                                t: t,
                                height: 46,
                                fontSize: 14,
                                onTap: _quickKcal,
                                child: Text(
                                  l.t('food.addCaloriesManual'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MealMacroCard(items: items, store: s),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _quickKcal() {
    final l = context.l10nRead;
    var v = 210;
    final values = [for (var i = 10; i <= 1500; i += 10) i];
    showEcoSheet(
      context: context,
      t: t,
      title: l.t('food.addCaloriesManual'),
      onDone: () {
        context.read<AppStore>().addFood(
              mealKey,
              LogItem(l.t('food.quickAdd'), v),
              date: date,
            );
      },
      body: SizedBox(
        height: 130,
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: values.indexOf(210),
          ),
          itemExtent: 44,
          selectionOverlay: const EcoPickerSelectionOverlay(t: t),
          onSelectedItemChanged: (i) => v = values[i],
          children: [
            for (final n in values)
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$n',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '  ${l.unit('kcal')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMeal(BuildContext context) {
    final l = context.l10nRead;
    final screen = MediaQuery.of(context);
    final anchorContext = _mealTitleKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final anchorOffset =
        anchorBox?.localToGlobal(Offset.zero) ?? const Offset(0, 210);
    final anchorBottom = anchorOffset.dy + (anchorBox?.size.height ?? 44);
    final popupWidth = screen.size.width < 306 ? screen.size.width - 32 : 262.0;
    final estimatedHeight = 286.0;
    var selectedMealKey = mealKey;
    final popupTop = (anchorBottom + 10)
        .clamp(
          screen.padding.top + 8,
          screen.size.height - estimatedHeight - screen.padding.bottom - 8,
        )
        .toDouble();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l.t('common.cancel'),
      barrierColor: const Color(0x4714180C),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          children: [
            Positioned(
              top: popupTop,
              left: (screen.size.width - popupWidth) / 2,
              width: popupWidth,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  alignment: Alignment.topCenter,
                  scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                  child: StatefulBuilder(
                    builder: (popupCtx, popupSetState) {
                      return Material(
                        color: Colors.transparent,
                        child: EcoGlassSurface(
                          t: t,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          bg: t.band,
                          blur: 18,
                          borderRadius: BorderRadius.circular(24),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x52121A08),
                              blurRadius: 34,
                              offset: Offset(0, 14),
                            ),
                          ],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final m in kMealsByTime)
                                _MealChoiceButton(
                                  label: l.meal(m.key),
                                  selected: m.key == selectedMealKey,
                                  onTap: () {
                                    popupSetState(() {
                                      selectedMealKey = m.key;
                                    });
                                    if (m.key != mealKey) {
                                      setState(() => mealKey = m.key);
                                    }
                                    Navigator.of(dialogCtx).pop();
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _pickTime(BuildContext context, String current) {
    final l = context.l10nRead;
    final parts = current.split(':');
    var h = int.tryParse(parts[0]) ?? 8;
    var mi = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    showEcoSheet(
      context: context,
      t: t,
      title: l.t('common.setTime'),
      onDone: () => context.read<AppStore>().setMealTime(
            mealKey,
            '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
          ),
      body: SizedBox(
        height: 130,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: h),
                itemExtent: 36,
                selectionOverlay: const EcoPickerSelectionOverlay(
                  t: t,
                  radius: 14,
                ),
                onSelectedItemChanged: (v) => h = v,
                children: [
                  for (var i = 0; i < 24; i++)
                    Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              ':',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.dark,
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: mi),
                itemExtent: 36,
                selectionOverlay: const EcoPickerSelectionOverlay(
                  t: t,
                  radius: 14,
                ),
                onSelectedItemChanged: (v) => mi = v,
                children: [
                  for (var i = 0; i < 60; i++)
                    Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
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

class _MealMacroCard extends StatelessWidget {
  final List<LogItem> items;
  final AppStore store;

  const _MealMacroCard({required this.items, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalKcal = items.fold<int>(0, (sum, item) => sum + item.kcal);
    final sections = [
      _MealMacroSectionData(
        label: l.nutrient('fat'),
        total: items.fold(0.0, (sum, item) => sum + item.fat),
        target: store.fatGoal.toDouble(),
        color: EcoColors.fat,
        unit: l.unit('g'),
        rows: _rows(items, (item) => item.fat),
      ),
      _MealMacroSectionData(
        label: l.nutrient('carbs'),
        total: items.fold(0.0, (sum, item) => sum + item.carbs),
        target: store.carbGoal.toDouble(),
        color: EcoColors.carb,
        unit: l.unit('g'),
        rows: _rows(items, (item) => item.carbs),
      ),
      _MealMacroSectionData(
        label: l.nutrient('protein'),
        total: items.fold(0.0, (sum, item) => sum + item.protein),
        target: store.protGoal.toDouble(),
        color: EcoColors.prot,
        unit: l.unit('g'),
        rows: _rows(items, (item) => item.protein),
      ),
    ].where((section) => section.total > 0).toList();

    return EcoCard(
      t: _MealLogScreenState.t,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalKcal > 0) ...[
            _TotalCaloriesSummary(
              label: _totalCaloriesLabel(l),
              total: totalKcal,
              target: store.goalKcal.toDouble(),
              unit: l.unit('kcal'),
            ),
          ],
          if (sections.isNotEmpty) const SizedBox(height: 22),
          for (final (index, section) in sections.indexed) ...[
            if (index > 0) const SizedBox(height: 22),
            _MealMacroSection(section: section),
          ],
        ],
      ),
    );
  }

  String _totalCaloriesLabel(AppStrings l) => switch (l.language) {
        AppLanguage.en => 'Total',
        AppLanguage.uzLatn => 'Umumiy',
        AppLanguage.uzCyrl => 'Умумий',
        AppLanguage.ru => 'Общее количество',
      };

  static List<_MealMacroRowData> _rows(
    List<LogItem> items,
    double Function(LogItem item) valueFor,
  ) {
    final rows = <_MealMacroRowData>[
      for (final item in items)
        if (valueFor(item) > 0)
          _MealMacroRowData(name: item.name, value: valueFor(item)),
    ];
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }
}

class _TotalCaloriesSummary extends StatelessWidget {
  final String label;
  final int total;
  final double target;
  final String unit;

  const _TotalCaloriesSummary({
    required this.label,
    required this.total,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return ProgressScale(
      value: total.toDouble(),
      target: target,
      color: EcoColors.cal,
      unit: unit,
      label: label,
    );
  }
}

class _MealMacroSectionData {
  final String label;
  final double total;
  final double target;
  final Color color;
  final String unit;
  final List<_MealMacroRowData> rows;

  const _MealMacroSectionData({
    required this.label,
    required this.total,
    required this.target,
    required this.color,
    required this.unit,
    required this.rows,
  });
}

class _MealMacroRowData {
  final String name;
  final double value;

  const _MealMacroRowData({required this.name, required this.value});
}

class _MealMacroSection extends StatelessWidget {
  final _MealMacroSectionData section;

  const _MealMacroSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressScale(
          value: section.total,
          target: section.target,
          color: section.color,
          unit: section.unit,
          label: section.label,
        ),
        if (section.rows.isNotEmpty) const SizedBox(height: 12),
        for (final (index, row) in section.rows.indexed)
          _MealMacroContributionRow(
            name: row.name,
            value: '${_fmtMacro(row.value, l)} ${section.unit}',
            last: index == section.rows.length - 1,
          ),
      ],
    );
  }

  static String _fmtMacro(double value, AppStrings l) {
    final decimal =
        l.language == AppLanguage.ru || l.language == AppLanguage.uzCyrl
            ? ','
            : '.';
    final fixed =
        value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return fixed.replaceAll('.', decimal);
  }
}

class _MealMacroContributionRow extends StatelessWidget {
  final String name;
  final String value;
  final bool last;

  const _MealMacroContributionRow({
    required this.name,
    required this.value,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: EcoColors.sub,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 86,
                child: Text(
                  value,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: EcoColors.ink,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),
      ],
    );
  }
}

class _MealChoiceButton extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MealChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: selected ? 17 : 16,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        color: t.dark,
        decoration: TextDecoration.none,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? SizedBox(
                      key: ValueKey('selected-$label'),
                      width: 238,
                      height: 42,
                      child: Stack(
                        children: [
                          const EcoPickerSelectionOverlay(
                            t: t,
                            radius: 999,
                            margin: EdgeInsets.zero,
                          ),
                          Center(child: text),
                        ],
                      ),
                    )
                  : SizedBox(
                      key: ValueKey('plain-$label'),
                      width: 238,
                      height: 42,
                      child: Center(child: text),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
