import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../l10n/app_language.dart';
import '../steps/steps_service.dart';

/// Meal definitions (Журнал питания) — from the Eco design store.
class Meal {
  final String key;
  final String label;
  final String time;
  const Meal(this.key, this.label, this.time);
}

const kMeals = [
  Meal('breakfast', 'Завтрак', '08:30'),
  Meal('lunch', 'Обед', '14:30'),
  Meal('dinner', 'Ужин', '19:00'),
  Meal('snackM', 'Утренний перекус', '11:00'),
  Meal('snackD', 'Дневной перекус', '16:30'),
  Meal('snackE', 'Вечерний перекус', '21:30'),
];

/// Meals in chronological day order (breakfast → … → evening snack).
final kMealsByTime = [...kMeals]..sort((a, b) => a.time.compareTo(b.time));

class LogItem {
  final String name;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, double> micros;
  const LogItem(
    this.name,
    this.kcal, {
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.micros = const {},
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'kcal': kcal,
    'p': protein,
    'c': carbs,
    'f': fat,
    'm': micros,
  };
  static LogItem fromMap(Map m) => LogItem(
    m['name'] as String,
    (m['kcal'] as num).toInt(),
    protein: (m['p'] as num?)?.toDouble() ?? 0,
    carbs: (m['c'] as num?)?.toDouble() ?? 0,
    fat: (m['f'] as num?)?.toDouble() ?? 0,
    micros: _microsFromMap(m['m']),
  );

  static Map<String, double> _microsFromMap(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(
        key as String,
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0,
      ),
    );
  }
}

/// App state — mirrors the Eco design INITIAL store, persisted to Hive so the
/// app is fully offline-first. Supabase sync attaches on top of this later.
class AppStore extends ChangeNotifier {
  static const _boxName = 'eco';
  static const _seedDemoFood = bool.fromEnvironment('SEED_DEMO_FOOD');
  static const _resetDemoFood = bool.fromEnvironment('SEED_DEMO_FOOD_RESET');
  late Box _box;

  // Home dashboard metrics
  int water = 0; // мл
  int waterGoal = 2000;
  int steps = 0;
  int stepsGoal = 10000;
  double weight = 0;
  String? recFeedback; // 'up' | 'down'
  AppLanguage language = AppLanguage.ru;

  // Food diary keyed by date: ymd -> (meal.key -> items).
  Map<String, Map<String, List<LogItem>>> diary = {};
  Set<String> favoriteProductSlugs = {};

  /// "YYYY-MM-DD" key for a date (local), default today.
  static String ymd([DateTime? d]) {
    final x = d ?? DateTime.now();
    return '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  Map<String, List<LogItem>> _day(String date) =>
      diary.putIfAbsent(date, () => {});

  // Custom meal times (meal.key -> "HH:mm"); defaults come from kMeals.
  Map<String, String> mealTimes = {};

  int goalKcal = 2045;

  // Health detail metrics
  String? pressure; // "120/80"
  double? sugar; // мг/дл
  double bodyFat = 17.5; // %
  double skeletalMuscle = 30.2; // кг

  // Macro goals in grams (set from target kcal at onboarding).
  int carbGoal = 230;
  int fatGoal = 60;
  int protGoal = 150;

  // Onboarding profile
  bool onboarded = false;
  String? gender;
  int? age;
  int? heightCm;
  double? weightKg;
  String? activity;
  String? goal; // lose | keep | gain

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    water = _box.get('water', defaultValue: 0) as int;
    waterGoal = _box.get('waterGoal', defaultValue: 2000) as int;
    steps = _box.get('steps', defaultValue: 0) as int;
    stepsGoal = _box.get('stepsGoal', defaultValue: 10000) as int;
    weight = (_box.get('weight', defaultValue: 0.0) as num).toDouble();
    pressure = _box.get('pressure') as String?;
    sugar = (_box.get('sugar') as num?)?.toDouble();
    bodyFat = (_box.get('bodyFat', defaultValue: 17.5) as num).toDouble();
    skeletalMuscle = (_box.get('skeletalMuscle', defaultValue: 30.2) as num)
        .toDouble();
    language = AppLanguage.fromCode(
      _box.get('language', defaultValue: AppLanguage.ru.code) as String?,
    );
    goalKcal = _box.get('goalKcal', defaultValue: 2045) as int;
    carbGoal = _box.get('carbGoal', defaultValue: 230) as int;
    fatGoal = _box.get('fatGoal', defaultValue: 60) as int;
    protGoal = _box.get('protGoal', defaultValue: 150) as int;
    onboarded = _box.get('onboarded', defaultValue: false) as bool;
    final rawFavorites = _box.get('favoriteProductSlugs');
    if (rawFavorites is List) {
      favoriteProductSlugs = rawFavorites.whereType<String>().toSet();
    }
    final rawTimes = _box.get('mealTimes');
    if (rawTimes is Map) {
      mealTimes = rawTimes.map((k, v) => MapEntry(k as String, v as String));
    }
    final rawDiary = _box.get('diary');
    if (rawDiary is Map) {
      diary = rawDiary.map(
        (date, meals) => MapEntry(
          date as String,
          (meals as Map).map(
            (mk, items) => MapEntry(
              mk as String,
              (items as List).map((e) => LogItem.fromMap(e as Map)).toList(),
            ),
          ),
        ),
      );
    } else {
      // Migrate the old flat log (meal -> items) into today's diary entry.
      final rawLog = _box.get('log');
      if (rawLog is Map) {
        _day(ymd()).addAll(
          rawLog.map(
            (k, v) => MapEntry(
              k as String,
              (v as List).map((e) => LogItem.fromMap(e as Map)).toList(),
            ),
          ),
        );
      }
    }
    if (_seedDemoFood) _seedDemoFood30Days();
    notifyListeners();
  }

  void _persist() {
    _box.put('water', water);
    _box.put('waterGoal', waterGoal);
    _box.put('steps', steps);
    _box.put('stepsGoal', stepsGoal);
    _box.put('weight', weight);
    _box.put('pressure', pressure);
    _box.put('sugar', sugar);
    _box.put('bodyFat', bodyFat);
    _box.put('skeletalMuscle', skeletalMuscle);
    _box.put('language', language.code);
    _box.put('goalKcal', goalKcal);
    _box.put('carbGoal', carbGoal);
    _box.put('fatGoal', fatGoal);
    _box.put('protGoal', protGoal);
    _box.put('onboarded', onboarded);
    _box.put('favoriteProductSlugs', favoriteProductSlugs.toList());
    _box.put(
      'diary',
      diary.map(
        (date, meals) => MapEntry(
          date,
          meals.map(
            (mk, items) => MapEntry(mk, items.map((e) => e.toMap()).toList()),
          ),
        ),
      ),
    );
    _box.put('mealTimes', mealTimes);
  }

  bool isFavoriteProduct(String slug) => favoriteProductSlugs.contains(slug);

  void toggleFavoriteProduct(String slug) {
    if (!favoriteProductSlugs.add(slug)) {
      favoriteProductSlugs.remove(slug);
    }
    _box.put('favoriteProductSlugs', favoriteProductSlugs.toList());
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage next) async {
    if (language == next) return;
    language = next;
    await _box.put('language', next.code);
    notifyListeners();
  }

  String mealTime(String mealKey) =>
      mealTimes[mealKey] ??
      kMeals
          .firstWhere((m) => m.key == mealKey, orElse: () => kMeals.first)
          .time;

  void setMealTime(String mealKey, String time) {
    mealTimes[mealKey] = time;
    _persist();
    notifyListeners();
  }

  /// Items logged for a meal on a date (default today).
  List<LogItem> itemsFor(String mealKey, {String? date}) =>
      diary[date ?? ymd()]?[mealKey] ?? const [];

  int consumedOn([String? date]) => (diary[date ?? ymd()] ?? const {}).values
      .expand((items) => items)
      .fold(0, (sum, e) => sum + e.kcal);

  int get consumed => consumedOn();

  int mealKcal(String mealKey, {String? date}) =>
      itemsFor(mealKey, date: date).fold(0, (sum, e) => sum + e.kcal);

  /// Consumed macros in grams for a date (default today).
  ({double protein, double carbs, double fat}) macrosOn([String? date]) {
    double p = 0, c = 0, f = 0;
    for (final items in (diary[date ?? ymd()] ?? const {}).values) {
      for (final e in items) {
        p += e.protein;
        c += e.carbs;
        f += e.fat;
      }
    }
    return (protein: p, carbs: c, fat: f);
  }

  ({double protein, double carbs, double fat}) get macros => macrosOn();

  /// Consumed micronutrients for a date (keys match Product.micros codes).
  Map<String, double> microsOn([String? date]) {
    final out = <String, double>{};
    for (final items in (diary[date ?? ymd()] ?? const {}).values) {
      for (final item in items) {
        for (final entry in item.micros.entries) {
          out.update(
            entry.key,
            (current) => current + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }
    }
    return out;
  }

  // ── Independent pedometer ──

  StreamSubscription<int>? _liveSteps;
  bool stepsPermission = false;

  /// Silent sync at startup/resume; no permission prompt.
  Future<void> syncSteps() async {
    stepsPermission = await StepsService.instance.checkPermission();
    if (!stepsPermission) {
      notifyListeners();
      return;
    }
    final n = await StepsService.instance.getTodaySteps();
    if (n != null && n != steps) {
      steps = n;
      _persist();
    }
    _startLiveSteps();
    notifyListeners();
  }

  /// Tap on the Шаги card: ask permission if needed, then sync + go live.
  Future<bool> enableSteps() async {
    final ok = await StepsService.instance.requestPermission();
    if (ok) await syncSteps();
    return ok;
  }

  void _startLiveSteps() {
    _liveSteps ??= StepsService.instance.liveSteps().listen((n) {
      if (n == steps) return;
      steps = n;
      _persist();
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _liveSteps?.cancel();
    super.dispose();
  }

  void addWater(int ml) {
    water = (water + ml).clamp(0, 100000);
    _persist();
    notifyListeners();
  }

  /// ± buttons on the water screen clamp to the [0, goal] range (per design).
  void stepWater(int delta) {
    water = (water + delta).clamp(0, waterGoal);
    _persist();
    notifyListeners();
  }

  void setWeight(double kg) {
    weight = kg;
    weightKg = kg;
    _persist();
    notifyListeners();
  }

  void setBodyComposition({double? bodyFat, double? skeletalMuscle}) {
    if (bodyFat != null) this.bodyFat = bodyFat;
    if (skeletalMuscle != null) this.skeletalMuscle = skeletalMuscle;
    _persist();
    notifyListeners();
  }

  void setPressureFull(int sys, int dia) {
    pressure = '$sys/$dia';
    _persist();
    notifyListeners();
  }

  void setRecFeedback(String? v) {
    recFeedback = recFeedback == v ? null : v;
    notifyListeners();
  }

  void setPressure(String v) {
    pressure = v;
    _persist();
    notifyListeners();
  }

  void setSugar(double v) {
    sugar = v;
    _persist();
    notifyListeners();
  }

  void addFood(String mealKey, LogItem item, {String? date}) {
    _day(date ?? ymd()).putIfAbsent(mealKey, () => []).add(item);
    _persist();
    notifyListeners();
  }

  void removeFood(String mealKey, int index, {String? date}) {
    final items = diary[date ?? ymd()]?[mealKey];
    if (items == null || index < 0 || index >= items.length) return;
    items.removeAt(index);
    _persist();
    notifyListeners();
  }

  void completeOnboarding({
    required String gender,
    required int age,
    required int heightCm,
    required double weightKg,
    required String activity,
    required String goal,
    required int targetKcal,
  }) {
    this.gender = gender;
    this.age = age;
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    weight = weightKg;
    this.activity = activity;
    this.goal = goal;
    goalKcal = targetKcal;
    // Standard 45/30/25 split → grams (carbs & protein 4 kcal/г, fat 9 kcal/г).
    carbGoal = (targetKcal * 0.45 / 4).round();
    protGoal = (targetKcal * 0.30 / 4).round();
    fatGoal = (targetKcal * 0.25 / 9).round();
    onboarded = true;
    _persist();
    notifyListeners();
  }

  void _seedDemoFood30Days() {
    final alreadySeeded =
        _box.get('demoFoodSeeded30Days', defaultValue: false) as bool;
    if (alreadySeeded && !_resetDemoFood) return;

    if (!onboarded) {
      gender = 'm';
      age = 28;
      heightCm = 178;
      weightKg = 66;
      weight = 66;
      activity = 'mid';
      goal = 'lose';
      goalKcal = 1975;
      carbGoal = (goalKcal * 0.45 / 4).round();
      protGoal = (goalKcal * 0.30 / 4).round();
      fatGoal = (goalKcal * 0.25 / 9).round();
      onboarded = true;
    }

    final today = DateTime.now();
    for (var offset = 29; offset >= 0; offset--) {
      final date = ymd(today.subtract(Duration(days: offset)));
      if (!_resetDemoFood && (diary[date]?.isNotEmpty ?? false)) continue;
      final meals = <String, List<LogItem>>{};
      _fillDemoDay(meals, 29 - offset);
      diary[date] = meals;
    }

    recFeedback = null;
    _box.put('demoFoodSeeded30Days', true);
    _box.put('demoFoodSeededAt', ymd());
    _persist();
  }

  void _fillDemoDay(Map<String, List<LogItem>> meals, int dayIndex) {
    final pattern = dayIndex % 7;
    final lightFactor = dayIndex % 10 == 2 ? 0.82 : 1.0;
    final activeFactor = dayIndex % 9 == 4 ? 1.12 : 1.0;
    final factor = lightFactor * activeFactor;
    void add(String meal, _DemoFood food, num grams) =>
        _addDemoFood(meals, meal, food, grams * factor);

    switch (pattern) {
      case 0:
        add('breakfast', _oats, 65);
        add('breakfast', _greekYogurt, 170);
        add('breakfast', _banana, 120);
        add('lunch', _chickenBreast, 170);
        add('lunch', _riceCooked, 190);
        add('lunch', _vegetableSalad, 180);
        add('lunch', _oliveOil, 10);
        add('snackD', _apple, 170);
        add('snackD', _almonds, 20);
        add('dinner', _salmon, 150);
        add('dinner', _buckwheatCooked, 160);
        add('dinner', _broccoli, 160);
      case 1:
        add('breakfast', _eggs, 110);
        add('breakfast', _wholeWheatBread, 70);
        add('breakfast', _tomato, 130);
        add('lunch', _lentilsCooked, 230);
        add('lunch', _vegetableSalad, 180);
        add('snackD', _kefir, 250);
        add('dinner', _turkey, 150);
        add('dinner', _potatoBoiled, 240);
        add('dinner', _cucumber, 120);
      case 2:
        add('breakfast', _oats, 45);
        add('breakfast', _banana, 100);
        add('lunch', _plov, 260);
        add('lunch', _bread, 60);
        add('snackD', _sweetTea, 250);
        add('snackD', _cookies, 45);
        add('dinner', _soup, 350);
        add('dinner', _cheese, 40);
      case 3:
        add('breakfast', _cottageCheese, 220);
        add('breakfast', _berries, 120);
        add('lunch', _beefLean, 160);
        add('lunch', _buckwheatCooked, 180);
        add('lunch', _vegetableSalad, 220);
        add('snackD', _apple, 160);
        add('dinner', _chickenBreast, 150);
        add('dinner', _broccoli, 220);
        add('dinner', _oliveOil, 8);
      case 4:
        add('breakfast', _eggs, 120);
        add('breakfast', _cheese, 35);
        add('breakfast', _bread, 70);
        add('lunch', _fishWhite, 190);
        add('lunch', _riceCooked, 210);
        add('lunch', _vegetableSalad, 160);
        add('snackD', _yogurtSweet, 180);
        add('dinner', _lentilsCooked, 220);
        add('dinner', _potatoBoiled, 180);
      case 5:
        add('breakfast', _oats, 40);
        add('breakfast', _apple, 150);
        add('lunch', _riceCooked, 230);
        add('lunch', _vegetableSalad, 120);
        add('snackD', _banana, 120);
        add('dinner', _soup, 300);
        add('dinner', _bread, 45);
      case 6:
        add('breakfast', _greekYogurt, 200);
        add('breakfast', _berries, 130);
        add('breakfast', _almonds, 18);
        add('lunch', _turkey, 170);
        add('lunch', _buckwheatCooked, 190);
        add('lunch', _broccoli, 170);
        add('snackD', _kefir, 250);
        add('dinner', _salmon, 130);
        add('dinner', _vegetableSalad, 220);
        add('dinner', _potatoBoiled, 160);
    }
  }

  void _addDemoFood(
    Map<String, List<LogItem>> meals,
    String meal,
    _DemoFood food,
    num grams,
  ) {
    meals.putIfAbsent(meal, () => []).add(food.portion(grams));
  }
}

class _DemoFood {
  final String name;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, double> micros;

  const _DemoFood(
    this.name,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.micros,
  );

  LogItem portion(num grams) {
    final g = grams.toDouble();
    return LogItem(
      '$name ${g.round()} g',
      (kcal * g / 100).round(),
      protein: _round(protein * g / 100),
      carbs: _round(carbs * g / 100),
      fat: _round(fat * g / 100),
      micros: {
        for (final entry in micros.entries)
          entry.key: _round(entry.value * g / 100),
      },
    );
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(2));
}

const _oats = _DemoFood('Oats', 389, 16.9, 66.3, 6.9, {
  'fe': 4.7,
  'mg': 177,
  'ca': 54,
  'k': 429,
  'zn': 4.0,
});
const _greekYogurt = _DemoFood('Greek yogurt', 73, 10.0, 3.9, 2.0, {
  'ca': 115,
  'p': 140,
  'k': 141,
});
const _banana = _DemoFood('Banana', 89, 1.1, 22.8, 0.3, {
  'k': 358,
  'mg': 27,
  'vit_c': 8.7,
});
const _chickenBreast = _DemoFood('Chicken breast', 165, 31.0, 0, 3.6, {
  'p': 228,
  'k': 256,
  'zn': 1.0,
});
const _riceCooked = _DemoFood('Cooked rice', 130, 2.7, 28.2, 0.3, {
  'mg': 12,
  'p': 43,
  'k': 35,
});
const _vegetableSalad = _DemoFood('Vegetable salad', 32, 1.2, 5.8, 0.4, {
  'vit_c': 25,
  'vit_a': 180,
  'k': 220,
  'ca': 35,
});
const _oliveOil = _DemoFood('Olive oil', 884, 0, 0, 100, {});
const _apple = _DemoFood('Apple', 52, 0.3, 13.8, 0.2, {'vit_c': 4.6, 'k': 107});
const _almonds = _DemoFood('Almonds', 579, 21.2, 21.6, 49.9, {
  'mg': 270,
  'ca': 269,
  'fe': 3.7,
  'zn': 3.1,
});
const _salmon = _DemoFood('Salmon', 208, 20.0, 0, 13.0, {
  'vit_d': 10.9,
  'p': 252,
  'k': 363,
});
const _buckwheatCooked = _DemoFood('Cooked buckwheat', 92, 3.4, 19.9, 0.6, {
  'mg': 51,
  'fe': 0.8,
  'k': 88,
});
const _broccoli = _DemoFood('Broccoli', 35, 2.4, 7.2, 0.4, {
  'vit_c': 89,
  'vit_a': 31,
  'ca': 47,
  'k': 316,
});
const _eggs = _DemoFood('Eggs', 155, 13.0, 1.1, 11.0, {
  'vit_d': 2.0,
  'vit_a': 160,
  'p': 198,
  'zn': 1.3,
});
const _wholeWheatBread = _DemoFood('Whole wheat bread', 247, 13.0, 41.0, 4.2, {
  'fe': 3.6,
  'mg': 82,
  'zn': 2.0,
});
const _tomato = _DemoFood('Tomato', 18, 0.9, 3.9, 0.2, {
  'vit_c': 13.7,
  'vit_a': 42,
  'k': 237,
});
const _lentilsCooked = _DemoFood('Cooked lentils', 116, 9.0, 20.1, 0.4, {
  'fe': 3.3,
  'mg': 36,
  'k': 369,
  'zn': 1.3,
});
const _kefir = _DemoFood('Kefir', 50, 3.4, 4.7, 2.0, {
  'ca': 120,
  'p': 95,
  'k': 150,
});
const _turkey = _DemoFood('Turkey breast', 135, 29.0, 0, 1.5, {
  'p': 230,
  'k': 240,
  'zn': 1.5,
});
const _potatoBoiled = _DemoFood('Boiled potato', 87, 1.9, 20.1, 0.1, {
  'k': 379,
  'vit_c': 13,
  'mg': 22,
});
const _cucumber = _DemoFood('Cucumber', 15, 0.7, 3.6, 0.1, {
  'k': 147,
  'vit_c': 2.8,
});
const _plov = _DemoFood('Plov', 210, 7.5, 24.0, 9.5, {
  'na': 480,
  'fe': 1.5,
  'zn': 1.8,
});
const _bread = _DemoFood('White bread', 265, 8.7, 49.0, 3.2, {
  'na': 491,
  'fe': 3.6,
});
const _sweetTea = _DemoFood('Sweet tea', 32, 0, 8.0, 0, {});
const _cookies = _DemoFood('Cookies', 480, 6.0, 68.0, 20.0, {'na': 320});
const _soup = _DemoFood('Vegetable soup', 45, 2.0, 7.0, 1.3, {
  'na': 360,
  'k': 180,
  'vit_a': 120,
});
const _cheese = _DemoFood('Cheese', 402, 25.0, 1.3, 33.0, {
  'ca': 721,
  'p': 512,
  'na': 621,
  'zn': 3.1,
});
const _cottageCheese = _DemoFood('Cottage cheese', 98, 11.1, 3.4, 4.3, {
  'ca': 83,
  'p': 159,
  'k': 104,
});
const _berries = _DemoFood('Berries', 57, 0.7, 14.5, 0.3, {
  'vit_c': 35,
  'k': 153,
});
const _beefLean = _DemoFood('Lean beef', 187, 29.0, 0, 7.0, {
  'fe': 2.6,
  'zn': 6.0,
  'p': 210,
});
const _fishWhite = _DemoFood('White fish', 105, 22.0, 0, 1.2, {
  'p': 200,
  'k': 300,
});
const _yogurtSweet = _DemoFood('Sweet yogurt', 95, 4.0, 15.0, 2.2, {
  'ca': 110,
  'p': 95,
});
