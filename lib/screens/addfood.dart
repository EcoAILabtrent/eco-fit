import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
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
  final _selected = <String, _SelectedProduct>{};
  String query = '';
  bool catalogMode = true;
  bool _filterMenuOpen = false;
  Set<String> categoryFilterIds = {};
  Set<String>? categoryFilterSlugs;
  final _filterLayerLink = LayerLink();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // Кэш результатов: поиск/категории считаем не в build(), а только при смене
  // запроса/фильтра. Раньше FoodDb.search() (полный проход по базе) запускался
  // на каждый build — в т.ч. на фоновых тиках store (шаги/вода).
  List<Product> _matching = const [];
  List<ProductCategory>? _categoriesCache;
  String? _categoriesLocale;
  Timer? _searchDebounce;

  void _recomputeMatching() {
    _matching = FoodDb.instance.search(
      query,
      categorySlugs: categoryFilterSlugs,
      limit: FoodDb.instance.all.length, // показать весь подходящий каталог
    );
  }

  List<ProductCategory> _categoriesFor(AppStrings l) {
    final code = l.language.code;
    if (_categoriesCache == null || _categoriesLocale != code) {
      _categoriesCache = FoodDb.instance.categories();
      _categoriesLocale = code;
    }
    return _categoriesCache!;
  }

  Meal get meal => kMeals.firstWhere(
        (m) => m.key == widget.mealKey,
        orElse: () => kMeals.first,
      );

  @override
  void initState() {
    super.initState();
    _recomputeMatching();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && _filterMenuOpen && mounted) {
        setState(() => _filterMenuOpen = false);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Bulk quick-add the checkbox-selected products at 100 г, then stay on the
  /// list (top-app pattern) so the user can keep adding.
  int _commitSelected() {
    final store = context.read<AppStore>();
    var added = 0;
    for (final entry in _selected.entries) {
      final p = FoodDb.instance.bySlug(entry.key);
      if (p == null) continue;
      store.addFood(
        widget.mealKey,
        entry.value.toLogItem(p),
        date: widget.date,
      );
      added++;
    }
    if (added > 0) setState(() => _selected.clear());
    return added;
  }

  void _finish() {
    if (_selected.isEmpty) return;
    _commitSelected();
    Navigator.of(context).pushReplacement(
      EcoPageRoute(
        builder: (_) =>
            MealLogScreen(mealKey: widget.mealKey, date: widget.date),
      ),
    );
  }

  void _applyCategoryFilters(Iterable<ProductCategory> categories) {
    final selected = categories.toList();
    setState(() {
      catalogMode = true;
      _filterMenuOpen = false;
      categoryFilterIds = {for (final category in selected) category.id};
      categoryFilterSlugs = selected.isEmpty
          ? null
          : {for (final category in selected) ...category.categorySlugs};
      _recomputeMatching();
    });
  }

  void _toggleCategory(
    ProductCategory category,
    List<ProductCategory> categories,
  ) {
    final nextIds = categoryFilterIds.contains(category.id)
        ? <String>{}
        : <String>{category.id};
    _applyCategoryFilters(
      categories.where((item) => nextIds.contains(item.id)),
    );
  }

  void _showCatalog({bool focusSearch = false}) {
    setState(() {
      catalogMode = true;
      _filterMenuOpen = false;
      categoryFilterIds = {};
      categoryFilterSlugs = null;
      _recomputeMatching();
    });
    if (focusSearch) _searchFocus.requestFocus();
  }

  void _showFavorites() {
    _searchFocus.unfocus();
    setState(() {
      catalogMode = false;
      _filterMenuOpen = false;
      categoryFilterIds = {};
      categoryFilterSlugs = null;
      _recomputeMatching();
    });
  }

  void _toggleFilterMenu() {
    setState(() => _filterMenuOpen = !_filterMenuOpen);
  }

  String _activeFilterLabel(AppStrings l, List<ProductCategory> categories) {
    if (!catalogMode) return l.t('food.favorites');
    for (final category in categories) {
      if (categoryFilterIds.contains(category.id)) return category.name;
    }
    return _allFilterLabel(l);
  }

  String _allFilterLabel(AppStrings l) => switch (l.language.code) {
        'en' => 'All',
        'uz_latn' => 'Hammasi',
        'uz_cyrl' => 'Ҳаммаси',
        _ => 'Всё',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final categories = _categoriesFor(l);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final searchBottom =
        keyboardInset > 0 ? keyboardInset + 10.0 : bottomInset + 90.0;
    final productCardBottomGap = searchBottom + 58.0;
    const listBottomPadding = 12.0;
    final store = context.read<AppStore>();
    // В режиме «избранное» пересобираемся только при изменении набора избранного
    // (а не на каждый notify стора). В каталоге эта подписка не нужна.
    if (!catalogMode) {
      context.select<AppStore, int>((s) => s.favoriteProductSlugs.length);
    }
    final items = catalogMode
        ? _matching
        : _matching
            .where((product) => store.isFavoriteProduct(product.slug))
            .toList();
    final activeFilterLabel = _activeFilterLabel(l, categories);
    final selectedCount = _selected.length;
    final selectedKcal = _selected.entries.fold<int>(0, (sum, entry) {
      final product = FoodDb.instance.bySlug(entry.key);
      return product == null ? sum : sum + entry.value.kcal(product);
    });
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: false,
      body: BackdropGroup(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: EcoGlassBackground(t: t)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AddFoodTopBar(
                      t: t,
                      title: l.meal(meal.key),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    AnimatedSize(
                      duration: kEcoMotionDuration,
                      curve: kEcoMotionCurve,
                      alignment: Alignment.topLeft,
                      child: AnimatedSwitcher(
                        duration: kEcoMotionDuration,
                        switchInCurve: kEcoMotionCurve,
                        switchOutCurve: Curves.easeInCubic,
                        child: selectedCount > 0
                            ? Padding(
                                key: const ValueKey('selected-summary'),
                                padding:
                                    const EdgeInsets.only(top: 10, left: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: t.ink,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.selectedFoods(
                                        selectedCount,
                                        selectedKcal,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: t.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('selected-summary-empty'),
                                width: double.infinity,
                              ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(
                          top: 16,
                          bottom: productCardBottomGap,
                        ),
                        child: EcoGlassSurface(
                          t: t,
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(t.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 18, 20, 12),
                                child: Text(
                                  activeFilterLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: t.ink,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: t.glassBorder,
                              ),
                              Expanded(
                                child: items.isEmpty
                                    ? !catalogMode &&
                                            store.favoriteProductSlugs.isEmpty
                                        ? _EmptyFavorites(
                                            t: t,
                                            text: l.t('food.favoritesEmpty'),
                                            buttonLabel:
                                                l.t('food.browseProducts'),
                                            onBrowse: () =>
                                                _showCatalog(focusSearch: true),
                                          )
                                        : Center(
                                            child: Text(
                                              l.t('food.noResults'),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: t.sub,
                                              ),
                                            ),
                                          )
                                    : ListView.separated(
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        padding: const EdgeInsets.only(
                                          bottom: listBottomPadding,
                                        ),
                                        itemCount: items.length,
                                        separatorBuilder: (_, __) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: t.bandSoft,
                                          ),
                                        ),
                                        itemBuilder: (ctx, i) {
                                          final p = items[i];
                                          final selected = _selected[p.slug];
                                          // Штучные продукты по умолчанию — 1 шт
                                          // (её вес), остальные — 100 г.
                                          final defaultGrams = p.isPieceUnit
                                              ? p.gramsPerUnit.round()
                                              : 100;
                                          return _ProductRow(
                                            t: t,
                                            p: p,
                                            selected: selected != null,
                                            grams: selected?.grams ?? defaultGrams,
                                            pieces: selected?.pieces ??
                                                (p.isPieceUnit ? 1.0 : null),
                                            onToggle: () => setState(
                                              () => selected != null
                                                  ? _selected.remove(p.slug)
                                                  : _selected[p.slug] =
                                                      _SelectedProduct(
                                                        grams: defaultGrams,
                                                        pieces: p.isPieceUnit
                                                            ? 1.0
                                                            : null,
                                                      ),
                                            ),
                                            onOpen: () async {
                                              final result = await Navigator.of(
                                                      context)
                                                  .push<DishSelectionResult>(
                                                EcoPageRoute(
                                                  builder: (_) => DishScreen(
                                                    product: p,
                                                    mealKey: widget.mealKey,
                                                    date: widget.date,
                                                    initialGrams:
                                                        selected?.grams ??
                                                            defaultGrams,
                                                  ),
                                                ),
                                              );
                                              if (result == null || !mounted) {
                                                return;
                                              }
                                              setState(() {
                                                _selected[result.product.slug] =
                                                    _SelectedProduct(
                                                  grams: result.grams,
                                                  pieces: result.pieces,
                                                );
                                              });
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              bottom: searchBottom,
              child: CompositedTransformTarget(
                link: _filterLayerLink,
                child: EcoGlassSurface(
                  t: t,
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  borderRadius: BorderRadius.circular(t.r),
                  child: SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        Icon(
                          ecoIcon('search'),
                          size: 30,
                          color: t.sub,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            focusNode: _searchFocus,
                            controller: _searchCtrl,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            onChanged: (v) {
                              // Поле обновляем сразу (крестик очистки), а
                              // дорогой пересчёт списка откладываем на 150 мс.
                              setState(() => query = v);
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted) setState(_recomputeMatching);
                                },
                              );
                            },
                            decoration: InputDecoration(
                              hintText: l.t('food.search'),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _searchDebounce?.cancel();
                              setState(() {
                                query = '';
                                _recomputeMatching();
                              });
                              _searchFocus.requestFocus();
                            },
                            child: Icon(Icons.close, size: 18, color: t.ink),
                          ),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: IconButton(
                            onPressed: _toggleFilterMenu,
                            tooltip: l.t('food.filters'),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (_filterMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _filterMenuOpen = false),
                  child: const SizedBox.expand(),
                ),
              ),
            if (_filterMenuOpen)
              CompositedTransformFollower(
                link: _filterLayerLink,
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -10),
                showWhenUnlinked: false,
                child: _FilterMenuPopup(
                  t: t,
                  allLabel: _allFilterLabel(l),
                  favoritesLabel: l.t('food.favorites'),
                  categories: categories,
                  activeLabel: activeFilterLabel,
                  catalogMode: catalogMode,
                  selectedIds: categoryFilterIds,
                  onAll: () => _showCatalog(),
                  onFavorites: _showFavorites,
                  onCategory: (category) =>
                      _toggleCategory(category, categories),
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
              child: Row(
                children: [
                  Expanded(
                    child: EcoBtn(
                      t: t,
                      bg: t.dark,
                      fg: t.onDark,
                      onTap: () {
                        if (_selected.isNotEmpty) {
                          setState(_selected.clear);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
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
                      bg: _selected.isEmpty
                          ? t.dark.withValues(alpha: 0.30)
                          : t.dark,
                      fg: t.onDark,
                      onTap: _selected.isEmpty ? null : _finish,
                      child: Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              l.t('common.add'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            child: _selected.isEmpty
                                ? null
                                : Text(
                                    '${_selected.length}',
                                    textAlign: TextAlign.right,
                                  ),
                          ),
                        ],
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

class _SelectedProduct {
  final int grams;
  final double? pieces; // выбранное число штук (для штучных продуктов)

  const _SelectedProduct({required this.grams, this.pieces});

  double _scaled(Product p, num value) => value * grams / 100;

  int kcal(Product p) => _scaled(p, p.kcal).round();

  LogItem toLogItem(Product p) => LogItem(
        p.name,
        kcal(p),
        protein: _scaled(p, p.protein),
        carbs: _scaled(p, p.carbs),
        fat: _scaled(p, p.fat),
        micros: p.microsForGrams(grams),
        productSlug: p.slug,
        grams: grams,
        pieces: pieces,
      );
}

class _AddFoodTopBar extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final VoidCallback onBack;

  const _AddFoodTopBar({
    required this.t,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.chevron_left, size: 28, color: t.ink),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterMenuPopup extends StatelessWidget {
  final EcoTheme t;
  final String allLabel;
  final String favoritesLabel;
  final List<ProductCategory> categories;
  final String activeLabel;
  final bool catalogMode;
  final Set<String> selectedIds;
  final VoidCallback onAll;
  final VoidCallback onFavorites;
  final ValueChanged<ProductCategory> onCategory;

  const _FilterMenuPopup({
    required this.t,
    required this.allLabel,
    required this.favoritesLabel,
    required this.categories,
    required this.activeLabel,
    required this.catalogMode,
    required this.selectedIds,
    required this.onAll,
    required this.onFavorites,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    // Ширина подгоняется под самую длинную надпись (включая категории) — без
    // лишних зазоров и без обрезки, корректно при смене языка. Хром: паддинг
    // подложки (12*2) + паддинг строки (14*2) + запас (6).
    final width = ecoPopupContentWidth(
      context: context,
      labels: [
        allLabel,
        favoritesLabel,
        for (final category in categories) category.name,
      ],
      chrome: 12 * 2 + 14 * 2 + 6,
      minWidth: 160,
      maxWidth: MediaQuery.sizeOf(context).width - 32,
    );
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: EcoGlassSurface(
          t: t,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          // Подложка как у окон ввода («Размер порции»): полупрозрачное стекло
          // по теме + сильное размытие.
          blur: 60,
          borderRadius: BorderRadius.circular(22),
          // Единые тени для всех меню: мягкая тёмная + верхний блик.
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
            children: [
              _FilterMenuItem(
                t: t,
                label: allLabel,
                selected: catalogMode && selectedIds.isEmpty,
                onTap: onAll,
              ),
              _FilterMenuItem(
                t: t,
                label: favoritesLabel,
                selected: !catalogMode,
                onTap: onFavorites,
              ),
              for (final category in categories)
                _FilterMenuItem(
                  t: t,
                  label: category.name,
                  selected: activeLabel == category.name,
                  onTap: () => onCategory(category),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterMenuItem extends StatelessWidget {
  final EcoTheme t;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterMenuItem({
    required this.t,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Единое выделение выбранного — стеклянная пилюля как у пикеров
              // («173 см», фото 5). Выравнивание справа сохраняем.
              if (selected)
                Positioned.fill(
                  child: EcoPickerSelectionOverlay(
                    t: t,
                    radius: 999,
                    margin: EdgeInsets.zero,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.05,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: t.ink.withValues(alpha: selected ? 0.95 : 0.88),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  final EcoTheme t;
  final String text;
  final String buttonLabel;
  final VoidCallback onBrowse;

  const _EmptyFavorites({
    required this.t,
    required this.text,
    required this.buttonLabel,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 34, color: t.olive),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: t.sub,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 190,
              child: EcoBtn(
                t: t,
                height: 42,
                fontSize: 12,
                onTap: onBrowse,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final EcoTheme t;
  final Product p;
  final bool selected;
  final int grams;
  final double? pieces;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ProductRow({
    required this.t,
    required this.p,
    required this.selected,
    required this.grams,
    required this.pieces,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selectedKcal = (p.kcal * grams / 100).round();
    // Для штучных показываем выбранное число штук (если известно), иначе —
    // оценку из массы; так «1 большой ломоть» не превращается в «1,5 шт».
    final portionLabel = p.isPieceUnit
        ? '${formatPieceCount(pieces ?? p.piecesForGrams(grams), l.language)}'
            ' ${p.displayUnit(l.language)}'
        : '$grams ${p.displayUnit(l.language)}';
    final kcalLabel = selected
        ? '$selectedKcal ${l.unit('kcal')} · $portionLabel'
        : '${p.kcal} ${p.calorieBaseLabel(l.language).replaceAll(' ', '')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 75),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? t.dark : Colors.white.withValues(alpha: 0.42),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.dark : const Color(0xFFD8E1EF),
                  width: 1.3,
                ),
              ),
              child:
                  selected ? Icon(Icons.check, size: 14, color: t.onDark) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Row(
                children: [
                  _ProductVisual(t: t, product: p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          p.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: selected ? 128 : 104),
                    child: Text(
                      kcalLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: selected ? 12 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
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
}

class _ProductVisual extends StatelessWidget {
  final EcoTheme t;
  final Product product;

  const _ProductVisual({required this.t, required this.product});

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imageAssetPath;
    final cacheExtent = (42 * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: t.bandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imagePath != null
          ? Image.asset(
              imagePath,
              width: 42,
              height: 42,
              cacheWidth: cacheExtent,
              cacheHeight: cacheExtent,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final emoji = product.emoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Text(emoji, style: const TextStyle(fontSize: 18));
    }
    return Icon(
      product.isDrink ? Icons.local_drink_outlined : Icons.restaurant_menu,
      size: 19,
      color: t.ink,
    );
  }
}
