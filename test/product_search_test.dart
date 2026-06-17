import 'package:eco_mobile/data/products.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FoodDb.instance.all.clear();
  });

  tearDown(() {
    FoodDb.instance.all.clear();
  });

  test('matches product name terms in any order', () {
    FoodDb.instance.all.add(
      _product(
        slug: 'oq_non',
        name:
            '\u0431\u0435\u043b\u044b\u0439 \u0445\u043b\u0435\u0431 '
            '(\u0431\u0443\u043b\u043e\u0447\u043a\u0430)',
        category: '\u0412\u044b\u043f\u0435\u0447\u043a\u0430',
        categorySlug: 'bakery',
      ),
    );

    final results = FoodDb.instance.search(
      '\u0445\u043b\u0435\u0431 \u0431\u0435\u043b\u044b\u0439',
    );

    expect(results.map((product) => product.slug), contains('oq_non'));
  });

  test('matches cyrillic names through latin transliteration', () {
    FoodDb.instance.all.add(
      _product(
        slug: 'oq_non',
        name:
            '\u0431\u0435\u043b\u044b\u0439 \u0445\u043b\u0435\u0431 '
            '(\u0431\u0443\u043b\u043e\u0447\u043a\u0430)',
        category: '\u0412\u044b\u043f\u0435\u0447\u043a\u0430',
        categorySlug: 'bakery',
      ),
    );

    final results = FoodDb.instance.search('hleb belyy');

    expect(results.map((product) => product.slug), contains('oq_non'));
  });

  test('matches sh/ch transliteration for cyrillic dish names', () {
    FoodDb.instance.all.add(
      _product(
        slug: 'shurva',
        name: '\u0448\u0443\u0440\u0432\u0430',
        category: '\u0411\u043b\u044e\u0434\u0430',
        categorySlug: 'taomlar',
      ),
    );

    final results = FoodDb.instance.search('shurva');

    expect(results.single.slug, 'shurva');
  });

  test('does not match weak random three-letter fragments', () {
    FoodDb.instance.all.add(
      _product(
        slug: 'shashlik_qiyma_qoy',
        name: "Shashlik qiyma qo'y",
        category: 'Kaboblar va shashliklar',
        categorySlug: 'kaboblar_va_shashliklar',
      ),
    );

    final results = FoodDb.instance.search('vae');

    expect(results, isEmpty);
  });

  test('uses all locale search text, not only the visible name', () {
    FoodDb.instance.all.add(
      _product(
        slug: 'oq_non',
        name: 'Oq non',
        category: 'Non mahsulotlari',
        categorySlug: 'non_mahsulotlari',
        searchText:
            '\u0431\u0435\u043b\u044b\u0439 \u0445\u043b\u0435\u0431 '
            'white bread',
      ),
    );

    final results = FoodDb.instance.search(
      '\u0445\u043b\u0435\u0431 \u0431\u0435\u043b\u044b\u0439',
    );

    expect(results.single.slug, 'oq_non');
  });

  test('filters by category slug', () {
    FoodDb.instance.all
      ..add(
        _product(
          slug: 'oq_non',
          name: 'Oq non',
          category: 'Non mahsulotlari',
          categorySlug: 'non_mahsulotlari',
        ),
      )
      ..add(
        _product(
          slug: 'olma',
          name: 'Olma',
          category: 'Mevalar',
          categorySlug: 'mevalar',
        ),
      );

    final results = FoodDb.instance.search(
      '',
      categorySlugs: {'non_mahsulotlari'},
    );

    expect(results.map((product) => product.slug), ['oq_non']);
  });

  test('combines multiple selected category filters', () {
    FoodDb.instance.all
      ..add(
        _product(
          slug: 'shurva',
          name: 'Shurva',
          category: 'Dishes',
          categorySlug: 'taomlar',
        ),
      )
      ..add(
        _product(
          slug: 'suv',
          name: 'Water',
          category: 'Drinks',
          categorySlug: 'ichimliklar',
        ),
      )
      ..add(
        _product(
          slug: 'olma',
          name: 'Apple',
          category: 'Fruit',
          categorySlug: 'mevalar',
        ),
      );

    final results = FoodDb.instance.search(
      '',
      categorySlugs: {'taomlar', 'ichimliklar'},
    );

    expect(results.map((product) => product.slug), ['shurva', 'suv']);
  });

  test('groups close product categories into main filters', () {
    FoodDb.instance.all
      ..add(
        _product(
          slug: 'bodom',
          name: 'Bodom',
          category: "Yong'oqlar",
          categorySlug: 'yongoqlar',
        ),
      )
      ..add(
        _product(
          slug: 'kungaboqar_urugi',
          name: "Kungaboqar urug'i",
          category: "Urug'lar",
          categorySlug: 'uruglar',
        ),
      )
      ..add(
        _product(
          slug: 'quruq_meva',
          name: 'Quruq meva',
          category: 'Quruq mevalar',
          categorySlug: 'quruq_mevalar',
        ),
      );

    final categories = FoodDb.instance.categories();

    expect(categories.map((category) => category.id), contains('grains'));
    expect(
      categories.map((category) => category.name),
      isNot(contains("Yong'oqlar")),
    );
    expect(
      categories.singleWhere((category) => category.id == 'grains').count,
      2,
    );
  });
}

Product _product({
  required String slug,
  required String name,
  required String category,
  required String categorySlug,
  String searchText = '',
}) {
  return Product(
    id: slug.hashCode,
    slug: slug,
    name: name,
    category: category,
    categorySlug: categorySlug,
    typeCode: 'food',
    unit: 'g',
    gramsPerUnit: 100,
    isRecipe: false,
    isDrink: false,
    kcal: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    searchText: searchText,
  );
}
