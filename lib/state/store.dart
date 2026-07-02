import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ai/saved_advice.dart';
import '../l10n/app_language.dart';
import '../nutrition/energy.dart';
import '../steps/steps_service.dart';
import '../theme/tokens.dart';

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
  final String? productSlug;
  final int? grams;
  const LogItem(
    this.name,
    this.kcal, {
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.micros = const {},
    this.productSlug,
    this.grams,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'kcal': kcal,
        'p': protein,
        'c': carbs,
        'f': fat,
        'm': micros,
        'slug': productSlug,
        'grams': grams,
      };
  static LogItem fromMap(Map m) => LogItem(
        m['name'] as String,
        (m['kcal'] as num).toInt(),
        protein: (m['p'] as num?)?.toDouble() ?? 0,
        carbs: (m['c'] as num?)?.toDouble() ?? 0,
        fat: (m['f'] as num?)?.toDouble() ?? 0,
        micros: _microsFromMap(m['m']),
        productSlug: m['slug'] as String?,
        grams: (m['grams'] as num?)?.toInt(),
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
class BodyMetricEntry {
  final DateTime date;
  final double weightKg;
  final double skeletalMuscle;
  final double bodyFat;

  const BodyMetricEntry({
    required this.date,
    required this.weightKg,
    required this.skeletalMuscle,
    required this.bodyFat,
  });

  Map<String, dynamic> toMap() => {
        'date': AppStore.ymd(date),
        'weightKg': weightKg,
        'skeletalMuscle': skeletalMuscle,
        'bodyFat': bodyFat,
      };

  static BodyMetricEntry fromMap(Map<dynamic, dynamic> m) {
    final rawDate = m['date'] as String?;
    return BodyMetricEntry(
      date: rawDate == null
          ? DateTime.now()
          : DateTime.tryParse(rawDate) ?? DateTime.now(),
      weightKg: (m['weightKg'] as num?)?.toDouble() ?? 0,
      skeletalMuscle: (m['skeletalMuscle'] as num?)?.toDouble() ?? 0,
      bodyFat: (m['bodyFat'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AppStore extends ChangeNotifier {
  static const _boxName = 'eco';
  static const _seedDemoFood = bool.fromEnvironment('SEED_DEMO_FOOD');
  static const _resetDemoFood = bool.fromEnvironment('SEED_DEMO_FOOD_RESET');
  late Box _box;

  // Home dashboard metrics
  int water = 0; // мл
  int waterGoal = 2000;
  // История воды по дням (ymd -> мл) для графика на экране «Вода».
  // Сегодняшний день всегда берётся из живого [water]; прошлые — отсюда.
  Map<String, int> waterHistory = {};
  int steps = 0;
  int stepsGoal = 10000;
  // История шагов по дням (ymd -> шаги) для недельного графика на экране «Шаги».
  // Сегодняшний день всегда берётся из живого [steps]; прошлые — отсюда.
  Map<String, int> stepsHistory = {};
  double weight = 0;
  String? recFeedback; // 'up' | 'down'
  AppLanguage language = AppLanguage.ru;

  /// Whether the user has picked a language on the first-launch language page.
  /// Gates whether that page is shown before onboarding.
  bool languageChosen = false;

  // Прозрачность стеклянных карточек (alpha заливки EcoGlassSurface).
  // Меньше значение = карточки прозрачнее. Регулируется ползунком в Настройках.
  double cardOpacity = 0.30;

  // Тёмная тема (переключатель в Настройках). Активная палитра — [theme].
  bool darkMode = false;

  // ── Настройки уведомлений (экран «Уведомления», колокольчик на главной).
  // Мастер-тумблер + отдельные категории. Планировщик (NotificationService)
  // подписан на стор и перепланирует расписание при любом изменении.
  bool notifEnabled = true;
  bool notifMeals = true;
  bool notifWater = true;
  bool notifSummary = true;
  bool notifSteps = true;
  bool notifWeight = true;

  /// Разрешение POST_NOTIFICATIONS уже запрашивалось (чтобы не спамить
  /// системным диалогом на каждый запуск). Не вызывает notifyListeners.
  bool notifPermAsked = false;

  /// Активная тема приложения (светлая/тёмная) — для всех экранов и элементов.
  EcoTheme get theme => darkMode ? EcoTheme.night : EcoTheme.meadow;

  // Food diary keyed by date: ymd -> (meal.key -> items).
  Map<String, Map<String, List<LogItem>>> diary = {};
  Set<String> favoriteProductSlugs = {};

  // Кеш агрегатов СЕГОДНЯШНЕГО дня (consumed/macros). Раньше эти геттеры
  // пересчитывались полным проходом по дневнику на КАЖДОЙ перестройке —
  // а главный экран читает их в select-хэше, который дёргается на каждый тик
  // шагомера. Кешируем по дате и сбрасываем только при изменении дневника,
  // чтобы тик шагов/воды не перелопачивал весь день.
  String? _aggDate;
  int? _consumedCache;
  ({double protein, double carbs, double fat})? _macrosCache;

  /// Растёт при любом изменении дневника. Виджеты, которым важно лишь «дневник
  /// поменялся» (карточка ИИ-совета), подписываются через
  /// `context.select((s) => s.diaryRevision)` и не перестраиваются на тики
  /// шагомера/воды.
  int diaryRevision = 0;

  void _invalidateAggregates() {
    _aggDate = null;
    _consumedCache = null;
    _macrosCache = null;
    diaryRevision++;
  }

  void _ensureAggregates() {
    final today = ymd();
    if (_aggDate == today && _consumedCache != null) return;
    _aggDate = today;
    _consumedCache = consumedOn(today);
    _macrosCache = macrosOn(today);
  }

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
  double bodyFat = 17.5; // %
  double skeletalMuscle = 30.2; // кг
  List<BodyMetricEntry> bodyHistory = [];

  /// Сохранённые пользователем ИИ-советы (новые в начале). Персист в Hive под
  /// ключом 'aiAdvices'; показываются на вкладке «Сохранённые» страницы совета.
  List<SavedAiAdvice> aiAdvices = [];

  // Macro goals in grams (set from target kcal at onboarding).
  int carbGoal = 230;
  int fatGoal = 60;
  int protGoal = 150;

  // Onboarding profile
  bool onboarded = false;
  String? profileName;
  String? gender;
  int? age; // derived from birthDate when it is set
  DateTime? birthDate;
  int? heightCm;
  double? weightKg;
  String? activity;
  String? goal; // lose | keep | gain
  String? avatarPath; // local file path of the chosen profile photo

  /// Whole years from [birth] to today.
  static int ageFromBirth(DateTime birth) {
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    water = _box.get('water', defaultValue: 0) as int;
    // Полуночный сброс: живое [water] принадлежит дню 'waterDate'. Раньше
    // вчерашний итог «переезжал» в новое утро до первого нажатия ± — и все
    // прогресс-подписи (и уведомления о воде) утром врали. Вчерашнее значение
    // уже сохранено в waterHistory, поэтому новый день начинаем с нуля.
    final waterDate = _box.get('waterDate') as String?;
    if (waterDate != null && waterDate != ymd()) {
      water = 0;
      _box.put('water', 0);
    }
    _box.put('waterDate', ymd());
    waterGoal = _box.get('waterGoal', defaultValue: 2000) as int;
    final rawWaterHistory = _box.get('waterHistory');
    if (rawWaterHistory is Map) {
      waterHistory = rawWaterHistory
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    }
    _seedRandomWaterMonth();
    steps = _box.get('steps', defaultValue: 0) as int;
    stepsGoal = _box.get('stepsGoal', defaultValue: 10000) as int;
    final rawStepsHistory = _box.get('stepsHistory');
    if (rawStepsHistory is Map) {
      stepsHistory = rawStepsHistory
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    }
    _seedRandomStepsMonth();
    weight = (_box.get('weight', defaultValue: 0.0) as num).toDouble();
    bodyFat = (_box.get('bodyFat', defaultValue: 17.5) as num).toDouble();
    skeletalMuscle =
        (_box.get('skeletalMuscle', defaultValue: 30.2) as num).toDouble();
    language = AppLanguage.fromCode(
      _box.get('language', defaultValue: AppLanguage.ru.code) as String?,
    );
    languageChosen = _box.get('languageChosen', defaultValue: false) as bool;
    cardOpacity =
        (_box.get('cardOpacity', defaultValue: 0.30) as num).toDouble();
    darkMode = _box.get('darkMode', defaultValue: false) as bool;
    notifEnabled = _box.get('notifEnabled', defaultValue: true) as bool;
    notifMeals = _box.get('notifMeals', defaultValue: true) as bool;
    notifWater = _box.get('notifWater', defaultValue: true) as bool;
    notifSummary = _box.get('notifSummary', defaultValue: true) as bool;
    notifSteps = _box.get('notifSteps', defaultValue: true) as bool;
    notifWeight = _box.get('notifWeight', defaultValue: true) as bool;
    notifPermAsked = _box.get('notifPermAsked', defaultValue: false) as bool;
    goalKcal = _box.get('goalKcal', defaultValue: 2045) as int;
    carbGoal = _box.get('carbGoal', defaultValue: 230) as int;
    fatGoal = _box.get('fatGoal', defaultValue: 60) as int;
    protGoal = _box.get('protGoal', defaultValue: 150) as int;
    onboarded = _box.get('onboarded', defaultValue: false) as bool;
    profileName = _cleanName(_box.get('profileName') as String?);
    gender = _box.get('gender') as String?;
    final birthStr = _box.get('birthDate') as String?;
    birthDate = birthStr != null ? DateTime.tryParse(birthStr) : null;
    age = birthDate != null
        ? ageFromBirth(birthDate!)
        : (_box.get('age') as num?)?.toInt();
    heightCm = (_box.get('heightCm') as num?)?.toInt();
    weightKg = (_box.get('weightKg') as num?)?.toDouble();
    activity = _box.get('activity') as String?;
    goal = _box.get('goal') as String?;
    avatarPath = _box.get('avatarPath') as String?;
    final hasCompleteProfile = (gender == 'm' || gender == 'f') &&
        age != null &&
        heightCm != null &&
        (weightKg != null || weight > 0);
    if (onboarded && !hasCompleteProfile) {
      onboarded = false;
      await _box.put('onboarded', false);
    }
    // Норма воды теперь выводится из профиля, а не хранится жёстко. Пересчитываем
    // при каждом старте, когда профиль полон: так «старые» пользователи с
    // сохранёнными 2000 мл сразу получают персональную норму, и она остаётся
    // актуальной при изменении возраста/веса.
    if (hasCompleteProfile) {
      waterGoal = waterGoalFor(
        ageYears: age!,
        sex: gender!,
        weightKg: weightKg ?? weight,
        heightCm: heightCm!.toDouble(),
        activity: activity ?? 'mid',
      );
      await _box.put('waterGoal', waterGoal);
    }
    final rawBodyHistory = _box.get('bodyHistory');
    if (rawBodyHistory is List) {
      bodyHistory = rawBodyHistory
          .whereType<Map<dynamic, dynamic>>()
          .map(BodyMetricEntry.fromMap)
          .where((entry) => entry.weightKg > 0)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    final currentWeight = weight > 0 ? weight : (weightKg ?? 0);
    if (bodyHistory.isEmpty && currentWeight > 0) {
      bodyHistory = [
        BodyMetricEntry(
          date: DateTime.now(),
          weightKg: currentWeight,
          skeletalMuscle: skeletalMuscle,
          bodyFat: bodyFat,
        ),
      ];
    }
    final rawFavorites = _box.get('favoriteProductSlugs');
    if (rawFavorites is List) {
      favoriteProductSlugs = rawFavorites.whereType<String>().toSet();
    }
    final rawAdvices = _box.get('aiAdvices');
    if (rawAdvices is List) {
      aiAdvices = rawAdvices
          .whereType<Map<dynamic, dynamic>>()
          .map(SavedAiAdvice.fromMap)
          .toList();
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

  /// Прозрачность карточек (0.08–0.95). Меньше = прозрачнее. Сразу сохраняется.
  void setCardOpacity(double value) {
    cardOpacity = value.clamp(0.08, 0.95);
    _box.put('cardOpacity', cardOpacity);
    notifyListeners();
  }

  /// Включить/выключить тёмную тему. Сохраняется и применяется ко всему UI.
  void setDarkMode(bool value) {
    darkMode = value;
    _box.put('darkMode', value);
    notifyListeners();
  }

  void _persist() {
    _box.put('water', water);
    _box.put('waterGoal', waterGoal);
    _box.put('steps', steps);
    _box.put('stepsGoal', stepsGoal);
    _box.put('weight', weight);
    _box.put('bodyFat', bodyFat);
    _box.put('skeletalMuscle', skeletalMuscle);
    _box.put('bodyHistory', bodyHistory.map((entry) => entry.toMap()).toList());
    _box.put('language', language.code);
    _box.put('goalKcal', goalKcal);
    _box.put('carbGoal', carbGoal);
    _box.put('fatGoal', fatGoal);
    _box.put('protGoal', protGoal);
    _box.put('onboarded', onboarded);
    _box.put('profileName', profileName);
    _box.put('gender', gender);
    _box.put('age', age);
    _box.put('birthDate', birthDate?.toIso8601String());
    _box.put('heightCm', heightCm);
    _box.put('weightKg', weightKg);
    _box.put('activity', activity);
    _box.put('goal', goal);
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

  /// Сохранить ИИ-совет (в начало списка), с ограничением на 50 записей.
  void saveAiAdvice(SavedAiAdvice advice) {
    aiAdvices.insert(0, advice);
    if (aiAdvices.length > 50) {
      aiAdvices = aiAdvices.sublist(0, 50);
    }
    _persistAiAdvices();
    notifyListeners();
  }

  /// Удалить сохранённый совет по id.
  void deleteAiAdvice(String id) {
    final before = aiAdvices.length;
    aiAdvices.removeWhere((advice) => advice.id == id);
    if (aiAdvices.length == before) return;
    _persistAiAdvices();
    notifyListeners();
  }

  void _persistAiAdvices() {
    _box.put('aiAdvices', aiAdvices.map((advice) => advice.toMap()).toList());
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

  /// Обновляет настройки уведомлений (мастер-тумблер и/или категории).
  /// Каждый переданный флаг сразу персистится; планировщик перепланирует
  /// расписание через подписку на стор.
  void setNotifPrefs({
    bool? enabled,
    bool? meals,
    bool? water,
    bool? summary,
    bool? steps,
    bool? weight,
  }) {
    var changed = false;
    void apply(String key, bool? value, bool current, void Function(bool) set) {
      if (value == null || value == current) return;
      set(value);
      _box.put(key, value);
      changed = true;
    }

    apply('notifEnabled', enabled, notifEnabled, (v) => notifEnabled = v);
    apply('notifMeals', meals, notifMeals, (v) => notifMeals = v);
    apply('notifWater', water, notifWater, (v) => notifWater = v);
    apply('notifSummary', summary, notifSummary, (v) => notifSummary = v);
    apply('notifSteps', steps, notifSteps, (v) => notifSteps = v);
    apply('notifWeight', weight, notifWeight, (v) => notifWeight = v);
    if (changed) notifyListeners();
  }

  /// Помечает, что системный диалог разрешения уведомлений уже показывали.
  /// Без notifyListeners — вызывается из планировщика, петля не нужна.
  void markNotifPermAsked() {
    if (notifPermAsked) return;
    notifPermAsked = true;
    _box.put('notifPermAsked', true);
  }

  /// Marks that the first-launch language page has been completed.
  void setLanguageChosen(bool value) {
    if (languageChosen == value) return;
    languageChosen = value;
    _box.put('languageChosen', value);
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

  int consumedOn([String? date]) => (diary[date ?? ymd()] ?? const {})
      .values
      .expand((items) => items)
      .fold(0, (sum, e) => sum + e.kcal);

  int get consumed {
    _ensureAggregates();
    return _consumedCache!;
  }

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

  ({double protein, double carbs, double fat}) get macros {
    _ensureAggregates();
    return _macrosCache!;
  }

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

  /// Демо: заполняет историю шагов случайными значениями (2500–13500) за
  /// последние 30 дней для дней без записи, чтобы недельный/месячный график не
  /// был пустым. Реальные записанные дни не трогает; если сегодняшних живых шагов
  /// ещё нет (0), подставляет случайное значение и в [steps].
  void _seedRandomStepsMonth() {
    final rnd = math.Random();
    final today = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final key = ymd(today.subtract(Duration(days: i)));
      if ((stepsHistory[key] ?? 0) <= 0) {
        stepsHistory[key] = 2500 + rnd.nextInt(11000);
      }
    }
    // Если живых шагов ещё нет (эмулятор/нет датчика) — показываем сегодняшнее
    // демо-значение, чтобы график и сводка не были пустыми.
    if (steps <= 0) steps = stepsHistory[ymd()] ?? steps;
    _box.put('steps', steps);
    _box.put('stepsHistory', stepsHistory);
  }

  /// Заполняет историю воды за 30 дней демо-значениями там, где их ещё нет, —
  /// чтобы график на экране «Вода» не был пустым (как [_seedRandomStepsMonth]).
  void _seedRandomWaterMonth() {
    final rnd = math.Random();
    final today = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final key = ymd(today.subtract(Duration(days: i)));
      if ((waterHistory[key] ?? 0) <= 0) {
        waterHistory[key] = 600 + rnd.nextInt(1800); // 600..2399 мл
      }
    }
    _box.put('waterHistory', waterHistory);
  }

  /// Полуночный сброс воды для процесса, пережившего ночь в фоне: init()
  /// выполняется один раз за запуск, поэтому при возврате из фона на новый
  /// день сбрасываем живое [water] здесь (вызывается из onResume в main.dart).
  void rolloverWaterIfNeeded() {
    final today = ymd();
    final waterDate = _box.get('waterDate') as String?;
    if (waterDate == null || waterDate == today) return;
    water = 0;
    _box.put('water', 0);
    _box.put('waterDate', today);
    notifyListeners();
  }

  /// Сохраняет сегодняшнюю воду в историю по дате (для графика на экране «Вода»).
  void _recordWaterToday() {
    waterHistory[ymd()] = water;
    _box.put('waterHistory', waterHistory);
    // Штамп дня, которому принадлежит живое [water] (полуночный сброс в init).
    _box.put('waterDate', ymd());
  }

  /// Вода за последние [days] дней (старые слева, сегодня справа) — для
  /// горизонтально прокручиваемой полосы на экране «Вода». Сегодня берётся из
  /// живого [water], прошлые дни — из [waterHistory].
  List<({DateTime date, int water})> waterMonth([int days = 30]) {
    final today = DateTime.now();
    final out = <({DateTime date, int water})>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = ymd(d);
      out.add(
          (date: d, water: key == ymd() ? water : (waterHistory[key] ?? 0)));
    }
    return out;
  }

  /// Вода за день, отстоящий на [offset] дней назад (0 = сегодня, живое
  /// значение; прошлые — из истории).
  int waterForOffset(int offset) {
    if (offset <= 0) return water;
    final key = ymd(DateTime.now().subtract(Duration(days: offset)));
    return waterHistory[key] ?? 0;
  }

  /// Сохраняет сегодняшние шаги: и отдельным ключом 'steps', и в историю по дате
  /// (для недельного графика на экране «Шаги»). Дневник при этом не трогаем.
  void _recordStepsToday() {
    _box.put('steps', steps);
    stepsHistory[ymd()] = steps;
    _box.put('stepsHistory', stepsHistory);
  }

  /// Шаги за последние 7 дней (старые слева, сегодня справа). Сегодня берётся из
  /// живого [steps], прошлые дни — из [stepsHistory].
  List<({DateTime date, int steps})> stepsWeek() => stepsMonth(7);

  /// Шаги за последние [days] дней (старые слева, сегодня справа) — для
  /// горизонтально прокручиваемой полосы на экране «Шаги». Сегодня берётся из
  /// живого [steps], прошлые дни — из [stepsHistory].
  List<({DateTime date, int steps})> stepsMonth([int days = 30]) {
    final today = DateTime.now();
    final out = <({DateTime date, int steps})>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = ymd(d);
      out.add(
          (date: d, steps: key == ymd() ? steps : (stepsHistory[key] ?? 0)));
    }
    return out;
  }

  /// Шаги за день, отстоящий на [offset] дней назад (0 = сегодня, живой
  /// счётчик; прошлые дни — из истории). Для выбранного в полосе дня.
  int stepsForOffset(int offset) {
    if (offset <= 0) return steps;
    final key = ymd(DateTime.now().subtract(Duration(days: offset)));
    return stepsHistory[key] ?? 0;
  }

  /// Оценка сожжённых за активность калорий по шагам и весу (~0.00065 ккал на
  /// шаг·кг ≈ 0.045 ккал/шаг при 70 кг). Формула в nutrition/energy.dart.
  int activeKcal() => activeKcalFor(steps);

  /// То же, но для произвольного числа шагов [s] (выбранный в полосе день).
  int activeKcalFor(int s) {
    final kg = weight > 0 ? weight : (weightKg ?? 70);
    return walkingCalories(steps: s, weightKg: kg);
  }

  /// Оценка времени активности в минутах по шагам (~110 шагов/мин).
  int activeMinutes() => activeMinutesFor(steps);

  /// То же, но для произвольного числа шагов [s] (выбранный в полосе день).
  int activeMinutesFor(int s) => (s / 110).round();

  /// Silent sync at startup/resume; no permission prompt.
  Future<void> syncSteps() async {
    stepsPermission = await StepsService.instance.checkPermission();
    if (!stepsPermission) {
      notifyListeners();
      return;
    }
    final n = await StepsService.instance.getTodaySteps();
    // Игнорируем нулевые показания (нет датчика/разрешения), чтобы не затирать
    // уже показанное значение (в т.ч. демо-данные) нулём.
    if (n != null && n > 0 && n != steps) {
      steps = n;
      _recordStepsToday();
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
      if (n <= 0 || n == steps) return;
      steps = n;
      // Живой шагомер тикает несколько раз в секунду при ходьбе — пишем только
      // шаги (+ историю дня), а не весь дневник (это и была главная причина
      // пропуска кадров при ходьбе с открытым приложением).
      _recordStepsToday();
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
    // Пишем ТОЛЬКО изменившийся ключ, а не весь дневник (раньше каждый «+250 мл»
    // заново сериализовал все 30 дней дневника в main-потоке).
    _box.put('water', water);
    _recordWaterToday();
    notifyListeners();
  }

  /// ± buttons on the water screen clamp to the [0, goal] range (per design).
  void stepWater(int delta) {
    water = (water + delta).clamp(0, waterGoal);
    _box.put('water', water);
    _recordWaterToday();
    notifyListeners();
  }

  /// Изменяет воду выбранного в графике дня кнопками ± ([offset] дней назад,
  /// 0 = сегодня). Сегодня правит живое [water], прошлые дни — запись в истории.
  /// Клампится в диапазон [0, цель], как и [stepWater].
  void stepWaterForOffset(int offset, int delta) {
    if (offset <= 0) {
      stepWater(delta);
      return;
    }
    final key = ymd(DateTime.now().subtract(Duration(days: offset)));
    final cur = waterHistory[key] ?? 0;
    waterHistory[key] = (cur + delta).clamp(0, waterGoal);
    _box.put('waterHistory', waterHistory);
    notifyListeners();
  }

  void setWeight(double kg) {
    weight = kg;
    weightKg = kg;
    _upsertBodyHistory(
      BodyMetricEntry(
        date: DateTime.now(),
        weightKg: kg,
        skeletalMuscle: skeletalMuscle,
        bodyFat: bodyFat,
      ),
    );
    _persist();
    notifyListeners();
  }

  void setBodyComposition({double? bodyFat, double? skeletalMuscle}) {
    if (bodyFat != null) this.bodyFat = bodyFat;
    if (skeletalMuscle != null) this.skeletalMuscle = skeletalMuscle;
    final currentWeight = weight > 0 ? weight : (weightKg ?? 0);
    if (currentWeight > 0) {
      _upsertBodyHistory(
        BodyMetricEntry(
          date: DateTime.now(),
          weightKg: currentWeight,
          skeletalMuscle: this.skeletalMuscle,
          bodyFat: this.bodyFat,
        ),
      );
    }
    _persist();
    notifyListeners();
  }

  void saveBodyMetrics({
    required double weightKg,
    required double skeletalMuscle,
    required double bodyFat,
    DateTime? date,
  }) {
    final roundedWeight = double.parse(weightKg.toStringAsFixed(1));
    this.weightKg = roundedWeight;
    weight = roundedWeight;
    this.skeletalMuscle = double.parse(skeletalMuscle.toStringAsFixed(1));
    this.bodyFat = double.parse(bodyFat.toStringAsFixed(1));
    _upsertBodyHistory(
      BodyMetricEntry(
        date: date ?? DateTime.now(),
        weightKg: roundedWeight,
        skeletalMuscle: this.skeletalMuscle,
        bodyFat: this.bodyFat,
      ),
    );
    _persist();
    notifyListeners();
  }

  void updateProfileBasics({
    required String? profileName,
    required int age,
    required String gender,
  }) {
    this.profileName = _cleanName(profileName);
    this.age = age;
    this.gender = gender;
    _persist();
    notifyListeners();
  }

  void setAvatarPath(String? path) {
    avatarPath = path;
    _box.put('avatarPath', path);
    notifyListeners();
  }

  void setRecFeedback(String? v) {
    recFeedback = recFeedback == v ? null : v;
    notifyListeners();
  }

  void addFood(String mealKey, LogItem item, {String? date}) {
    _day(date ?? ymd()).putIfAbsent(mealKey, () => []).add(item);
    _invalidateAggregates();
    _persist();
    notifyListeners();
  }

  void removeFood(String mealKey, int index, {String? date}) {
    final items = diary[date ?? ymd()]?[mealKey];
    if (items == null || index < 0 || index >= items.length) return;
    items.removeAt(index);
    _invalidateAggregates();
    _persist();
    notifyListeners();
  }

  void updateFood(String mealKey, int index, LogItem item, {String? date}) {
    final items = diary[date ?? ymd()]?[mealKey];
    if (items == null || index < 0 || index >= items.length) return;
    items[index] = item;
    _invalidateAggregates();
    _persist();
    notifyListeners();
  }

  void completeOnboarding({
    required String? profileName,
    required String gender,
    required DateTime birthDate,
    required int heightCm,
    required double weightKg,
    required String activity,
    required String goal,
    required int targetKcal,
  }) {
    this.profileName = _cleanName(profileName);
    this.gender = gender;
    this.birthDate = birthDate;
    age = ageFromBirth(birthDate);
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    weight = weightKg;
    this.activity = activity;
    this.goal = goal;
    goalKcal = targetKcal;
    // Норма воды выводится из параметров профиля (см. waterGoalFor), поэтому
    // пересчитываем её здесь — она больше не фиксированные 2000 мл.
    waterGoal = waterGoalFor(
      ageYears: age!,
      sex: gender,
      weightKg: weightKg,
      heightCm: heightCm.toDouble(),
      activity: activity,
    );
    // Standard 45/30/25 split → grams (carbs & protein 4 kcal/г, fat 9 kcal/г).
    carbGoal = (targetKcal * 0.45 / 4).round();
    protGoal = (targetKcal * 0.30 / 4).round();
    fatGoal = (targetKcal * 0.25 / 9).round();
    onboarded = true;
    _upsertBodyHistory(
      BodyMetricEntry(
        date: DateTime.now(),
        weightKg: weightKg,
        skeletalMuscle: skeletalMuscle,
        bodyFat: bodyFat,
      ),
    );
    _persist();
    notifyListeners();
  }

  /// Полный сброс пользовательских данных — как первый запуск приложения.
  /// Очищает Hive-хранилище и заново подтягивает дефолты (профиль, дневник,
  /// история веса/воды/шагов, настройки). После вызова onboarded == false,
  /// поэтому приложение ведёт в онбординг, где все характеристики (возраст,
  /// рост…) вводятся заново. Язык/тема тоже сбрасываются к значениям по
  /// умолчанию, как при чистой установке.
  Future<void> resetUserData() async {
    await _box.clear();
    // init() присваивает коллекции только при наличии данных в box — после
    // clear() гварды не срабатывают, и старые in-memory данные (дневник,
    // история, времена приёмов…) пережили бы сброс до перезапуска приложения.
    water = 0;
    steps = 0;
    diary = {};
    waterHistory = {};
    stepsHistory = {};
    bodyHistory = [];
    mealTimes = {};
    favoriteProductSlugs = {};
    aiAdvices = [];
    _invalidateAggregates();
    // Сбрасываем живые поля шагомера, чтобы новый поток подписался заново.
    await _liveSteps?.cancel();
    _liveSteps = null;
    // init() перечитывает уже пустой box: всё возвращается к дефолтам и
    // повторно засеиваются демо-история шагов/воды (как при первом запуске),
    // в конце вызывает notifyListeners().
    await init();
  }

  void _upsertBodyHistory(BodyMetricEntry entry) {
    final key = ymd(entry.date);
    bodyHistory = [
      for (final item in bodyHistory)
        if (ymd(item.date) != key) item,
      entry,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (bodyHistory.length > 90) {
      bodyHistory = bodyHistory.sublist(bodyHistory.length - 90);
    }
  }

  /// Удаляет сохранённую запись состава тела за указанную дату. Возвращает
  /// true, если что-то было удалено (синтетические записи графика не трогаются).
  bool deleteBodyEntry(DateTime date) {
    final key = ymd(date);
    final before = bodyHistory.length;
    bodyHistory = [
      for (final item in bodyHistory)
        if (ymd(item.date) != key) item,
    ];
    if (bodyHistory.length == before) return false;
    _persist();
    notifyListeners();
    return true;
  }

  String? _cleanName(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    if (bodyHistory.isEmpty && weight > 0) {
      _upsertBodyHistory(
        BodyMetricEntry(
          date: DateTime.now(),
          weightKg: weight,
          skeletalMuscle: skeletalMuscle,
          bodyFat: bodyFat,
        ),
      );
    }

    final today = DateTime.now();
    for (var offset = 29; offset >= 0; offset--) {
      final date = ymd(today.subtract(Duration(days: offset)));
      if (!_resetDemoFood && (diary[date]?.isNotEmpty ?? false)) continue;
      final meals = <String, List<LogItem>>{};
      _fillDemoDay(meals, 29 - offset);
      diary[date] = meals;
      // Демо-шаги: правдоподобный разброс 4500–11500 для недельного графика.
      stepsHistory[date] = 4500 + ((offset * 1733 + 2200) % 7000);
    }
    steps = stepsHistory[ymd()] ?? steps;

    recFeedback = null;
    _box.put('demoFoodSeeded30Days', true);
    _box.put('demoFoodSeededAt', ymd());
    _box.put('stepsHistory', stepsHistory);
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
