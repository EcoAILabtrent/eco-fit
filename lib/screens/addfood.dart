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
  static const t = EcoTheme.meadow;
  final _selected = <String, _SelectedProduct>{};
  String query = '';
  bool catalogMode = true;
  bool _filterMenuOpen = false;
  Set<String> categoryFilterIds = {};
  Set<String>? categoryFilterSlugs;
  final _filterLayerLink = LayerLink();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  Meal get meal => kMeals.firstWhere(
        (m) => m.key == widget.mealKey,
        orElse: () => kMeals.first,
      );

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && _filterMenuOpen && mounted) {
        setState(() => _filterMenuOpen = false);
      }
    });
  }

  @override
  void dispose() {
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
      MaterialPageRoute(
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
    final categories = FoodDb.instance.categories();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final searchBottom =
        keyboardInset > 0 ? keyboardInset + 10.0 : bottomInset + 90.0;
    final productCardBottomGap = searchBottom + 58.0;
    const listBottomPadding = 12.0;
    final store = context.watch<AppStore>();
    final matchingItems = FoodDb.instance.search(
      query,
      categorySlugs: categoryFilterSlugs,
      limit: 100000,
    );
    final items = catalogMode
        ? matchingItems
        : matchingItems
            .where((product) => store.isFavoriteProduct(product.slug))
            .toList();
    final l = context.l10n;
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
            const Positioned.fill(child: EcoGlassBackground(t: t)),
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
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
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
                                      color: t.dark,
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
                                        color: t.dark,
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
                        duration: const Duration(milliseconds: 220),
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: EcoColors.ink,
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
                                            text: l.t('food.favoritesEmpty'),
                                            buttonLabel:
                                                l.t('food.browseProducts'),
                                            onBrowse: () =>
                                                _showCatalog(focusSearch: true),
                                          )
                                        : Center(
                                            child: Text(
                                              l.t('food.noResults'),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: EcoColors.sub,
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
                                          return _ProductRow(
                                            p: p,
                                            selected: selected != null,
                                            grams: selected?.grams ?? 100,
                                            onToggle: () => setState(
                                              () => selected != null
                                                  ? _selected.remove(p.slug)
                                                  : _selected[p.slug] =
                                                      const _SelectedProduct(
                                                          grams: 100),
                                            ),
                                            onOpen: () async {
                                              final result = await Navigator.of(
                                                      context)
                                                  .push<DishSelectionResult>(
                                                MaterialPageRoute(
                                                  builder: (_) => DishScreen(
                                                    product: p,
                                                    mealKey: widget.mealKey,
                                                    date: widget.date,
                                                    initialGrams:
                                                        selected?.grams ?? 100,
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
              duration: const Duration(milliseconds: 220),
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
                          color: EcoColors.sub,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            focusNode: _searchFocus,
                            controller: _searchCtrl,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            onChanged: (v) => setState(() => query = v),
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
                              setState(() => query = '');
                              _searchFocus.requestFocus();
                            },
                            child: Icon(Icons.close, size: 18, color: t.dark),
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
                      fg: t.pill,
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
                      fg: t.pill,
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

  const _SelectedProduct({required this.grams});

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
      );
}

class _AddFoodTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _AddFoodTopBar({
    required EcoTheme t,
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
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.chevron_left, size: 28, color: EcoColors.ink),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: EcoColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterMenuPopup extends StatelessWidget {
  static const t = EcoTheme.meadow;
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
    final width = (MediaQuery.sizeOf(context).width - 96).clamp(220.0, 244.0);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: EcoGlassSurface(
          t: t,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          bg: Colors.white.withValues(alpha: 0.46),
          blur: 22,
          borderRadius: BorderRadius.circular(22),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(-2, -2),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterMenuItem(
                label: allLabel,
                selected: catalogMode && selectedIds.isEmpty,
                onTap: onAll,
              ),
              _FilterMenuItem(
                label: favoritesLabel,
                selected: !catalogMode,
                onTap: onFavorites,
              ),
              for (final category in categories)
                _FilterMenuItem(
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
  static const t = EcoTheme.meadow;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterMenuItem({
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
        child: Container(
          height: 41,
          alignment: Alignment.centerRight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: selected ? 36 : 41,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: selected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.58))
                  : null,
            ),
            alignment: Alignment.centerRight,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: t.dark.withValues(alpha: selected ? 0.95 : 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final String text;
  final String buttonLabel;
  final VoidCallback onBrowse;

  const _EmptyFavorites({
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
                color: EcoColors.sub,
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
  static const t = EcoTheme.meadow;
  final Product p;
  final bool selected;
  final int grams;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ProductRow({
    required this.p,
    required this.selected,
    required this.grams,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selectedKcal = (p.kcal * grams / 100).round();
    final kcalLabel = selected
        ? '$selectedKcal ${l.unit('kcal')} · $grams ${p.displayUnit(l.language)}'
        : '${p.kcal} ${p.calorieBaseLabel(l.language).replaceAll(' ', '')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
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
                  selected ? Icon(Icons.check, size: 14, color: t.pill) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Row(
                children: [
                  _ProductVisual(product: p),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: EcoColors.sub,
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
                        color: selected ? t.dark : EcoColors.ink,
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
  static const t = EcoTheme.meadow;
  final Product product;

  const _ProductVisual({required this.product});

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
      color: t.dark,
    );
  }
}
