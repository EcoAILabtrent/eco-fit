import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
  });

  late final String searchKey = [
    name,
    category,
    slug.replaceAll('_', ' '),
  ].join(' ').toLowerCase();

  bool get hasImage =>
      imageAssetPath != null || imageStoragePath != null || imageRemoteUrl != null;

  String get displayUnit {
    return switch (unit) {
      'ml' => 'мл',
      'l' => 'л',
      'piece' => 'шт',
      'portion' => 'порция',
      _ => 'г',
    };
  }

  String get calorieBaseLabel => 'ккал/100 $displayUnit';

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
    );
  }

  static String? _nonEmpty(Object? value) {
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
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
  static const _locale = 'uz_latn';

  final List<Product> all = [];
  Database? _db;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final path = await _ensureDatabaseFile();
    final db = await openDatabase(path, readOnly: false);
    _db = db;

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
        img.remote_url AS primary_image_remote_url
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
      ..addAll(rows.map((row) {
        final id = (row['id'] as num).toInt();
        return Product.fromDbRow(row, microsByFoodId[id] ?? const {});
      }));
    _loaded = true;
  }

  Future<Map<int, Map<String, num>>> _loadMicros(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT fn.food_id, n.code, fn.amount_per_100g
      FROM food_nutrients fn
      JOIN nutrients n ON n.id = fn.nutrient_id
      WHERE n.code NOT IN ('energy_kcal', 'protein', 'carbs', 'fat')
      ''',
    );
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

  List<Product> search(String query, {bool recipesOnly = false, int limit = 60}) {
    final q = query.trim().toLowerCase();
    final out = <Product>[];
    for (final product in all) {
      if (recipesOnly && !product.isRecipe) continue;
      if (q.isEmpty || product.searchKey.contains(q)) {
        out.add(product);
        if (out.length >= limit) break;
      }
    }
    return out;
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
