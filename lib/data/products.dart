import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A product from the offline database (assets/foods.json).
class Product {
  final String slug;
  final String name;
  final String? emoji;
  final String category;
  final String unit;
  final num gramsPerUnit;
  final bool isRecipe;
  final int kcal; // per 100 г
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, num> micros; // per 100 г

  Product({
    required this.slug,
    required this.name,
    this.emoji,
    required this.category,
    required this.unit,
    required this.gramsPerUnit,
    required this.isRecipe,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.micros = const {},
  });

  /// Lower-cased name for case-insensitive search (cached at load).
  late final String searchKey = name.toLowerCase();

  static Product fromJson(Map<String, dynamic> j) {
    final per = (j['per_100g'] as Map?) ?? const {};
    final micros = <String, num>{};
    final rawMicros = per['micros'];
    if (rawMicros is Map) {
      rawMicros.forEach((k, v) {
        if (v is num) micros[k as String] = v;
      });
    }
    final name = (j['name_ru'] as String?)?.trim().isNotEmpty == true
        ? j['name_ru'] as String
        : (j['name_uz'] as String? ?? j['slug'] as String);
    final emoji = j['emoji'] as String?;
    return Product(
      slug: j['slug'] as String,
      name: name,
      emoji: (emoji != null && emoji.isNotEmpty && emoji != '??') ? emoji : null,
      category: (j['category'] as String?) ?? '',
      unit: (j['default_unit'] as String?) ?? 'g',
      gramsPerUnit: (j['grams_per_unit'] as num?) ?? 100,
      isRecipe: per['type'] == 'recipe',
      kcal: ((per['kcal'] as num?) ?? 0).round(),
      protein: ((per['protein'] as num?) ?? 0).toDouble(),
      carbs: ((per['carbs'] as num?) ?? 0).toDouble(),
      fat: ((per['fat'] as num?) ?? 0).toDouble(),
      micros: micros,
    );
  }
}

/// Loads and searches the offline product database. One instance, loaded once
/// at startup; everything is in memory so search is instant and offline.
class FoodDb {
  FoodDb._();
  static final FoodDb instance = FoodDb._();

  final List<Product> all = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/foods.json');
    final list = jsonDecode(raw) as List;
    all
      ..clear()
      ..addAll(list.map((e) => Product.fromJson(e as Map<String, dynamic>)));
    all.sort((a, b) => a.name.compareTo(b.name));
    _loaded = true;
  }

  /// Case-insensitive name search. Empty query returns the first [limit] items.
  List<Product> search(String query, {bool recipesOnly = false, int limit = 60}) {
    final q = query.trim().toLowerCase();
    final out = <Product>[];
    for (final p in all) {
      if (recipesOnly && !p.isRecipe) continue;
      if (q.isEmpty || p.searchKey.contains(q)) {
        out.add(p);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  Product? bySlug(String slug) {
    for (final p in all) {
      if (p.slug == slug) return p;
    }
    return null;
  }
}
