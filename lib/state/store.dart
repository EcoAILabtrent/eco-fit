import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  const LogItem(this.name, this.kcal);

  Map<String, dynamic> toMap() => {'name': name, 'kcal': kcal};
  static LogItem fromMap(Map m) => LogItem(m['name'] as String, (m['kcal'] as num).toInt());
}

/// App state — mirrors the Eco design INITIAL store, persisted to Hive so the
/// app is fully offline-first. Supabase sync attaches on top of this later.
class AppStore extends ChangeNotifier {
  static const _boxName = 'eco';
  late Box _box;

  // Home dashboard metrics
  int water = 0; // мл
  int waterGoal = 2000;
  int steps = 0;
  int stepsGoal = 10000;
  double weight = 0;
  String? recFeedback; // 'up' | 'down'

  // Food log: meal.key -> items
  Map<String, List<LogItem>> log = {};

  // Custom meal times (meal.key -> "HH:mm"); defaults come from kMeals.
  Map<String, String> mealTimes = {};

  int goalKcal = 2045;

  // Health detail metrics
  String? pressure; // "120/80"
  double? sugar; // ммоль/л

  // Macro goals (grams → displayed as кал in the design legend)
  int carbGoal = 900;
  int fatGoal = 659;
  int protGoal = 589;

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
    goalKcal = _box.get('goalKcal', defaultValue: 2045) as int;
    onboarded = _box.get('onboarded', defaultValue: false) as bool;
    final rawTimes = _box.get('mealTimes');
    if (rawTimes is Map) {
      mealTimes = rawTimes.map((k, v) => MapEntry(k as String, v as String));
    }
    final rawLog = _box.get('log');
    if (rawLog is Map) {
      log = rawLog.map((k, v) => MapEntry(
            k as String,
            (v as List).map((e) => LogItem.fromMap(e as Map)).toList(),
          ));
    }
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
    _box.put('goalKcal', goalKcal);
    _box.put('onboarded', onboarded);
    _box.put('log', log.map((k, v) => MapEntry(k, v.map((e) => e.toMap()).toList())));
    _box.put('mealTimes', mealTimes);
  }

  String mealTime(String mealKey) =>
      mealTimes[mealKey] ?? kMeals.firstWhere((m) => m.key == mealKey, orElse: () => kMeals.first).time;

  void setMealTime(String mealKey, String time) {
    mealTimes[mealKey] = time;
    _persist();
    notifyListeners();
  }

  int get consumed =>
      log.values.expand((items) => items).fold(0, (sum, e) => sum + e.kcal);

  int mealKcal(String mealKey) =>
      (log[mealKey] ?? const []).fold(0, (sum, e) => sum + e.kcal);

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

  void addFood(String mealKey, LogItem item) {
    log.putIfAbsent(mealKey, () => []).add(item);
    _persist();
    notifyListeners();
  }

  void removeFood(String mealKey, int index) {
    final items = log[mealKey];
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
    onboarded = true;
    _persist();
    notifyListeners();
  }
}
