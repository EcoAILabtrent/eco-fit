import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/nutrition_widgets.dart';
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
      EcoPageRoute(
        builder: (_) => DishScreen(
          product: product,
          mealKey: mealKey,
          date: date,
          initialGrams: item.grams ??
              (product.isPieceUnit ? product.gramsPerUnit.round() : 100),
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
    // Штучные показываем как «N шт»: берём сохранённое число штук (совпадает с
    // выбором при любом размере), иначе оцениваем из массы.
    if (product != null && product.isPieceUnit) {
      final pieces = item.pieces ?? product.piecesForGrams(grams);
      return '${formatPieceCount(pieces, l.language)}'
          ' ${product.displayUnit(l.language)}';
    }
    final unit = product?.displayUnit(l.language) ?? l.unit('g');
    return '$grams $unit';
  }

  @override
  Widget build(BuildContext context) {
    // Только тема + изменения дневника + время приёма; тики шагомера/воды этот
    // экран не перестраивают.
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>(
      (s) => Object.hash(s.diaryRevision, s.mealTime(mealKey)),
    );
    final s = context.read<AppStore>();
    final l = context.l10n;
    final items = s.itemsFor(mealKey, date: date);
    final time = s.mealTime(mealKey);

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('food.diary'),
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
                onTap: () => Navigator.of(context).push(
                  EcoPageRoute(
                    builder: (_) => AddFoodScreen(
                      mealKey: mealKey,
                      date: date,
                      // Открыт из журнала — по «Добавить» вернуться сюда, а не
                      // класть в стек второй журнал.
                      openLogOnFinish: false,
                    ),
                  ),
                ),
                child: Text(l.t('common.add')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EcoBtn(
                t: t,
                frosted: true,
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
                      // Ввод времени — стандартная стеклянная кнопка (press-эффект).
                      EcoGlassButton(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        onTap: () => _pickTime(context, time),
                        child: Text(
                          time,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: t.sub,
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
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: t.sub,
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
                                    // Удаление блюда — круглая стеклянная кнопка
                                    // (как edit-круг в профиле): светлое стекло с
                                    // press-эффектом + искажением, а не плоский
                                    // залитый кружок.
                                    EcoGlassButton(
                                      width: 36,
                                      height: 36,
                                      padding: EdgeInsets.zero,
                                      onTap: () => context
                                          .read<AppStore>()
                                          .removeFood(mealKey, i, date: date),
                                      child: Center(
                                        child: Icon(
                                          Icons.remove,
                                          size: 20,
                                          color: t.ink,
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
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    var v = 210;
    final values = [for (var i = 10; i <= 1500; i += 10) i];
    // Контроллер создаём до показа шита и dispose'им по его закрытию: иначе
    // FixedExtentScrollController течёт на каждый показ окна.
    final ctrl = FixedExtentScrollController(initialItem: values.indexOf(210));
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
          scrollController: ctrl,
          itemExtent: 44,
          selectionOverlay: EcoPickerSelectionOverlay(t: t),
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
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _pickMeal(BuildContext context) {
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    final screen = MediaQuery.of(context);
    final anchorContext = _mealTitleKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final anchorOffset =
        anchorBox?.localToGlobal(Offset.zero) ?? const Offset(0, 210);
    final anchorBottom = anchorOffset.dy + (anchorBox?.size.height ?? 44);
    // Ширина подгоняется под самую длинную надпись приёма пищи — без лишних
    // зазоров и без обрезки, корректно при смене языка. Хром: паддинг подложки
    // (12*2) + поля вокруг текста в пилюле (~20*2) + запас (6).
    final popupWidth = ecoPopupContentWidth(
      context: context,
      labels: [for (final m in kMealsByTime) l.meal(m.key)],
      chrome: 12 * 2 + 20 * 2 + 6,
      minWidth: 160,
      maxWidth: screen.size.width - 32,
    );
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
      // Без затемнения фона — единое поведение со всеми меню.
      barrierColor: Colors.transparent,
      transitionDuration: kEcoMotionDuration,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: kEcoMotionCurve,
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
                          // Подложка как у окон ввода («Размер порции»):
                          // полупрозрачное стекло по теме + сильное размытие.
                          blur: 60,
                          borderRadius: BorderRadius.circular(22),
                          // Единые тени для всех меню: тёмная + верхний блик.
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.30),
                              blurRadius: 16,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final m in kMealsByTime)
                                _MealChoiceButton(
                                  t: t,
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
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    final parts = current.split(':');
    var h = int.tryParse(parts[0]) ?? 8;
    var mi = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    // Контроллеры колёс создаём до показа шита и dispose'им по его закрытию.
    final hCtrl = FixedExtentScrollController(initialItem: h);
    final miCtrl = FixedExtentScrollController(initialItem: mi);
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
                scrollController: hCtrl,
                itemExtent: 36,
                selectionOverlay: EcoPickerSelectionOverlay(
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
                color: t.ink,
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: miCtrl,
                itemExtent: 36,
                selectionOverlay: EcoPickerSelectionOverlay(
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
    ).whenComplete(() {
      hCtrl.dispose();
      miCtrl.dispose();
    });
  }
}

class _MealMacroCard extends StatelessWidget {
  final List<LogItem> items;
  final AppStore store;

  const _MealMacroCard({required this.items, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
      t: t,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalKcal > 0) ...[
            TotalCaloriesSummary(
              label: l.t('common.totalAmount'),
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressScale(
          t: t,
          value: section.total,
          target: section.target,
          color: section.color,
          unit: section.unit,
          label: section.label,
        ),
        if (section.rows.isNotEmpty) const SizedBox(height: 12),
        for (final (index, row) in section.rows.indexed)
          NutrientContributionRow(
            name: row.name,
            value: '${l.num1(row.value)} ${section.unit}',
            last: index == section.rows.length - 1,
          ),
      ],
    );
  }
}

class _MealChoiceButton extends StatelessWidget {
  final EcoTheme t;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MealChoiceButton({
    required this.t,
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
        fontSize: 16,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        color: t.ink,
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
              duration: kEcoMotionDuration,
              child: selected
                  ? SizedBox(
                      key: ValueKey('selected-$label'),
                      width: double.infinity,
                      height: 44,
                      child: Stack(
                        children: [
                          EcoPickerSelectionOverlay(
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
                      width: double.infinity,
                      height: 44,
                      child: Center(child: text),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
