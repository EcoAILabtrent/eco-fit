import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../l10n/app_language.dart';

/// Product from the offline SQLite catalog (assets/db/eco_fit.db).
class Product {
  final int id;
  final String slug;
  final String name;
  final String? emoji;
  final String category;
  final String categorySlug;
  final String typeCode;
  final String unit;
  final num gramsPerUnit;
  final bool isRecipe;
  final bool isDrink;
  final int kcal; // per 100 g
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, num> micros; // per 100 g
  final String? imageAssetPath;
  final String? imageStoragePath;
  final String? imageRemoteUrl;
  final String searchText;

  Product({
    required this.id,
    required this.slug,
    required this.name,
    this.emoji,
    required this.category,
    required this.categorySlug,
    required this.typeCode,
    required this.unit,
    required this.gramsPerUnit,
    required this.isRecipe,
    required this.isDrink,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.micros = const {},
    this.imageAssetPath,
    this.imageStoragePath,
    this.imageRemoteUrl,
    this.searchText = '',
  });

  late final String nameSearchKey = _normalizeSearchText(name);
  late final String nameSearchIndex = _buildSearchIndex(name);
  late final String categorySearchKey = _buildSearchIndex(category);
  late final String searchKey = _buildSearchIndex(
    [name, category, slug.replaceAll('_', ' '), searchText].join(' '),
  );
  late final List<String> nameSearchTokens = _searchTokens(nameSearchIndex);
  late final List<String> categorySearchTokens = _searchTokens(
    categorySearchKey,
  );
  late final List<String> searchTokens = _searchTokens(searchKey);
  late final Set<String> nameSearchTokenSet = nameSearchTokens.toSet();
  late final Set<String> categorySearchTokenSet = categorySearchTokens.toSet();
  late final Set<String> searchTokenSet = searchTokens.toSet();

  bool get hasImage =>
      imageAssetPath != null ||
      imageStoragePath != null ||
      imageRemoteUrl != null;

  String displayUnit(AppLanguage language) => switch (unit) {
    'ml' => _unit(language, 'ml'),
    'l' => _unit(language, 'l'),
    'piece' => _unit(language, 'piece'),
    'portion' => _unit(language, 'portion'),
    _ => _unit(language, 'g'),
  };

  String calorieBaseLabel(AppLanguage language) =>
      '${_unit(language, 'kcal')}/100 ${displayUnit(language)}';

  Map<String, double> microsForGrams(num grams) => {
    for (final entry in micros.entries)
      entry.key: entry.value.toDouble() * grams / 100,
  };

  static String _unit(AppLanguage language, String code) {
    final labels = _unitLabels[language] ?? _unitLabels[AppLanguage.ru]!;
    return labels[code] ?? code;
  }

  static const _unitLabels = {
    AppLanguage.en: {
      'kcal': 'kcal',
      'g': 'g',
      'ml': 'ml',
      'l': 'l',
      'piece': 'pcs',
      'portion': 'portion',
    },
    AppLanguage.ru: {
      'kcal': 'ккал',
      'g': 'г',
      'ml': 'мл',
      'l': 'л',
      'piece': 'шт',
      'portion': 'порция',
    },
    AppLanguage.uzLatn: {
      'kcal': 'kkal',
      'g': 'g',
      'ml': 'ml',
      'l': 'l',
      'piece': 'dona',
      'portion': 'porsiya',
    },
    AppLanguage.uzCyrl: {
      'kcal': 'ккал',
      'g': 'г',
      'ml': 'мл',
      'l': 'л',
      'piece': 'дона',
      'portion': 'порция',
    },
  };

  static Product fromDbRow(Map<String, Object?> row, Map<String, num> micros) {
    return Product(
      id: (row['id'] as num).toInt(),
      slug: row['slug'] as String,
      name: (row['name'] as String?) ?? row['slug'] as String,
      emoji: _nonEmpty(row['emoji']),
      category: (row['category_name'] as String?) ?? '',
      categorySlug: (row['category_slug'] as String?) ?? '',
      typeCode: (row['type_code'] as String?) ?? 'food',
      unit: (row['default_unit_code'] as String?) ?? 'g',
      gramsPerUnit: (row['grams_per_default_unit'] as num?) ?? 100,
      isRecipe: ((row['is_recipe'] as num?) ?? 0).toInt() == 1,
      isDrink: ((row['is_drink'] as num?) ?? 0).toInt() == 1,
      kcal: ((row['kcal_per_100g'] as num?) ?? 0).round(),
      protein: ((row['protein_g_per_100g'] as num?) ?? 0).toDouble(),
      carbs: ((row['carbs_g_per_100g'] as num?) ?? 0).toDouble(),
      fat: ((row['fat_g_per_100g'] as num?) ?? 0).toDouble(),
      micros: micros,
      imageAssetPath: _nonEmpty(row['primary_image_asset_path']),
      imageStoragePath: _nonEmpty(row['primary_image_storage_path']),
      imageRemoteUrl: _nonEmpty(row['primary_image_remote_url']),
      searchText: [
        _nonEmpty(row['food_search_text']),
        _nonEmpty(row['category_search_text']),
        _nonEmpty(row['alias_search_text']),
      ].whereType<String>().join(' '),
    );
  }

  static String? _nonEmpty(Object? value) {
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}

class ProductCategory {
  final String id;
  final String name;
  final int count;
  final Set<String> categorySlugs;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.count,
    required this.categorySlugs,
  });
}

/// Loads and searches the offline product database.
///
/// The bundled SQLite asset is copied into the app database directory. Product
/// data is then read from SQLite and cached in memory for fast UI search.
class FoodDb {
  FoodDb._();
  static final FoodDb instance = FoodDb._();

  static const _assetPath = 'assets/db/eco_fit.db';
  static const _dbFileName = 'eco_fit.db';
  String _locale = AppLanguage.ru.productLocale;

  final List<Product> all = [];
  Database? _db;
  bool _loaded = false;

  Future<void> load({String? localeCode, bool force = false}) async {
    final nextLocale = localeCode ?? _locale;
    if (_loaded && _locale == nextLocale && !force) return;
    final path = await _ensureDatabaseFile();
    final db = _db ?? await openDatabase(path, readOnly: false);
    _db = db;
    _locale = nextLocale;

    final microsByFoodId = await _loadMicros(db);
    final rows = await db.rawQuery(
      '''
      SELECT
        f.id,
        f.slug,
        f.emoji,
        f.type_code,
        f.is_recipe,
        f.is_drink,
        f.grams_per_default_unit,
        u.code AS default_unit_code,
        c.slug AS category_slug,
        COALESCE(ft_req.name, ft_default.name, f.slug) AS name,
        COALESCE(ct_req.name, ct_default.name, '') AS category_name,
        n.kcal_per_100g,
        n.protein_g_per_100g,
        n.carbs_g_per_100g,
        n.fat_g_per_100g,
        img.asset_path AS primary_image_asset_path,
        img.storage_path AS primary_image_storage_path,
        img.remote_url AS primary_image_remote_url,
        (
          SELECT GROUP_CONCAT(
            COALESCE(ft_all.name, '') || ' ' ||
            COALESCE(ft_all.short_name, '') || ' ' ||
            COALESCE(ft_all.brand_name, '') || ' ' ||
            COALESCE(ft_all.search_text, ''),
            ' '
          )
          FROM food_translations ft_all
          WHERE ft_all.food_id = f.id
        ) AS food_search_text,
        (
          SELECT GROUP_CONCAT(
            COALESCE(ct_all.name, '') || ' ' ||
            COALESCE(ct_all.search_text, ''),
            ' '
          )
          FROM category_translations ct_all
          WHERE ct_all.category_id = c.id
        ) AS category_search_text,
        (
          SELECT GROUP_CONCAT(fa.alias || ' ' || fa.normalized_alias, ' ')
          FROM food_aliases fa
          WHERE fa.food_id = f.id
        ) AS alias_search_text
      FROM foods f
      LEFT JOIN units u ON u.id = f.default_unit_id
      LEFT JOIN categories c ON c.id = f.primary_category_id
      LEFT JOIN food_translations ft_req
        ON ft_req.food_id = f.id AND ft_req.locale_code = ?
      LEFT JOIN food_translations ft_default
        ON ft_default.food_id = f.id AND ft_default.locale_code = 'uz_latn'
      LEFT JOIN category_translations ct_req
        ON ct_req.category_id = c.id AND ct_req.locale_code = ?
      LEFT JOIN category_translations ct_default
        ON ct_default.category_id = c.id AND ct_default.locale_code = 'uz_latn'
      LEFT JOIN food_nutrition_summary n ON n.food_id = f.id
      LEFT JOIN food_images img
        ON img.food_id = f.id AND img.is_primary = 1
      WHERE f.is_active = 1
      ORDER BY name COLLATE NOCASE
      ''',
      [_locale, _locale],
    );

    all
      ..clear()
      ..addAll(
        rows.map((row) {
          final id = (row['id'] as num).toInt();
          return Product.fromDbRow(row, microsByFoodId[id] ?? const {});
        }),
      );
    _loaded = true;
  }

  Future<Map<int, Map<String, num>>> _loadMicros(Database db) async {
    final rows = await db.rawQuery('''
      SELECT fn.food_id, n.code, fn.amount_per_100g
      FROM food_nutrients fn
      JOIN nutrients n ON n.id = fn.nutrient_id
      WHERE n.code NOT IN ('energy_kcal', 'protein', 'carbs', 'fat')
      ''');
    final out = <int, Map<String, num>>{};
    for (final row in rows) {
      final foodId = (row['food_id'] as num).toInt();
      final code = row['code'] as String;
      final amount = row['amount_per_100g'];
      if (amount is! num) continue;
      out.putIfAbsent(foodId, () => {})[code] = amount;
    }
    return out;
  }

  Future<String> _ensureDatabaseFile() async {
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    final dbPath = p.join(dir, _dbFileName);
    final file = File(dbPath);
    final assetData = await _loadAssetDatabase();
    if (!await file.exists() || await file.length() != assetData.length) {
      await _copyAssetDatabase(file, assetData);
    }
    return dbPath;
  }

  Future<Uint8List> _loadAssetDatabase() async {
    final bytes = await rootBundle.load(_assetPath);
    return Uint8List.fromList(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }

  Future<void> _copyAssetDatabase(File target, Uint8List data) async {
    await target.writeAsBytes(data, flush: true);
  }

  List<Product> search(
    String query, {
    bool recipesOnly = false,
    Set<String>? categorySlugs,
    int limit = 60,
  }) {
    final q = _normalizeSearchText(query);
    final queryTokens = _searchTokens(
      q,
    ).where((token) => !_isStopSearchToken(token)).toList();
    final selectedCategories = categorySlugs?.where((slug) => slug.isNotEmpty);
    final out = <Product>[];
    final matches = <_ProductSearchMatch>[];
    for (final product in all) {
      if (recipesOnly && !product.isRecipe) continue;
      if (selectedCategories != null &&
          selectedCategories.isNotEmpty &&
          !selectedCategories.contains(product.categorySlug)) {
        continue;
      }
      if (q.isEmpty) {
        out.add(product);
        if (out.length >= limit) break;
        continue;
      }
      if (queryTokens.isEmpty) continue;
      final score = _scoreProduct(product, q, queryTokens);
      if (score > 0) matches.add(_ProductSearchMatch(product, score));
    }
    if (q.isNotEmpty) {
      matches.sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        if (scoreOrder != 0) return scoreOrder;
        return a.product.nameSearchKey.compareTo(b.product.nameSearchKey);
      });
      for (final match in matches.take(limit)) {
        out.add(match.product);
      }
    }
    return out;
  }

  List<ProductCategory> categories({bool recipesOnly = false}) {
    final byGroup = <String, _CategoryCounter>{
      for (final definition in _categoryGroupDefinitions)
        definition.id: _CategoryCounter(
          _categoryGroupName(definition.id, _locale),
          {...definition.slugs},
        ),
    };
    for (final product in all) {
      if (recipesOnly && !product.isRecipe) continue;
      if (product.categorySlug.isEmpty || product.category.isEmpty) continue;
      final group = _categoryGroupForSlug(product.categorySlug);
      final counter = byGroup[group.id]!;
      counter.count++;
      counter.categorySlugs.add(product.categorySlug);
    }
    final categories = [
      for (final entry in byGroup.entries)
        if (entry.value.count > 0)
          ProductCategory(
            id: entry.key,
            name: entry.value.name,
            count: entry.value.count,
            categorySlugs: Set.unmodifiable(entry.value.categorySlugs),
          ),
    ];
    return categories;
  }

  Product? bySlug(String slug) {
    for (final product in all) {
      if (product.slug == slug) return product;
    }
    return null;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _loaded = false;
  }
}

class _ProductSearchMatch {
  final Product product;
  final int score;

  const _ProductSearchMatch(this.product, this.score);
}

class _CategoryCounter {
  final String name;
  final Set<String> categorySlugs;
  int count = 0;

  _CategoryCounter(this.name, this.categorySlugs);
}

class _CategoryGroupDefinition {
  final String id;
  final Set<String> slugs;

  const _CategoryGroupDefinition(this.id, this.slugs);
}

const _categoryGroupDefinitions = [
  _CategoryGroupDefinition('dishes', {
    'taomlar',
    'palov_va_uning_turlari',
    'somsa',
    'manti_va_barak',
    'kaboblar_va_shashliklar',
    'suyuq_taomlar',
    'xamirli_taomlar',
    'asosiy_taomlar',
    'salatlar_va_gazaklar',
    'salatlar',
    'milliy_taomlar',
    'main',
    'fastfood',
    'breakfast',
    'snack',
    'soup',
  }),
  _CategoryGroupDefinition('drinks', {'ichimliklar', 'drinks'}),
  _CategoryGroupDefinition('produce', {
    'sabzavotlar',
    'fruits',
    'mevalar',
    'mevalar_va_rezavorlar',
    'kokatlar',
    'kokatlar_va_sabzavotlar',
    'quruq_mevalar',
    'vegetables',
  }),
  _CategoryGroupDefinition('protein', {
    'gosht_mahsulotlari',
    'parranda_goshti',
    'baliq_va_dengiz_mahsulotlari',
    'subproduktlar',
    'tuxum',
    'sut_mahsulotlari',
    'meat',
    'fish',
    'dairy',
  }),
  _CategoryGroupDefinition('grains', {
    'don_va_dukkakli_mahsulotlar',
    'dukkaklilar',
    'grains',
    'legumes',
    'non_va_pishiriqlar',
    'non_mahsulotlari',
    'un_va_non_mahsulotlari',
    'bakery',
    'nuts',
    'yongoqlar',
    'uruglar',
    'yongoqlar_va_quruq_mevalar',
  }),
  _CategoryGroupDefinition('other', {
    'shirinliklar',
    'shirinliklar_va_desertlar',
    'sweets',
    'ziravor_va_qoshimchalar',
    'ziravorlar',
    'spices',
    'yoglar',
    'fats',
    'konservalar',
    'sport_ozuqalari',
    'supplements',
    'bolalar_ozuqalari',
    'boshqalar',
  }),
];

_CategoryGroupDefinition _categoryGroupForSlug(String slug) {
  for (final definition in _categoryGroupDefinitions) {
    if (definition.slugs.contains(slug)) return definition;
  }
  return _categoryGroupDefinitions.last;
}

String _categoryGroupName(String id, String localeCode) {
  return switch (localeCode) {
    'en' => switch (id) {
      'dishes' => 'Dishes',
      'drinks' => 'Drinks',
      'produce' => 'Fruits & vegetables',
      'protein' => 'Protein foods',
      'grains' => 'Grains & bread',
      _ => 'Sweets & other',
    },
    'uz_latn' => switch (id) {
      'dishes' => 'Taomlar',
      'drinks' => 'Ichimliklar',
      'produce' => 'Meva-sabzavot',
      'protein' => 'Oqsilli mahsulotlar',
      'grains' => 'Don va non',
      _ => 'Shirinlik/boshqa',
    },
    'uz_cyrl' => switch (id) {
      'dishes' => 'Таомлар',
      'drinks' => 'Ичимликлар',
      'produce' => 'Мева-сабзавот',
      'protein' => 'Оқсилли маҳсулотлар',
      'grains' => 'Дон ва нон',
      _ => 'Ширинлик/бошқа',
    },
    _ => switch (id) {
      'dishes' => 'Блюда',
      'drinks' => 'Напитки',
      'produce' => 'Фрукты и овощи',
      'protein' => 'Белковые продукты',
      'grains' => 'Крупы и хлеб',
      _ => 'Сладости и прочее',
    },
  };
}

String _normalizeSearchText(String value) {
  final buffer = StringBuffer();
  var lastWasSpace = true;

  for (final rawRune in value.toLowerCase().runes) {
    final rune = _normalizedSearchRune(rawRune);
    if (rune == _removedRune) continue;
    if (rune == null) {
      if (!lastWasSpace) {
        buffer.writeCharCode(0x20);
        lastWasSpace = true;
      }
      continue;
    }
    buffer.writeCharCode(rune);
    lastWasSpace = false;
  }

  return buffer.toString().trim();
}

String _buildSearchIndex(String value) {
  final normalized = _normalizeSearchText(value);
  if (normalized.isEmpty) return '';

  final variants = <String>{normalized};
  if (_containsCyrillic(normalized)) {
    variants.add(_transliterateCyrillicToLatin(normalized, ha: 'h'));
    variants.add(_transliterateCyrillicToLatin(normalized, ha: 'kh'));
    variants.add(_transliterateCyrillicToLatin(normalized, ha: 'x'));
  }

  return variants.where((variant) => variant.isNotEmpty).join(' ');
}

const _removedRune = -1;

int? _normalizedSearchRune(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return rune;
  if (rune >= 0x61 && rune <= 0x7a) return rune;
  if (rune >= 0x0430 && rune <= 0x044f) return rune;

  return switch (rune) {
    0x0027 ||
    0x0060 ||
    0x00b4 ||
    0x02bb ||
    0x02bc ||
    0x2018 ||
    0x2019 => _removedRune,
    0x0451 => 0x0435, // yo -> e
    0x045e => 0x0443, // short u -> u
    0x0493 => 0x0433, // ghe -> ge
    0x049b => 0x043a, // qa -> ka
    0x04b3 => 0x0445, // ha -> kha
    _ => null,
  };
}

List<String> _searchTokens(String value) {
  final normalized = _normalizeSearchText(value);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ');
}

bool _isStopSearchToken(String token) {
  return token.length == 1 ||
      const {'and', 'with', 'va', 'bilan', 'i', 'и', 'с'}.contains(token);
}

bool _containsCyrillic(String value) {
  for (final rune in value.runes) {
    if (rune >= 0x0430 && rune <= 0x044f) return true;
  }
  return false;
}

String _transliterateCyrillicToLatin(String value, {required String ha}) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    buffer.write(_cyrillicRuneToLatin(rune, ha: ha));
  }
  return _normalizeSearchText(buffer.toString());
}

String _cyrillicRuneToLatin(int rune, {required String ha}) {
  return switch (rune) {
    0x0430 => 'a',
    0x0431 => 'b',
    0x0432 => 'v',
    0x0433 => 'g',
    0x0434 => 'd',
    0x0435 => 'e',
    0x0436 => 'zh',
    0x0437 => 'z',
    0x0438 => 'i',
    0x0439 => 'y',
    0x043a => 'k',
    0x043b => 'l',
    0x043c => 'm',
    0x043d => 'n',
    0x043e => 'o',
    0x043f => 'p',
    0x0440 => 'r',
    0x0441 => 's',
    0x0442 => 't',
    0x0443 => 'u',
    0x0444 => 'f',
    0x0445 => ha,
    0x0446 => 'ts',
    0x0447 => 'ch',
    0x0448 => 'sh',
    0x0449 => 'sh',
    0x044b => 'y',
    0x044d => 'e',
    0x044e => 'yu',
    0x044f => 'ya',
    0x044a || 0x044c => '',
    _ => String.fromCharCode(rune),
  };
}

int _scoreProduct(
  Product product,
  String normalizedQuery,
  List<String> queryTokens,
) {
  if (queryTokens.isEmpty) return 1;

  var score = 0;
  for (final token in queryTokens) {
    final tokenScore = _scoreToken(product, token);
    if (tokenScore == 0) return 0;
    score += tokenScore;
  }

  if (product.nameSearchKey == normalizedQuery) {
    score += 500;
  } else if (product.nameSearchKey.startsWith(normalizedQuery)) {
    score += 320;
  } else if (product.nameSearchKey.contains(normalizedQuery)) {
    score += 240;
  } else if (product.searchKey.contains(normalizedQuery)) {
    score += 120;
  }

  if (_tokensAppearInOrder(product.nameSearchTokens, queryTokens)) {
    score += 90;
  } else if (_tokensAppearInOrder(product.searchTokens, queryTokens)) {
    score += 35;
  }

  return score;
}

int _scoreToken(Product product, String token) {
  if (product.nameSearchTokenSet.contains(token)) return 90;
  if (product.searchTokenSet.contains(token)) return 65;
  if (product.categorySearchTokenSet.contains(token)) return 30;

  if (token.length >= 2 &&
      product.nameSearchTokens.any(
        (candidate) => candidate.startsWith(token),
      )) {
    return 55;
  }
  if (token.length >= 2 &&
      product.searchTokens.any((candidate) => candidate.startsWith(token))) {
    return 30;
  }
  if (token.length >= 4 &&
      product.nameSearchTokens.any((candidate) => candidate.contains(token))) {
    return 25;
  }
  if (token.length >= 4 &&
      product.searchTokens.any((candidate) => candidate.contains(token))) {
    return 10;
  }

  return 0;
}

bool _tokensAppearInOrder(List<String> source, List<String> query) {
  if (query.isEmpty) return false;
  var queryIndex = 0;
  for (final token in source) {
    if (token == query[queryIndex]) {
      queryIndex++;
      if (queryIndex == query.length) return true;
    }
  }
  return false;
}
