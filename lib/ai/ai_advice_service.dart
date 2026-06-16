import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_language.dart';
import '../state/store.dart';
import 'ai_config.dart';

enum AiAdvicePeriod {
  day(days: 1),
  week(days: 7),
  month(days: 30);

  final int days;

  const AiAdvicePeriod({required this.days});
}

class AiAdviceService {
  const AiAdviceService();

  Future<bool> hasInternet() async {
    try {
      final lookup = await InternetAddress.lookup(
        AiConfig.connectivityHost,
      ).timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<String> fetchDailyAdvice({
    required AppStore store,
    required AppLanguage language,
    AiAdvicePeriod period = AiAdvicePeriod.day,
    String? date,
  }) async {
    if (!AiConfig.hasBackend) {
      throw const AiAdviceException('AI backend is not configured.');
    }
    if (!await hasInternet()) {
      throw const AiAdviceException('No internet connection.');
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: AiConfig.functionsRegion,
      ).httpsCallable(
        AiConfig.adviceFunctionName,
        options: HttpsCallableOptions(timeout: AiConfig.timeout),
      );
      final result = await callable.call({
        'snapshot': _periodSnapshot(store, language, period, date),
      });

      final items = _itemsFromFunctionResult(result.data);
      if (items.isEmpty) {
        throw const AiAdviceException('AI returned an empty response.');
      }
      final normalized = _formatItems(items);
      if (normalized.isEmpty) {
        throw const AiAdviceException('AI returned an empty response.');
      }
      return normalized;
    } on AiAdviceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AiAdviceException(_functionError(error));
    } on TimeoutException {
      throw const AiAdviceException('AI request timed out.');
    } on SocketException {
      throw const AiAdviceException('No internet connection.');
    } on Object catch (error) {
      throw AiAdviceException('AI request failed: $error');
    }
  }

  Map<String, Object?> _periodSnapshot(
    AppStore store,
    AppLanguage language,
    AiAdvicePeriod period,
    String? date,
  ) {
    final dates = _dateKeys(period, date);
    final loggedDates = dates.where((day) => _itemsOn(store, day).isNotEmpty);
    final totals = _periodTotals(store, dates);
    final averageDays = loggedDates.isEmpty ? 1 : loggedDates.length;
    final averageKcal = totals.kcal / averageDays;
    final averageProtein = totals.protein / averageDays;
    final averageCarbs = totals.carbs / averageDays;
    final averageFat = totals.fat / averageDays;
    final snapshot = <String, Object?>{
      'period': period.name,
      'period_days': period.days,
      'start_date': dates.first,
      'end_date': dates.last,
      'logged_days': loggedDates.length,
      'language': language.code,
      'language_name': _languageName(language),
      'profile': {
        'age': store.age,
        'gender': store.gender,
        'height_cm': store.heightCm,
        'weight_kg': store.weightKg ?? (store.weight > 0 ? store.weight : null),
        'activity': store.activity,
        'goal': store.goal,
      },
      'daily_targets': {
        'kcal': store.goalKcal,
        'protein_g': store.protGoal,
        'carbs_g': store.carbGoal,
        'fat_g': store.fatGoal,
      },
      'period_totals': {
        'kcal': totals.kcal,
        'protein_g': _round(totals.protein),
        'carbs_g': _round(totals.carbs),
        'fat_g': _round(totals.fat),
        'micronutrients': {
          for (final entry in totals.micros.entries)
            entry.key: {
              'name': _microNames[entry.key] ?? entry.key,
              'amount': _round(entry.value),
              'unit': _microUnits[entry.key] ?? 'mg',
            },
        },
      },
      'average_per_logged_day': {
        'kcal': averageKcal.round(),
        'protein_g': _round(averageProtein),
        'carbs_g': _round(averageCarbs),
        'fat_g': _round(averageFat),
      },
      'daily_target_gaps': _dailyTargetGaps(
        store,
        averageKcal: averageKcal,
        averageProtein: averageProtein,
        averageCarbs: averageCarbs,
        averageFat: averageFat,
      ),
      'micronutrient_reference_gaps': _micronutrientGaps(
        store,
        totals.micros,
        averageDays,
      ),
      'micronutrient_note':
          'Micronutrient values are estimates from foods that have nutrient data in the local catalog.',
      'daily_breakdown': [
        for (final day in dates)
          {
            'date': day,
            'item_count': _itemsOn(store, day).length,
            'kcal': store.consumedOn(day),
            'protein_g': _round(store.macrosOn(day).protein),
            'carbs_g': _round(store.macrosOn(day).carbs),
            'fat_g': _round(store.macrosOn(day).fat),
          },
      ],
      'top_foods': _topFoods(store, dates),
    };

    if (period == AiAdvicePeriod.day) {
      final day = dates.last;
      snapshot['meals'] = [
        for (final meal in kMealsByTime)
          {
            'meal': meal.key,
            'time': store.mealTime(meal.key),
            'items': [
              for (final item in store.itemsFor(meal.key, date: day))
                {
                  'name': item.name,
                  'kcal': item.kcal,
                  'protein_g': _round(item.protein),
                  'carbs_g': _round(item.carbs),
                  'fat_g': _round(item.fat),
                  'micronutrients': {
                    for (final entry in item.micros.entries)
                      entry.key: _round(entry.value),
                  },
                },
            ],
          },
      ];
    }

    return snapshot;
  }

  List<String> _dateKeys(AiAdvicePeriod period, String? date) {
    final end = _parseDate(date);
    return [
      for (var i = period.days - 1; i >= 0; i--)
        AppStore.ymd(end.subtract(Duration(days: i))),
    ];
  }

  DateTime _parseDate(String? value) {
    if (value == null) return DateTime.now();
    final parts = value.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) {
      return DateTime.now();
    }
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }

  List<LogItem> _itemsOn(AppStore store, String date) => [
    for (final meal in kMealsByTime) ...store.itemsFor(meal.key, date: date),
  ];

  ({
    int kcal,
    double protein,
    double carbs,
    double fat,
    Map<String, double> micros,
  })
  _periodTotals(AppStore store, List<String> dates) {
    var kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    final micros = <String, double>{};

    for (final day in dates) {
      kcal += store.consumedOn(day);
      final macros = store.macrosOn(day);
      protein += macros.protein;
      carbs += macros.carbs;
      fat += macros.fat;
      for (final entry in store.microsOn(day).entries) {
        micros.update(
          entry.key,
          (current) => current + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }

    return (
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      micros: micros,
    );
  }

  List<Map<String, Object?>> _topFoods(AppStore store, List<String> dates) {
    final counts = <String, int>{};
    final kcals = <String, int>{};
    for (final day in dates) {
      for (final item in _itemsOn(store, day)) {
        counts.update(item.name, (current) => current + 1, ifAbsent: () => 1);
        kcals.update(
          item.name,
          (current) => current + item.kcal,
          ifAbsent: () => item.kcal,
        );
      }
    }

    final names = counts.keys.toList()
      ..sort((a, b) => (kcals[b] ?? 0).compareTo(kcals[a] ?? 0));
    return [
      for (final name in names.take(8))
        {'name': name, 'count': counts[name], 'kcal': kcals[name]},
    ];
  }

  Map<String, Object?> _dailyTargetGaps(
    AppStore store, {
    required double averageKcal,
    required double averageProtein,
    required double averageCarbs,
    required double averageFat,
  }) {
    return {
      'kcal': _gap(
        name: 'calories',
        average: averageKcal,
        target: store.goalKcal.toDouble(),
        unit: 'kcal',
      ),
      'protein_g': _gap(
        name: 'protein',
        average: averageProtein,
        target: store.protGoal.toDouble(),
        unit: 'g',
      ),
      'carbs_g': _gap(
        name: 'carbs',
        average: averageCarbs,
        target: store.carbGoal.toDouble(),
        unit: 'g',
      ),
      'fat_g': _gap(
        name: 'fat',
        average: averageFat,
        target: store.fatGoal.toDouble(),
        unit: 'g',
      ),
    };
  }

  Map<String, Object?> _micronutrientGaps(
    AppStore store,
    Map<String, double> totals,
    int averageDays,
  ) {
    final refs = _micronutrientReferences(store);
    return {
      for (final entry in refs.entries)
        entry.key: _gap(
          name: _microNames[entry.key] ?? entry.key,
          average: (totals[entry.key] ?? 0) / averageDays,
          target: entry.value.target,
          unit: entry.value.unit,
          upperLimit: entry.value.upperLimit,
        ),
    };
  }

  Map<String, ({double target, String unit, bool upperLimit})>
  _micronutrientReferences(AppStore store) {
    final female = store.gender == 'f';
    final age = store.age ?? 30;
    final calcium = age >= 51 && female || age >= 71 ? 1200.0 : 1000.0;
    return {
      'fe': (target: female ? 18.0 : 8.0, unit: 'mg', upperLimit: false),
      'mg': (target: female ? 320.0 : 420.0, unit: 'mg', upperLimit: false),
      'ca': (target: calcium, unit: 'mg', upperLimit: false),
      'p': (target: 700.0, unit: 'mg', upperLimit: false),
      'k': (target: female ? 2600.0 : 3400.0, unit: 'mg', upperLimit: false),
      'na': (target: 2300.0, unit: 'mg', upperLimit: true),
      'zn': (target: female ? 8.0 : 11.0, unit: 'mg', upperLimit: false),
      'vit_c': (target: female ? 75.0 : 90.0, unit: 'mg', upperLimit: false),
      'vit_a': (target: female ? 700.0 : 900.0, unit: 'mcg', upperLimit: false),
      'vit_d': (target: 15.0, unit: 'mcg', upperLimit: false),
    };
  }

  Map<String, Object?> _gap({
    required String name,
    required double average,
    required double target,
    required String unit,
    bool upperLimit = false,
  }) {
    final delta = average - target;
    final status = upperLimit
        ? (delta > 0 ? 'above_upper_limit_by' : 'within_limit')
        : (delta < 0 ? 'below_target_by' : 'above_target_by');
    return {
      'name': name,
      'average_per_logged_day': _round(average),
      'reference_per_day': _round(target),
      'delta': _round(delta),
      'absolute_gap': _round(delta.abs()),
      'unit': unit,
      'status': status,
    };
  }

  List<String> _itemsFromFunctionResult(Object? data) {
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is String) _cleanAdviceItem(item),
    ].where((item) => item.length >= 12).toList();
  }

  String _formatItems(List<String> rawItems) {
    final items = rawItems
        .map(_cleanAdviceItem)
        .where((item) => item.length >= 12)
        .take(4)
        .toList();
    if (items.length < 2) return '';
    return items.map(_withFinalPunctuation).join('\n');
  }

  String _cleanAdviceItem(String value) {
    return value
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp('^\\s*(?:[-*]|\\u2022)\\s*'), '')
        .replaceAll(RegExp(r'^\s*\d+[\).]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _withFinalPunctuation(String value) {
    if (value.isEmpty || RegExp(r'[.!?]$').hasMatch(value)) {
      return value;
    }
    return '$value.';
  }

  String _functionError(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;

    return switch (error.code) {
      'failed-precondition' => 'AI backend rejected this app.',
      'invalid-argument' => 'AI request data is invalid.',
      'resource-exhausted' => 'AI advice limit reached. Try again later.',
      'unauthenticated' => 'AI backend could not verify this app.',
      'unavailable' => 'AI service is temporarily unavailable.',
      _ => 'AI backend failed: ${error.code}.',
    };
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(2));

  static String _languageName(AppLanguage language) => switch (language) {
    AppLanguage.en => 'English',
    AppLanguage.ru => 'Russian',
    AppLanguage.uzLatn => 'Uzbek in Latin script',
    AppLanguage.uzCyrl => 'Uzbek in Cyrillic script',
  };

  static const _microNames = {
    'fe': 'iron',
    'mg': 'magnesium',
    'ca': 'calcium',
    'p': 'phosphorus',
    'k': 'potassium',
    'na': 'sodium',
    'zn': 'zinc',
    'vit_c': 'vitamin C',
    'vit_a': 'vitamin A',
    'vit_d': 'vitamin D',
  };

  static const _microUnits = {
    'fe': 'mg',
    'mg': 'mg',
    'ca': 'mg',
    'p': 'mg',
    'k': 'mg',
    'na': 'mg',
    'zn': 'mg',
    'vit_c': 'mg',
    'vit_a': 'mcg',
    'vit_d': 'mcg',
  };
}

class AiAdviceException implements Exception {
  final String message;

  const AiAdviceException(this.message);

  @override
  String toString() => message;
}
