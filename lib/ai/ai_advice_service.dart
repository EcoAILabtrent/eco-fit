import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../nutrition/micronutrients.dart';
import '../state/store.dart';
import 'ai_advice_contract.dart';
import 'ai_config.dart';

enum AiAdvicePeriod {
  day(days: 1),
  week(days: 7),
  month(days: 30);

  final int days;

  const AiAdvicePeriod({required this.days});
}

const _mainMealKeys = {'breakfast', 'lunch', 'dinner'};

bool isAiAdviceDayComplete(Iterable<String> loggedMealKeys) {
  final loggedMeals = loggedMealKeys.toSet();
  return loggedMeals.containsAll(_mainMealKeys);
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
      throw const AiAdviceException(
        AiAdviceErrorKind.generic,
        'AI backend is not configured.',
      );
    }
    // Предварительную DNS-проверку (hasInternet) здесь не делаем: экран уже
    // проверил сеть перед показом кнопки, а SocketException при отсутствии сети
    // и так обрабатывается ниже. Двойная проверка добавляла до 4 лишних секунд.

    try {
      final snapshot = _periodSnapshot(store, language, period, date);
      final callable = FirebaseFunctions.instanceFor(
        region: AiConfig.functionsRegion,
      ).httpsCallable(
        AiConfig.adviceFunctionName,
        options: HttpsCallableOptions(timeout: AiConfig.timeout),
      );
      final result = await callable.call({'snapshot': snapshot});

      final aiItems = AiAdviceContract.parseFunctionResult(result.data);
      final fallbackItems = _localAdviceItems(snapshot, language);
      final normalized = AiAdviceContract.format(
        AiAdviceContract.merge(aiItems: aiItems, fallbackItems: fallbackItems),
        language,
      );
      if (normalized.isEmpty) {
        throw const AiAdviceException(
          AiAdviceErrorKind.generic,
          'AI returned an empty response.',
        );
      }
      return normalized;
    } on AiAdviceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AiAdviceException(
        _functionErrorKind(error),
        'Firebase function "${error.code}": ${error.message ?? ''}',
      );
    } on TimeoutException catch (error) {
      throw AiAdviceException(AiAdviceErrorKind.timeout, '$error');
    } on SocketException catch (error) {
      throw AiAdviceException(AiAdviceErrorKind.network, '$error');
    } on Object catch (error) {
      throw AiAdviceException(AiAdviceErrorKind.generic, '$error');
    }
  }

  Map<String, Object?> _periodSnapshot(
    AppStore store,
    AppLanguage language,
    AiAdvicePeriod period,
    String? date,
  ) {
    final now = DateTime.now();
    final dates = _dateKeys(period, date);
    final loggedDates =
        dates.where((day) => _itemsOn(store, day).isNotEmpty).toList();
    final totals = _periodTotals(store, dates);
    final averageDays = loggedDates.isEmpty ? 1 : loggedDates.length;
    final averageKcal = totals.kcal / averageDays;
    final averageProtein = totals.protein / averageDays;
    final averageCarbs = totals.carbs / averageDays;
    final averageFat = totals.fat / averageDays;
    final loggedMeals = period == AiAdvicePeriod.day
        ? [
            for (final meal in kMealsByTime)
              if (store.itemsFor(meal.key, date: dates.last).isNotEmpty)
                meal.key,
          ]
        : <String>[];
    final isDayComplete = isAiAdviceDayComplete(loggedMeals);
    final isCalendarCurrentDay =
        period == AiAdvicePeriod.day && dates.last == AppStore.ymd(now);
    final snapshot = <String, Object?>{
      'period': period.name,
      'period_days': period.days,
      'start_date': dates.first,
      'end_date': dates.last,
      'logged_days': loggedDates.length,
      'generated_at_local': now.toIso8601String(),
      'current_local_hour': now.hour,
      'is_calendar_current_day': isCalendarCurrentDay,
      'is_current_day': isCalendarCurrentDay && !isDayComplete,
      'is_day_complete': isDayComplete,
      'logged_meals': loggedMeals,
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
        totals.microItemCounts,
        totals.itemCount,
      ),
      'micronutrient_note':
          'Micronutrient values are estimates from foods that have nutrient data in the local catalog. '
              'Never interpret insufficient_data as zero intake.',
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
                    for (final entry in _normalizedMicros(item.micros).entries)
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
        for (final meal in kMealsByTime)
          ...store.itemsFor(meal.key, date: date),
      ];

  ({
    int kcal,
    double protein,
    double carbs,
    double fat,
    Map<String, double> micros,
    Map<String, int> microItemCounts,
    int itemCount,
  }) _periodTotals(AppStore store, List<String> dates) {
    var kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    final micros = <String, double>{};
    final microItemCounts = <String, int>{};
    var itemCount = 0;

    for (final day in dates) {
      kcal += store.consumedOn(day);
      final macros = store.macrosOn(day);
      protein += macros.protein;
      carbs += macros.carbs;
      fat += macros.fat;
      for (final item in _itemsOn(store, day)) {
        itemCount++;
        for (final entry in item.micros.entries) {
          final key = canonicalMicronutrientKey(entry.key);
          if (key == null) continue;
          micros.update(
            key,
            (current) => current + entry.value,
            ifAbsent: () => entry.value,
          );
          microItemCounts.update(
            key,
            (current) => current + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    return (
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      micros: micros,
      microItemCounts: microItemCounts,
      itemCount: itemCount,
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
    Map<String, int> itemCounts,
    int totalItemCount,
  ) {
    final databaseKeys = FoodDb.instance.availableMicronutrientKeys;
    final refs = _micronutrientReferences(store, databaseKeys);
    return {
      for (final target in refs)
        target.key: _micronutrientGap(
          target: target,
          total: totals[target.key],
          averageDays: averageDays,
          coveredItems: itemCounts[target.key] ?? 0,
          totalItems: totalItemCount,
        ),
    };
  }

  List<MicroTarget> _micronutrientReferences(
    AppStore store,
    Iterable<String> databaseKeys,
  ) {
    final age = store.age;
    final heightCm = store.heightCm;
    final weightKg = store.weightKg ?? (store.weight > 0 ? store.weight : null);
    final gender = store.gender;
    if (age == null ||
        heightCm == null ||
        weightKg == null ||
        (gender != 'm' && gender != 'f')) {
      return const [];
    }

    return calculateMicroTargets(
      NutritionProfile(
        ageYears: age,
        sex: gender == 'f' ? ProfileSex.female : ProfileSex.male,
        weightKg: weightKg,
        heightCm: heightCm.toDouble(),
      ),
      databaseNutrientKeys: databaseKeys,
    );
  }

  Map<String, double> _normalizedMicros(Map<String, double> source) {
    final normalized = <String, double>{};
    for (final entry in source.entries) {
      final key = canonicalMicronutrientKey(entry.key);
      if (key == null) continue;
      normalized.update(
        key,
        (current) => current + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return normalized;
  }

  Map<String, Object?> _micronutrientGap({
    required MicroTarget target,
    required double? total,
    required int averageDays,
    required int coveredItems,
    required int totalItems,
  }) {
    final coverage = totalItems == 0 ? 0.0 : coveredItems / totalItems;
    final enoughData = total != null && coveredItems > 0;
    final average = (total ?? 0) / averageDays;
    // For nutrients with a CDRR (sodium) the meaningful reference is the
    // risk-reduction limit, not the AI — status is judged against it, so the
    // reported reference and gap must use it too.
    final referenceValue = target.cdrr ?? target.target;
    final delta = average - referenceValue;
    final dataQuality = !enoughData
        ? 'unavailable'
        : coverage >= 0.8
            ? 'high'
            : coverage >= 0.4
                ? 'medium'
                : 'low';

    String status;
    if (!enoughData) {
      status = 'insufficient_data';
    } else if (target.cdrr != null) {
      status = average > target.cdrr! ? 'above_cdrr_by' : 'within_cdrr';
    } else if (target.ear != null && average < target.ear!) {
      // Below the Estimated Average Requirement: intake is likely inadequate,
      // a stronger signal than merely falling short of the RDA/AI.
      status = 'below_ear_by';
    } else {
      status = delta < 0 ? 'below_target_by' : 'meets_or_above_target';
    }

    var safetyStatus = 'not_established';
    if (enoughData && target.cdrr != null) {
      safetyStatus = average > target.cdrr! ? 'above_cdrr' : 'within_cdrr';
    } else if (enoughData && target.ul != null) {
      final formSpecific = const {
        'mg',
        'vit_a',
        'vit_e',
        'vit_b3',
        'vit_b9',
      }.contains(target.key);
      safetyStatus = formSpecific
          ? 'not_evaluated_form_specific_ul'
          : (average > target.ul! ? 'above_ul' : 'within_ul');
    }

    return {
      'name': _microNames[target.key] ?? target.key,
      'average_per_logged_day': enoughData ? _round(average) : null,
      'reference_per_day': _round(referenceValue),
      'basis': target.basis.name,
      'delta_to_target': enoughData ? _round(delta) : null,
      'absolute_gap': enoughData ? _round(delta.abs()) : null,
      'unit': target.unit.code,
      'status': status,
      'safety_status': safetyStatus,
      'data_quality': dataQuality,
      'data_coverage_percent': _round(coverage * 100),
      if (target.ear != null) 'ear': _round(target.ear!),
      if (target.ul != null) 'ul': _round(target.ul!),
      if (target.cdrr != null) 'cdrr': _round(target.cdrr!),
      if (target.notes.isNotEmpty) 'notes': target.notes,
    };
  }

  List<AiAdviceEntry> _localAdviceItems(
    Map<String, Object?> snapshot,
    AppLanguage language,
  ) =>
      [
        ..._localMacroAdviceItems(snapshot, language),
        ..._localMicronutrientAdviceItems(snapshot, language),
      ];

  List<AiAdviceEntry> _localMacroAdviceItems(
    Map<String, Object?> snapshot,
    AppLanguage language,
  ) {
    final rawGaps = snapshot['daily_target_gaps'];
    final gaps = rawGaps is Map
        ? rawGaps.cast<Object?, Object?>()
        : const <Object?, Object?>{};
    const topics = [
      (AiAdviceTopic.calories, 'kcal'),
      (AiAdviceTopic.protein, 'protein_g'),
      (AiAdviceTopic.fat, 'fat_g'),
      (AiAdviceTopic.carbohydrates, 'carbs_g'),
    ];
    return [
      for (final (topic, key) in topics)
        AiAdviceEntry(
          topic,
          _localMacroAdvice(topic, gaps[key], snapshot, language),
        ),
    ];
  }

  String _localMacroAdvice(
    AiAdviceTopic topic,
    Object? rawData,
    Map<String, Object?> snapshot,
    AppLanguage language,
  ) {
    if (rawData is! Map) return _dataUnavailable(language);
    final data = rawData.cast<Object?, Object?>();
    final amountValue = data['average_per_logged_day'];
    final referenceValue = data['reference_per_day'];
    if (amountValue is! num || referenceValue is! num) {
      return _dataUnavailable(language);
    }

    final amount = amountValue.toDouble();
    final reference = referenceValue.toDouble();
    final status = data['status'] as String?;
    final below = status == 'below_target_by';
    final gap = (data['absolute_gap'] as num?)?.toDouble() ??
        (amount - reference).abs();
    final unit = topic == AiAdviceTopic.calories
        ? switch (language) {
            AppLanguage.ru || AppLanguage.uzCyrl => 'ккал',
            _ => 'kcal',
          }
        : switch (language) {
            AppLanguage.ru || AppLanguage.uzCyrl => 'г',
            _ => 'g',
          };
    final amountText = _localizedNumber(amount, language);
    final referenceText = _localizedNumber(reference, language);
    final gapText = _localizedNumber(gap, language);
    final period = '${snapshot['period'] ?? 'day'}';
    final loggedDays = (snapshot['logged_days'] as num?)?.toInt() ?? 0;
    final mentionProgress =
        snapshot['is_current_day'] == true && topic == AiAdviceTopic.calories;
    final reading = switch ((language, period, mentionProgress, below)) {
      (AppLanguage.en, 'day', true, true) =>
        '$amountText of $referenceText $unit so far; $gapText $unit remains.',
      (AppLanguage.ru, 'day', true, true) =>
        'Сейчас $amountText из $referenceText $unit; осталось $gapText $unit.',
      (AppLanguage.uzLatn, 'day', true, true) =>
        'Hozir $referenceText $unit dan $amountText; $gapText $unit qoldi.',
      (AppLanguage.uzCyrl, 'day', true, true) =>
        'Ҳозир $referenceText $unit дан $amountText; $gapText $unit қолди.',
      (AppLanguage.en, 'day', true, false) =>
        '$amountText $unit so far against $referenceText $unit; $gapText $unit over.',
      (AppLanguage.ru, 'day', true, false) =>
        'Сейчас $amountText $unit при ориентире $referenceText $unit; выше на $gapText $unit.',
      (AppLanguage.uzLatn, 'day', true, false) =>
        'Hozir $amountText $unit, moʻljal $referenceText $unit; $gapText $unit ortiq.',
      (AppLanguage.uzCyrl, 'day', true, false) =>
        'Ҳозир $amountText $unit, мўлжал $referenceText $unit; $gapText $unit ортиқ.',
      (AppLanguage.en, 'day', false, true) =>
        '$amountText of $referenceText $unit; $gapText $unit short.',
      (AppLanguage.ru, 'day', false, true) =>
        '$amountText из $referenceText $unit; не хватает $gapText $unit.',
      (AppLanguage.uzLatn, 'day', false, true) =>
        '$referenceText $unit dan $amountText; $gapText $unit kam.',
      (AppLanguage.uzCyrl, 'day', false, true) =>
        '$referenceText $unit дан $amountText; $gapText $unit кам.',
      (AppLanguage.en, 'day', false, false) =>
        '$amountText $unit against $referenceText $unit; $gapText $unit over.',
      (AppLanguage.ru, 'day', false, false) =>
        '$amountText $unit при ориентире $referenceText $unit; выше на $gapText $unit.',
      (AppLanguage.uzLatn, 'day', false, false) =>
        '$amountText $unit, moʻljal $referenceText $unit; $gapText $unit ortiq.',
      (AppLanguage.uzCyrl, 'day', false, false) =>
        '$amountText $unit, мўлжал $referenceText $unit; $gapText $unit ортиқ.',
      (AppLanguage.en, _, _, true) =>
        '$amountText of $referenceText $unit on average across $loggedDays logged days; $gapText $unit short.',
      (AppLanguage.ru, _, _, true) =>
        'В среднем $amountText из $referenceText $unit за $loggedDays заполненных дней; не хватает $gapText $unit.',
      (AppLanguage.uzLatn, _, _, true) =>
        '$loggedDays qayd etilgan kunda oʻrtacha $referenceText $unit dan $amountText; $gapText $unit kam.',
      (AppLanguage.uzCyrl, _, _, true) =>
        '$loggedDays қайд этилган кунда ўртача $referenceText $unit дан $amountText; $gapText $unit кам.',
      (AppLanguage.en, _, _, false) =>
        '$amountText $unit on average across $loggedDays logged days against $referenceText $unit; $gapText $unit over.',
      (AppLanguage.ru, _, _, false) =>
        'В среднем $amountText $unit за $loggedDays заполненных дней при ориентире $referenceText $unit; выше на $gapText $unit.',
      (AppLanguage.uzLatn, _, _, false) =>
        '$loggedDays qayd etilgan kunda oʻrtacha $amountText $unit, moʻljal $referenceText $unit; $gapText $unit ortiq.',
      (AppLanguage.uzCyrl, _, _, false) =>
        '$loggedDays қайд этилган кунда ўртача $amountText $unit, мўлжал $referenceText $unit; $gapText $unit ортиқ.',
    };
    final detail = _macroConsequenceAndFoods(
      topic,
      language,
      below,
      minorGap: reference > 0 && gap / reference < 0.05,
    );
    return '$reading $detail';
  }

  String _macroConsequenceAndFoods(
    AiAdviceTopic topic,
    AppLanguage language,
    bool below, {
    required bool minorGap,
  }) {
    const belowDetails = {
      AiAdviceTopic.calories: [
        'A persistent shortfall can cause fatigue and reduced performance; add buckwheat, yogurt, or nuts.',
        'Регулярный недобор может вызывать усталость и снижение работоспособности; добавьте гречку, йогурт или орехи.',
        'Muntazam kamlik charchoq va ish qobiliyati pasayishiga olib kelishi mumkin; grechka, yogurt yoki yongʻoq qoʻshing.',
        'Мунтазам камлик чарчоқ ва иш қобилияти пасайишига олиб келиши мумкин; гречка, йогурт ёки ёнғоқ қўшинг.',
      ],
      AiAdviceTopic.protein: [
        'A sustained shortfall can impair recovery and muscle maintenance; add eggs, fish, or legumes.',
        'Устойчивая нехватка может ухудшать восстановление и сохранение мышц; добавьте яйца, рыбу или бобовые.',
        'Doimiy kamlik tiklanish va mushaklarni saqlashni yomonlashtirishi mumkin; tuxum, baliq yoki dukkakli qoʻshing.',
        'Доимий камлик тикланиш ва мушакларни сақлашни ёмонлаштириши мумкин; тухум, балиқ ёки дуккакли қўшинг.',
      ],
      AiAdviceTopic.fat: [
        'A prolonged marked shortfall can impair absorption of vitamins A, D, E, and K; choose nuts, olive oil, or fish.',
        'Длительный выраженный недобор может ухудшать усвоение витаминов A, D, E и K; выберите орехи, растительное масло или рыбу.',
        'Uzoq davom etgan katta kamlik A, D, E va K vitaminlari soʻrilishini yomonlashtirishi mumkin; yongʻoq, oʻsimlik yogʻi yoki baliq tanlang.',
        'Узоқ давом этган катта камлик A, D, E ва K витаминлари сўрилишини ёмонлаштириши мумкин; ёнғоқ, ўсимлик ёғи ёки балиқ танланг.',
      ],
      AiAdviceTopic.carbohydrates: [
        'A repeated shortfall can reduce energy for physical and mental work; choose oats, potatoes, or fruit.',
        'Повторяющийся недобор может снижать энергию для физической и умственной работы; выберите овсянку, картофель или фрукты.',
        'Takroriy kamlik jismoniy va aqliy ish uchun energiyani kamaytirishi mumkin; suli, kartoshka yoki meva tanlang.',
        'Такрорий камлик жисмоний ва ақлий иш учун энергияни камайтириши мумкин; сули, картошка ёки мева танланг.',
      ],
    };
    const aboveDetails = {
      AiAdviceTopic.calories: [
        'A persistent excess can promote weight gain; reduce sugary drinks, pastries, or oversized portions.',
        'Постоянный избыток может способствовать набору веса; сократите сладкие напитки, выпечку или слишком большие порции.',
        'Doimiy ortiqcha miqdor vazn oshishiga olib kelishi mumkin; shirin ichimlik, pishiriq yoki katta porsiyalarni kamaytiring.',
        'Доимий ортиқча миқдор вазн ошишига олиб келиши мумкин; ширин ичимлик, пишириқ ёки катта порцияларни камайтиринг.',
      ],
      AiAdviceTopic.protein: [
        'Exceeding the target brings no extra benefit for most people; keep portions moderate and vary fish, dairy, and legumes.',
        'Превышение ориентира обычно не даёт дополнительной пользы; держите порции умеренными и чередуйте рыбу, кисломолочные продукты и бобовые.',
        'Moʻljaldan oshish odatda qoʻshimcha foyda bermaydi; porsiyani moʻtadil tutib, baliq, sut mahsuloti va dukkaklini navbatlang.',
        'Мўлжалдан ошиш одатда қўшимча фойда бермайди; порцияни мўътадил тутиб, балиқ, сут маҳсулоти ва дуккаклини навбатланг.',
      ],
      AiAdviceTopic.fat: [
        'A regular excess raises total calorie intake; reduce fried foods, fatty sauces, or added oil.',
        'Регулярный избыток повышает калорийность рациона; сократите жареное, жирные соусы или добавленное масло.',
        'Muntazam ortiqcha miqdor ratsion kaloriyasini oshiradi; qovurilgan taom, yogʻli sous yoki qoʻshilgan yogʻni kamaytiring.',
        'Мунтазам ортиқча миқдор рацион калориясини оширади; қовурилган таом, ёғли соус ёки қўшилган ёғни камайтиринг.',
      ],
      AiAdviceTopic.carbohydrates: [
        'A repeated excess, especially from sugar, can raise calorie intake and glucose swings; limit sweets, sugary drinks, or pastries.',
        'Повторяющийся избыток, особенно сахара, повышает калорийность и колебания глюкозы; ограничьте сладости, сладкие напитки или выпечку.',
        'Takroriy ortiqcha miqdor, ayniqsa shakar, kaloriya va glyukoza tebranishini oshiradi; shirinlik, shirin ichimlik yoki pishiriqni cheklang.',
        'Такрорий ортиқча миқдор, айниқса шакар, калория ва глюкоза тебранишини оширади; ширинлик, ширин ичимлик ёки пишириқни чекланг.',
      ],
    };
    if (below && minorGap) {
      const foods = {
        AiAdviceTopic.calories: [
          'a banana, yogurt, or nuts',
          'банан, йогурт или орехи',
          'banan, yogurt yoki yongʻoq',
          'банан, йогурт ёки ёнғоқ',
        ],
        AiAdviceTopic.protein: [
          'an egg, yogurt, or beans',
          'яйцо, йогурт или фасоль',
          'tuxum, yogurt yoki loviya',
          'тухум, йогурт ёки ловия',
        ],
        AiAdviceTopic.fat: [
          'nuts, olive oil, or fish',
          'орехи, растительное масло или рыба',
          'yongʻoq, oʻsimlik yogʻi yoki baliq',
          'ёнғоқ, ўсимлик ёғи ёки балиқ',
        ],
        AiAdviceTopic.carbohydrates: [
          'oats, potatoes, or fruit',
          'овсянка, картофель или фрукты',
          'suli, kartoshka yoki meva',
          'сули, картошка ёки мева',
        ],
      };
      final examples = foods[topic]![language.index];
      return switch (language) {
        AppLanguage.en =>
          'The difference is small and has no practical consequence; it can be covered by $examples.',
        AppLanguage.ru =>
          'Разница небольшая и практических последствий не имеет; её закроют $examples.',
        AppLanguage.uzLatn =>
          'Farq kichik va amaliy oqibati yoʻq; uni $examples bilan toʻldirish mumkin.',
        AppLanguage.uzCyrl =>
          'Фарқ кичик ва амалий оқибати йўқ; уни $examples билан тўлдириш мумкин.',
      };
    }
    return (below ? belowDetails : aboveDetails)[topic]![language.index];
  }

  List<AiAdviceEntry> _localMicronutrientAdviceItems(
    Map<String, Object?> snapshot,
    AppLanguage language,
  ) {
    final rawGaps = snapshot['micronutrient_reference_gaps'];
    final gaps = rawGaps is Map
        ? rawGaps.cast<Object?, Object?>()
        : const <Object?, Object?>{};
    const keys = [
      'fe',
      'mg',
      'ca',
      'p',
      'k',
      'na',
      'zn',
      'vit_a',
      'vit_c',
      'vit_d',
      'vit_e',
      'vit_k',
      'vit_b1',
      'vit_b2',
      'vit_b3',
      'vit_b6',
      'vit_b9',
      'vit_b12',
      'cu',
      'mn',
      'se',
      'i',
      'mo',
      'cr',
      'cl',
      'f',
      'vit_b4',
      'vit_h',
      'vit_b5',
    ];
    return [
      for (final key in keys)
        AiAdviceEntry(
          _topicForMicro(key),
          _micronutrientAdvice(key, gaps[key], snapshot, language),
        ),
    ];
  }

  AiAdviceTopic _topicForMicro(String key) =>
      AiAdviceTopic.forMicroKey(key) ?? (throw ArgumentError.value(key, 'key'));

  String _micronutrientAdvice(
    String key,
    Object? rawData,
    Map<String, Object?> snapshot,
    AppLanguage language,
  ) {
    if (rawData is! Map) return _dataUnavailable(language);
    final data = rawData.cast<Object?, Object?>();
    if (data['reference_per_day'] is! num) return _dataUnavailable(language);
    final period = '${snapshot['period'] ?? 'day'}';
    final loggedDays = (snapshot['logged_days'] as num?)?.toInt() ?? 0;
    return _micronutrientClause(key, data, language, period, loggedDays);
  }

  @visibleForTesting
  String micronutrientClauseForTesting(
    String key,
    Map<Object?, Object?> data,
    AppLanguage language, {
    String period = 'day',
    int loggedDays = 1,
  }) =>
      _micronutrientClause(key, data, language, period, loggedDays);

  String _micronutrientClause(
    String key,
    Map<Object?, Object?> data,
    AppLanguage language,
    String period,
    int loggedDays,
  ) {
    final reference = (data['reference_per_day'] as num).toDouble();
    final amountValue = data['average_per_logged_day'];
    final status = data['status'] as String?;
    final safetyStatus = data['safety_status'] as String?;
    final cdrr = (data['cdrr'] as num?)?.toDouble();
    final unit = _localizedMicroUnit('${data['unit'] ?? 'mg'}', language);
    final referenceText = _localizedNumber(reference, language);

    if (amountValue is! num || status == 'insufficient_data') {
      final sources = _microSources(key, language);
      return switch (language) {
        AppLanguage.en =>
          'No usable diary data; the personal reference is $referenceText $unit. Check intake using $sources.',
        AppLanguage.ru =>
          'Нет данных для расчёта; персональный ориентир — $referenceText $unit. Проверьте рацион по источникам: $sources.',
        AppLanguage.uzLatn =>
          'Hisoblash uchun maʼlumot yoʻq; shaxsiy moʻljal — $referenceText $unit. Manbalar: $sources.',
        AppLanguage.uzCyrl =>
          'Ҳисоблаш учун маълумот йўқ; шахсий мўлжал — $referenceText $unit. Манбалар: $sources.',
      };
    }

    final amount = amountValue.toDouble();
    final estimate = data['data_quality'] == 'low' ? '≈' : '';
    final amountText = '$estimate${_localizedNumber(amount, language)}';

    if (key == 'na' && cdrr != null) {
      return _sodiumAdvice(
        amount: amount,
        amountText: amountText,
        limit: cdrr,
        unit: unit,
        language: language,
      );
    }

    if (status == 'below_target_by' || status == 'below_ear_by') {
      final shortageText = _localizedNumber(reference - amount, language);
      final reading = _microShortageReading(
        amountText: amountText,
        referenceText: referenceText,
        shortageText: shortageText,
        unit: unit,
        language: language,
        period: period,
        loggedDays: loggedDays,
      );
      return '$reading ${_microShortageDetail(key, language)}';
    }

    // Intake above the safe upper limit (Tolerable Upper Intake Level). The
    // screen already flags this with an «Excess» chip; here the text must warn
    // about the excess and its consequences instead of listing more sources.
    if (safetyStatus == 'above_ul') {
      final ul = (data['ul'] as num?)?.toDouble();
      final ulText = _localizedNumber(ul ?? reference, language);
      final reading = _microExcessReading(
        amountText: amountText,
        referenceText: referenceText,
        ulText: ulText,
        unit: unit,
        language: language,
        period: period,
        loggedDays: loggedDays,
      );
      return '$reading ${_microExcessDetail(key, language)}';
    }

    final sources = _microSources(key, language);
    return switch (language) {
      AppLanguage.en =>
        '$amountText $unit against a $referenceText $unit reference; the target is met. Maintain it with $sources.',
      AppLanguage.ru =>
        '$amountText $unit при ориентире $referenceText $unit; нехватки нет. Поддерживайте уровень: $sources.',
      AppLanguage.uzLatn =>
        '$amountText $unit, moʻljal $referenceText $unit; kamlik yoʻq. Manbalar: $sources.',
      AppLanguage.uzCyrl =>
        '$amountText $unit, мўлжал $referenceText $unit; камлик йўқ. Манбалар: $sources.',
    };
  }

  String _microShortageReading({
    required String amountText,
    required String referenceText,
    required String shortageText,
    required String unit,
    required AppLanguage language,
    required String period,
    required int loggedDays,
  }) {
    if (period != 'day') {
      return switch (language) {
        AppLanguage.en =>
          '$amountText of $referenceText $unit on average across $loggedDays logged days; $shortageText $unit short.',
        AppLanguage.ru =>
          'В среднем $amountText из $referenceText $unit за $loggedDays заполненных дней; не хватает $shortageText $unit.',
        AppLanguage.uzLatn =>
          '$loggedDays qayd etilgan kunda oʻrtacha $referenceText $unit dan $amountText; $shortageText $unit kam.',
        AppLanguage.uzCyrl =>
          '$loggedDays қайд этилган кунда ўртача $referenceText $unit дан $amountText; $shortageText $unit кам.',
      };
    }
    return switch (language) {
      AppLanguage.en =>
        '$amountText of $referenceText $unit; $shortageText $unit short.',
      AppLanguage.ru =>
        '$amountText из $referenceText $unit; не хватает $shortageText $unit.',
      AppLanguage.uzLatn =>
        '$referenceText $unit dan $amountText; $shortageText $unit kam.',
      AppLanguage.uzCyrl =>
        '$referenceText $unit дан $amountText; $shortageText $unit кам.',
    };
  }

  String _microShortageDetail(String key, AppLanguage language) {
    const details = {
      'fe': [
        'A prolonged shortfall can cause weakness, fatigue, and anemia; add meat, legumes, or buckwheat.',
        'Длительная нехватка может вызывать слабость, утомляемость и анемию; добавьте мясо, бобовые или гречку.',
        'Uzoq davom etgan kamlik holsizlik, charchoq va kamqonlikka olib kelishi mumkin; goʻsht, dukkakli yoki grechka qoʻshing.',
        'Узоқ давом этган камлик ҳолсизлик, чарчоқ ва камқонликка олиб келиши мумкин; гўшт, дуккакли ёки гречка қўшинг.',
      ],
      'mg': [
        'Low intake can contribute to fatigue, muscle weakness, and cramps; choose nuts, beans, or buckwheat.',
        'Нехватка может приводить к утомляемости, мышечной слабости и судорогам; выберите орехи, фасоль или гречку.',
        'Kamlik charchoq, mushak zaifligi va tirishishga olib kelishi mumkin; yongʻoq, loviya yoki grechka tanlang.',
        'Камлик чарчоқ, мушак заифлиги ва тиришишга олиб келиши мумкин; ёнғоқ, ловия ёки гречка танланг.',
      ],
      'ca': [
        'A long-term shortfall weakens bones and raises fracture risk; add yogurt, cheese, or sardines.',
        'Длительный недобор ослабляет кости и повышает риск переломов; добавьте йогурт, сыр или сардины.',
        'Uzoq muddatli kamlik suyaklarni zaiflashtiradi va sinish xavfini oshiradi; yogurt, pishloq yoki sardina qoʻshing.',
        'Узоқ муддатли камлик суякларни заифлаштиради ва синиш хавфини оширади; йогурт, пишлоқ ёки сардина қўшинг.',
      ],
      'p': [
        'A prolonged shortfall can cause weakness and bone pain; choose fish, eggs, or cottage cheese.',
        'Длительная нехватка может вызывать слабость и боли в костях; выберите рыбу, яйца или творог.',
        'Uzoq davom etgan kamlik holsizlik va suyak ogʻrigʻiga olib kelishi mumkin; baliq, tuxum yoki tvorog tanlang.',
        'Узоқ давом этган камлик ҳолсизлик ва суяк оғриғига олиб келиши мумкин; балиқ, тухум ёки творог танланг.',
      ],
      'k': [
        'A sustained shortfall can cause weakness, cramps, and abnormal heart rhythm; add potatoes, beans, or dried apricots.',
        'Стойкая нехватка может вызывать слабость, судороги и нарушения сердечного ритма; добавьте картофель, фасоль или курагу.',
        'Doimiy kamlik holsizlik, tirishish va yurak ritmi buzilishiga olib kelishi mumkin; kartoshka, loviya yoki turshak qoʻshing.',
        'Доимий камлик ҳолсизлик, тиришиш ва юрак ритми бузилишига олиб келиши мумкин; картошка, ловия ёки туршак қўшинг.',
      ],
      'zn': [
        'A prolonged shortfall can weaken immunity and slow wound healing; add meat, pumpkin seeds, or legumes.',
        'Длительная нехватка может ослаблять иммунитет и замедлять заживление ран; добавьте мясо, тыквенные семечки или бобовые.',
        'Uzoq davom etgan kamlik immunitetni zaiflashtirishi va yaralar bitishini sekinlashtirishi mumkin; goʻsht, qovoq urugʻi yoki dukkakli qoʻshing.',
        'Узоқ давом этган камлик иммунитетни заифлаштириши ва яралар битишини секинлаштириши мумкин; гўшт, қовоқ уруғи ёки дуккакли қўшинг.',
      ],
      'vit_a': [
        'A prolonged shortfall can impair night vision and weaken immunity; add liver, carrots, or eggs.',
        'Длительная нехватка может ухудшать ночное зрение и ослаблять иммунитет; добавьте печень, морковь или яйца.',
        'Uzoq davom etgan kamlik tungi koʻrishni yomonlashtirishi va immunitetni zaiflashtirishi mumkin; jigar, sabzi yoki tuxum qoʻshing.',
        'Узоқ давом этган камлик тунги кўришни ёмонлаштириши ва иммунитетни заифлаштириши мумкин; жигар, сабзи ёки тухум қўшинг.',
      ],
      'vit_c': [
        'A prolonged shortfall can weaken immunity and slow wound healing; add citrus, bell pepper, or berries.',
        'Длительная нехватка может ослаблять иммунитет и замедлять заживление ран; добавьте цитрусовые, болгарский перец или ягоды.',
        'Uzoq davom etgan kamlik immunitetni zaiflashtirishi va yaralar bitishini sekinlashtirishi mumkin; sitrus, qalampir yoki rezavor meva qoʻshing.',
        'Узоқ давом этган камлик иммунитетни заифлаштириши ва яралар битишини секинлаштириши мумкин; ситрус, қалампир ёки резавор мева қўшинг.',
      ],
      'vit_d': [
        'A prolonged shortfall can weaken bones and reduce calcium absorption; add oily fish, eggs, or fortified dairy.',
        'Длительная нехватка может ослаблять кости и снижать усвоение кальция; добавьте жирную рыбу, яйца или обогащённые молочные продукты.',
        'Uzoq davom etgan kamlik suyaklarni zaiflashtirishi va kalsiy soʻrilishini kamaytirishi mumkin; yogʻli baliq, tuxum yoki vitaminlashtirilgan sut mahsuloti qoʻshing.',
        'Узоқ давом этган камлик суякларни заифлаштириши ва кальций сўрилишини камайтириши мумкин; ёғли балиқ, тухум ёки витаминлаштирилган сут маҳсулоти қўшинг.',
      ],
      'vit_e': [
        'A prolonged shortfall can affect nerve and muscle function; choose vegetable oil, nuts, or seeds.',
        'Длительная нехватка может влиять на работу нервов и мышц; выберите растительное масло, орехи или семечки.',
        'Uzoq davom etgan kamlik asab va mushak faoliyatiga taʼsir qilishi mumkin; oʻsimlik yogʻi, yongʻoq yoki urugʻ tanlang.',
        'Узоқ давом этган камлик асаб ва мушак фаолиятига таъсир қилиши мумкин; ўсимлик ёғи, ёнғоқ ёки уруғ танланг.',
      ],
      'vit_k': [
        'A prolonged shortfall can impair blood clotting; add leafy greens, broccoli, or vegetable oil.',
        'Длительная нехватка может ухудшать свёртываемость крови; добавьте листовую зелень, брокколи или растительное масло.',
        'Uzoq davom etgan kamlik qon ivishini yomonlashtirishi mumkin; bargli koʻkat, brokkoli yoki oʻsimlik yogʻi qoʻshing.',
        'Узоқ давом этган камлик қон ивишини ёмонлаштириши мумкин; баргли кўкат, брокколи ёки ўсимлик ёғи қўшинг.',
      ],
      'vit_b1': [
        'A prolonged shortfall can cause fatigue and nerve problems; add whole grains, legumes, or sunflower seeds.',
        'Длительная нехватка может вызывать усталость и нарушения работы нервов; добавьте цельные злаки, бобовые или семечки подсолнуха.',
        'Uzoq davom etgan kamlik charchoq va asab muammolariga olib kelishi mumkin; toʻliq don, dukkakli yoki kungaboqar urugʻi qoʻshing.',
        'Узоқ давом этган камлик чарчоқ ва асаб муаммоларига олиб келиши мумкин; тўлиқ дон, дуккакли ёки кунгабоқар уруғи қўшинг.',
      ],
      'vit_b2': [
        'A prolonged shortfall can cause cracked lips and skin problems; add milk, eggs, or almonds.',
        'Длительная нехватка может вызывать трещины в уголках губ и проблемы с кожей; добавьте молоко, яйца или миндаль.',
        'Uzoq davom etgan kamlik lab burchaklarida yoriqlar va teri muammolariga olib kelishi mumkin; sut, tuxum yoki bodom qoʻshing.',
        'Узоқ давом этган камлик лаб бурчакларида ёриқлар ва тери муаммоларига олиб келиши мумкин; сут, тухум ёки бодом қўшинг.',
      ],
      'vit_b3': [
        'A prolonged shortfall can cause fatigue and skin problems; add poultry, fish, or peanuts.',
        'Длительная нехватка может вызывать усталость и проблемы с кожей; добавьте птицу, рыбу или арахис.',
        'Uzoq davom etgan kamlik charchoq va teri muammolariga olib kelishi mumkin; parranda goʻshti, baliq yoki yeryongʻoq qoʻshing.',
        'Узоқ давом этган камлик чарчоқ ва тери муаммоларига олиб келиши мумкин; парранда гўшти, балиқ ёки ерёнғоқ қўшинг.',
      ],
      'vit_b6': [
        'A prolonged shortfall can cause anemia and low mood; add poultry, fish, or potatoes.',
        'Длительная нехватка может вызывать анемию и подавленное настроение; добавьте птицу, рыбу или картофель.',
        'Uzoq davom etgan kamlik kamqonlik va kayfiyat pasayishiga olib kelishi mumkin; parranda goʻshti, baliq yoki kartoshka qoʻshing.',
        'Узоқ давом этган камлик камқонлик ва кайфият пасайишига олиб келиши мумкин; парранда гўшти, балиқ ёки картошка қўшинг.',
      ],
      'vit_b9': [
        'A prolonged shortfall can cause anemia and fatigue; add leafy greens, legumes, or liver.',
        'Длительная нехватка может вызывать анемию и утомляемость; добавьте листовую зелень, бобовые или печень.',
        'Uzoq davom etgan kamlik kamqonlik va charchoqqa olib kelishi mumkin; bargli koʻkat, dukkakli yoki jigar qoʻshing.',
        'Узоқ давом этган камлик камқонлик ва чарчоққа олиб келиши мумкин; баргли кўкат, дуккакли ёки жигар қўшинг.',
      ],
      'vit_b12': [
        'A prolonged shortfall can cause anemia and nerve problems; add meat, fish, or dairy.',
        'Длительная нехватка может вызывать анемию и нарушения работы нервов; добавьте мясо, рыбу или молочные продукты.',
        'Uzoq davom etgan kamlik kamqonlik va asab muammolariga olib kelishi mumkin; goʻsht, baliq yoki sut mahsuloti qoʻshing.',
        'Узоқ давом этган камлик камқонлик ва асаб муаммоларига олиб келиши мумкин; гўшт, балиқ ёки сут маҳсулоти қўшинг.',
      ],
      'cu': [
        'A prolonged shortfall can cause anemia and weaken immunity; add liver, nuts, or seeds.',
        'Длительная нехватка может вызывать анемию и ослаблять иммунитет; добавьте печень, орехи или семечки.',
        'Uzoq davom etgan kamlik kamqonlik va immunitet zaifligiga olib kelishi mumkin; jigar, yongʻoq yoki urugʻ qoʻshing.',
        'Узоқ давом этган камлик камқонлик ва иммунитет заифлигига олиб келиши мумкин; жигар, ёнғоқ ёки уруғ қўшинг.',
      ],
      'mn': [
        'A prolonged shortfall can affect bone health and metabolism; add whole grains, nuts, or legumes.',
        'Длительная нехватка может влиять на здоровье костей и обмен веществ; добавьте цельные злаки, орехи или бобовые.',
        'Uzoq davom etgan kamlik suyak sogʻligʻi va moddalar almashinuviga taʼsir qilishi mumkin; toʻliq don, yongʻoq yoki dukkakli qoʻshing.',
        'Узоқ давом этган камлик суяк соғлиғи ва моддалар алмашинувига таъсир қилиши мумкин; тўлиқ дон, ёнғоқ ёки дуккакли қўшинг.',
      ],
      'se': [
        'A prolonged shortfall can weaken immunity and thyroid function; add fish, eggs, or nuts.',
        'Длительная нехватка может ослаблять иммунитет и работу щитовидной железы; добавьте рыбу, яйца или орехи.',
        'Uzoq davom etgan kamlik immunitet va qalqonsimon bez faoliyatini zaiflashtirishi mumkin; baliq, tuxum yoki yongʻoq qoʻshing.',
        'Узоқ давом этган камлик иммунитет ва қалқонсимон без фаолиятини заифлаштириши мумкин; балиқ, тухум ёки ёнғоқ қўшинг.',
      ],
      'i': [
        'A prolonged shortfall can impair thyroid function and cause goiter; add iodized salt, fish, or dairy.',
        'Длительная нехватка может нарушать работу щитовидной железы и вызывать зоб; добавьте йодированную соль, рыбу или молочные продукты.',
        'Uzoq davom etgan kamlik qalqonsimon bez faoliyatini buzishi va boʻqoqqa olib kelishi mumkin; yodlangan tuz, baliq yoki sut mahsuloti qoʻshing.',
        'Узоқ давом этган камлик қалқонсимон без фаолиятини бузиши ва бўқоққа олиб келиши мумкин; йодланган туз, балиқ ёки сут маҳсулоти қўшинг.',
      ],
      'mo': [
        'A shortfall is rare, but sustained low intake can affect enzyme function; add legumes, whole grains, or nuts.',
        'Нехватка встречается редко, но стойкий низкий уровень может влиять на работу ферментов; добавьте бобовые, цельные злаки или орехи.',
        'Kamlik kam uchraydi, ammo doimiy pastlik ferment faoliyatiga taʼsir qilishi mumkin; dukkakli, toʻliq don yoki yongʻoq qoʻshing.',
        'Камлик кам учрайди, аммо доимий пастлик фермент фаолиятига таъсир қилиши мумкин; дуккакли, тўлиқ дон ёки ёнғоқ қўшинг.',
      ],
      'cr': [
        'A dietary shortfall is uncommon and chromium plays only a minor role in carbohydrate metabolism; add whole grains, broccoli, or nuts.',
        'Дефицит в питании встречается нечасто, и хром играет лишь небольшую роль в обмене углеводов; добавьте цельные злаки, брокколи или орехи.',
        'Ratsiondagi kamlik kam uchraydi va xrom uglevod almashinuvida faqat kichik rol oʻynaydi; toʻliq don, brokkoli yoki yongʻoq qoʻshing.',
        'Рациондаги камлик кам учрайди ва хром углевод алмашинувида фақат кичик рол ўйнайди; тўлиқ дон, брокколи ёки ёнғоқ қўшинг.',
      ],
      'cl': [
        'A shortfall is uncommon and usually tied to heavy fluid loss; it comes mainly from table salt and vegetables.',
        'Нехватка встречается нечасто и обычно связана с большой потерей жидкости; поступает в основном из поваренной соли и овощей.',
        'Kamlik kam uchraydi va odatda koʻp suyuqlik yoʻqotish bilan bogʻliq; asosan osh tuzi va sabzavotdan olinadi.',
        'Камлик кам учрайди ва одатда кўп суюқлик йўқотиш билан боғлиқ; асосан ош тузи ва сабзавотдан олинади.',
      ],
      'f': [
        'A prolonged shortfall can raise the risk of tooth decay; it comes mainly from fluoridated water, tea, or fish.',
        'Длительная нехватка может повышать риск кариеса; поступает в основном из фторированной воды, чая или рыбы.',
        'Uzoq davom etgan kamlik tish kariyesi xavfini oshirishi mumkin; asosan ftorlangan suv, choy yoki baliqdan olinadi.',
        'Узоқ давом этган камлик тиш кариеси хавфини ошириши мумкин; асосан фторланган сув, чой ёки балиқдан олинади.',
      ],
      'vit_b4': [
        'A prolonged shortfall can affect liver and muscle function; add eggs, meat, or fish.',
        'Длительная нехватка может влиять на работу печени и мышц; добавьте яйца, мясо или рыбу.',
        'Uzoq davom etgan kamlik jigar va mushak faoliyatiga taʼsir qilishi mumkin; tuxum, goʻsht yoki baliq qoʻshing.',
        'Узоқ давом этган камлик жигар ва мушак фаолиятига таъсир қилиши мумкин; тухум, гўшт ёки балиқ қўшинг.',
      ],
      'vit_h': [
        'A prolonged shortfall can cause hair thinning and skin problems; add eggs, nuts, or legumes.',
        'Длительная нехватка может вызывать выпадение волос и проблемы с кожей; добавьте яйца, орехи или бобовые.',
        'Uzoq davom etgan kamlik soch toʻkilishi va teri muammolariga olib kelishi mumkin; tuxum, yongʻoq yoki dukkakli qoʻshing.',
        'Узоқ давом этган камлик соч тўкилиши ва тери муаммоларига олиб келиши мумкин; тухум, ёнғоқ ёки дуккакли қўшинг.',
      ],
      'vit_b5': [
        'A shortfall is rare, but sustained low intake can cause fatigue; add eggs, whole grains, or legumes.',
        'Нехватка встречается редко, но стойкий низкий уровень может вызывать усталость; добавьте яйца, цельные злаки или бобовые.',
        'Kamlik kam uchraydi, ammo doimiy pastlik charchoqqa olib kelishi mumkin; tuxum, toʻliq don yoki dukkakli qoʻshing.',
        'Камлик кам учрайди, аммо доимий пастлик чарчоққа олиб келиши мумкин; тухум, тўлиқ дон ёки дуккакли қўшинг.',
      ],
    };
    return details[key]?[language.index] ?? '';
  }

  String _microExcessReading({
    required String amountText,
    required String referenceText,
    required String ulText,
    required String unit,
    required AppLanguage language,
    required String period,
    required int loggedDays,
  }) {
    if (period != 'day') {
      return switch (language) {
        AppLanguage.en =>
          '$amountText $unit on average across $loggedDays logged days against $referenceText $unit; above the $ulText $unit safe upper limit.',
        AppLanguage.ru =>
          'В среднем $amountText $unit за $loggedDays заполненных дней при ориентире $referenceText $unit; выше безопасного предела $ulText $unit.',
        AppLanguage.uzLatn =>
          '$loggedDays qayd etilgan kunda oʻrtacha $amountText $unit, moʻljal $referenceText $unit; $ulText $unit xavfsiz chegaradan yuqori.',
        AppLanguage.uzCyrl =>
          '$loggedDays қайд этилган кунда ўртача $amountText $unit, мўлжал $referenceText $unit; $ulText $unit хавфсиз чегарадан юқори.',
      };
    }
    return switch (language) {
      AppLanguage.en =>
        '$amountText $unit against a $referenceText $unit reference; above the $ulText $unit safe upper limit.',
      AppLanguage.ru =>
        '$amountText $unit при ориентире $referenceText $unit; выше безопасного предела $ulText $unit.',
      AppLanguage.uzLatn =>
        '$amountText $unit, moʻljal $referenceText $unit; $ulText $unit xavfsiz chegaradan yuqori.',
      AppLanguage.uzCyrl =>
        '$amountText $unit, мўлжал $referenceText $unit; $ulText $unit хавфсиз чегарадан юқори.',
    };
  }

  String _microExcessDetail(String key, AppLanguage language) {
    const details = {
      'fe': [
        'A regular excess can cause nausea and constipation and, over time, strain the liver; cut back on iron supplements and organ meats.',
        'Регулярный избыток может вызывать тошноту и запоры, а со временем нагружать печень; сократите препараты железа и субпродукты.',
        'Muntazam ortiqcha koʻngil aynishi va ich qotishiga, vaqt oʻtib esa jigarga yuk boʻlishiga olib kelishi mumkin; temir qoʻshimchalari va ichak-jigar mahsulotlarini kamaytiring.',
        'Мунтазам ортиқча кўнгил айниши ва ич қотишига, вақт ўтиб эса жигарга юк бўлишига олиб келиши мумкин; темир қўшимчалари ва ичак-жигар маҳсулотларини камайтиринг.',
      ],
      'ca': [
        'A regular excess can raise the risk of kidney stones and hinder iron and zinc absorption; cut back on calcium supplements and very large dairy portions.',
        'Регулярный избыток может повышать риск камней в почках и мешать усвоению железа и цинка; сократите препараты кальция и очень большие порции молочного.',
        'Muntazam ortiqcha buyrak toshi xavfini oshirishi va temir hamda rux soʻrilishiga xalaqit berishi mumkin; kalsiy qoʻshimchalari va juda katta sut porsiyalarini kamaytiring.',
        'Мунтазам ортиқча буйрак тоши хавфини ошириши ва темир ҳамда рух сўрилишига халақит бериши мумкин; кальций қўшимчалари ва жуда катта сут порцияларини камайтиринг.',
      ],
      'p': [
        'A regular excess can upset calcium balance and bone health, especially with kidney problems; cut back on processed foods and cola drinks.',
        'Регулярный избыток может нарушать баланс кальция и здоровье костей, особенно при проблемах с почками; сократите переработанные продукты и колу.',
        'Muntazam ortiqcha kalsiy muvozanati va suyak sogʻligʻini buzishi mumkin, ayniqsa buyrak muammolarida; qayta ishlangan mahsulot va kola ichimliklarini kamaytiring.',
        'Мунтазам ортиқча кальций мувозанати ва суяк соғлиғини бузиши мумкин, айниқса буйрак муаммоларида; қайта ишланган маҳсулот ва кола ичимликларини камайтиринг.',
      ],
      'zn': [
        'A regular excess can impair copper absorption and weaken immunity; cut back on zinc supplements and very large portions of meat or seafood.',
        'Регулярный избыток может нарушать усвоение меди и ослаблять иммунитет; сократите препараты цинка и очень большие порции мяса или морепродуктов.',
        'Muntazam ortiqcha mis soʻrilishini buzishi va immunitetni zaiflashtirishi mumkin; rux qoʻshimchalari va juda katta goʻsht yoki dengiz mahsuloti porsiyalarini kamaytiring.',
        'Мунтазам ортиқча мис сўрилишини бузиши ва иммунитетни заифлаштириши мумкин; рух қўшимчалари ва жуда катта гўшт ёки денгиз маҳсулоти порцияларини камайтиринг.',
      ],
      'cu': [
        'A regular excess can cause nausea and stomach upset and strain the liver; cut back on copper supplements and large amounts of liver.',
        'Регулярный избыток может вызывать тошноту и расстройство желудка и нагружать печень; сократите препараты меди и большое количество печени.',
        'Muntazam ortiqcha koʻngil aynishi va oshqozon buzilishiga, jigarga yuk boʻlishiga olib kelishi mumkin; mis qoʻshimchalari va koʻp miqdordagi jigarni kamaytiring.',
        'Мунтазам ортиқча кўнгил айниши ва ошқозон бузилишига, жигарга юк бўлишига олиб келиши мумкин; мис қўшимчалари ва кўп миқдордаги жигарни камайтиринг.',
      ],
      'mn': [
        'A regular excess can affect the nervous system; cut back on manganese supplements and heavily fortified products.',
        'Регулярный избыток может влиять на нервную систему; сократите препараты марганца и сильно обогащённые продукты.',
        'Muntazam ortiqcha asab tizimiga taʼsir qilishi mumkin; marganes qoʻshimchalari va kuchli vitaminlashtirilgan mahsulotlarni kamaytiring.',
        'Мунтазам ортиқча асаб тизимига таъсир қилиши мумкин; марганес қўшимчалари ва кучли витаминлаштирилган маҳсулотларни камайтиринг.',
      ],
      'se': [
        'A regular excess can cause brittle hair and nails and stomach upset; cut back on selenium supplements and large amounts of Brazil nuts.',
        'Регулярный избыток может вызывать ломкость волос и ногтей и расстройство желудка; сократите препараты селена и большое количество бразильских орехов.',
        'Muntazam ortiqcha soch va tirnoqlarning moʻrtligiga hamda oshqozon buzilishiga olib kelishi mumkin; selen qoʻshimchalari va koʻp miqdordagi braziliya yongʻogʻini kamaytiring.',
        'Мунтазам ортиқча соч ва тирноқларнинг мўртлигига ҳамда ошқозон бузилишига олиб келиши мумкин; селен қўшимчалари ва кўп миқдордаги бразилия ёнғоғини камайтиринг.',
      ],
      'i': [
        'A regular excess can disturb thyroid function; cut back on iodine supplements, seaweed, and excess iodized salt.',
        'Регулярный избыток может нарушать работу щитовидной железы; сократите препараты йода, водоросли и избыток йодированной соли.',
        'Muntazam ortiqcha qalqonsimon bez faoliyatini buzishi mumkin; yod qoʻshimchalari, dengiz oʻti va ortiqcha yodlangan tuzni kamaytiring.',
        'Мунтазам ортиқча қалқонсимон без фаолиятини бузиши мумкин; йод қўшимчалари, денгиз ўти ва ортиқча йодланган тузни камайтиринг.',
      ],
      'mo': [
        'A regular excess is rare but can affect copper balance and joints; cut back on molybdenum supplements.',
        'Регулярный избыток встречается редко, но может влиять на баланс меди и суставы; сократите препараты молибдена.',
        'Muntazam ortiqcha kam uchraydi, ammo mis muvozanati va boʻgʻimlarga taʼsir qilishi mumkin; molibden qoʻshimchalarini kamaytiring.',
        'Мунтазам ортиқча кам учрайди, аммо мис мувозанати ва бўғимларга таъсир қилиши мумкин; молибден қўшимчаларини камайтиринг.',
      ],
      'cl': [
        'A regular excess usually comes with too much salt and can raise blood pressure; cut back on salt, sausages, and salty snacks.',
        'Регулярный избыток обычно связан с большим количеством соли и может повышать давление; сократите соль, колбасы и солёные снеки.',
        'Muntazam ortiqcha odatda koʻp tuz bilan bogʻliq va qon bosimini oshirishi mumkin; tuz, kolbasa va shoʻr gazaklarni kamaytiring.',
        'Мунтазам ортиқча одатда кўп туз билан боғлиқ ва қон босимини ошириши мумкин; туз, колбаса ва шўр газакларни камайтиринг.',
      ],
      'f': [
        'A prolonged excess can mottle teeth and, at high levels, affect bones; cut back on fluoride supplements and very strong tea.',
        'Длительный избыток может вызывать пятна на зубах, а при высоких уровнях влиять на кости; сократите препараты фтора и очень крепкий чай.',
        'Uzoq davom etgan ortiqcha tishlarda dogʻ paydo qilishi va yuqori darajada suyaklarga taʼsir qilishi mumkin; ftor qoʻshimchalari va juda achchiq choyni kamaytiring.',
        'Узоқ давом этган ортиқча тишларда доғ пайдо қилиши ва юқори даражада суякларга таъсир қилиши мумкин; фтор қўшимчалари ва жуда аччиқ чойни камайтиринг.',
      ],
      'vit_c': [
        'A regular excess can cause stomach upset and diarrhea and raise kidney-stone risk; cut back on high-dose vitamin C supplements.',
        'Регулярный избыток может вызывать расстройство желудка и диарею и повышать риск камней в почках; сократите высокие дозы витамина C в добавках.',
        'Muntazam ortiqcha oshqozon buzilishi va ich ketishiga olib kelishi hamda buyrak toshi xavfini oshirishi mumkin; yuqori dozadagi C vitamini qoʻshimchalarini kamaytiring.',
        'Мунтазам ортиқча ошқозон бузилиши ва ич кетишига олиб келиши ҳамда буйрак тоши хавфини ошириши мумкин; юқори дозадаги C витамини қўшимчаларини камайтиринг.',
      ],
      'vit_d': [
        'A regular excess can raise blood calcium and cause nausea and kidney problems; cut back on high-dose vitamin D supplements.',
        'Регулярный избыток может повышать кальций в крови и вызывать тошноту и проблемы с почками; сократите высокие дозы витамина D в добавках.',
        'Muntazam ortiqcha qondagi kalsiyni oshirishi va koʻngil aynishi hamda buyrak muammolariga olib kelishi mumkin; yuqori dozadagi D vitamini qoʻshimchalarini kamaytiring.',
        'Мунтазам ортиқча қондаги кальцийни ошириши ва кўнгил айниши ҳамда буйрак муаммоларига олиб келиши мумкин; юқори дозадаги D витамини қўшимчаларини камайтиринг.',
      ],
      'vit_b6': [
        'A prolonged excess can damage nerves and cause tingling in the hands and feet; cut back on high-dose vitamin B6 supplements.',
        'Длительный избыток может повреждать нервы и вызывать покалывание в руках и ногах; сократите высокие дозы витамина B6 в добавках.',
        'Uzoq davom etgan ortiqcha asablarni shikastlashi va qoʻl-oyoqda achishishga olib kelishi mumkin; yuqori dozadagi B6 vitamini qoʻshimchalarini kamaytiring.',
        'Узоқ давом этган ортиқча асабларни шикастлаши ва қўл-оёқда ачишишга олиб келиши мумкин; юқори дозадаги B6 витамини қўшимчаларини камайтиринг.',
      ],
      'vit_b4': [
        'A regular excess can cause low blood pressure, sweating, and a fishy body odor; cut back on choline supplements.',
        'Регулярный избыток может вызывать низкое давление, потливость и рыбный запах тела; сократите добавки холина.',
        'Muntazam ortiqcha past qon bosimi, terlash va tanadan baliq hidi kelishiga olib kelishi mumkin; xolin qoʻshimchalarini kamaytiring.',
        'Мунтазам ортиқча паст қон босими, терлаш ва танадан балиқ ҳиди келишига олиб келиши мумкин; холин қўшимчаларини камайтиринг.',
      ],
    };
    return details[key]?[language.index] ?? _microExcessGeneric(language);
  }

  String _microExcessGeneric(AppLanguage language) => switch (language) {
        AppLanguage.en =>
          'A regular excess offers no extra benefit and can burden the body; cut back on supplements and very concentrated sources.',
        AppLanguage.ru =>
          'Регулярный избыток не даёт дополнительной пользы и может нагружать организм; сократите добавки и очень концентрированные источники.',
        AppLanguage.uzLatn =>
          'Muntazam ortiqcha qoʻshimcha foyda bermaydi va organizmga yuk boʻlishi mumkin; qoʻshimchalar va juda konsentrlangan manbalarni kamaytiring.',
        AppLanguage.uzCyrl =>
          'Мунтазам ортиқча қўшимча фойда бермайди ва организмга юк бўлиши мумкин; қўшимчалар ва жуда концентрланган манбаларни камайтиринг.',
      };

  String _microSources(String key, AppLanguage language) {
    const sources = {
      'fe': [
        'meat, legumes, or buckwheat',
        'мясо, бобовые или гречка',
        'goʻsht, dukkakli yoki grechka',
        'гўшт, дуккакли ёки гречка',
      ],
      'mg': [
        'nuts, beans, or buckwheat',
        'орехи, фасоль или гречка',
        'yongʻoq, loviya yoki grechka',
        'ёнғоқ, ловия ёки гречка',
      ],
      'ca': [
        'yogurt, cheese, or sardines',
        'йогурт, сыр или сардины',
        'yogurt, pishloq yoki sardina',
        'йогурт, пишлоқ ёки сардина',
      ],
      'p': [
        'fish, eggs, or cottage cheese',
        'рыба, яйца или творог',
        'baliq, tuxum yoki tvorog',
        'балиқ, тухум ёки творог',
      ],
      'k': [
        'potatoes, beans, or dried apricots',
        'картофель, фасоль или курага',
        'kartoshka, loviya yoki turshak',
        'картошка, ловия ёки туршак',
      ],
      'na': [
        'sausages, chips, or salty sauces',
        'колбасы, чипсы или солёные соусы',
        'kolbasa, chips yoki shoʻr sous',
        'колбаса, чипс ёки шўр соус',
      ],
      'zn': [
        'meat, pumpkin seeds, or legumes',
        'мясо, тыквенные семечки или бобовые',
        'goʻsht, qovoq urugʻi yoki dukkakli',
        'гўшт, қовоқ уруғи ёки дуккакли',
      ],
      'vit_a': [
        'liver, carrots, or eggs',
        'печень, морковь или яйца',
        'jigar, sabzi yoki tuxum',
        'жигар, сабзи ёки тухум',
      ],
      'vit_c': [
        'citrus, bell pepper, or berries',
        'цитрусовые, болгарский перец или ягоды',
        'sitrus, qalampir yoki rezavor meva',
        'ситрус, қалампир ёки резавор мева',
      ],
      'vit_d': [
        'oily fish, eggs, or fortified dairy',
        'жирная рыба, яйца или обогащённые молочные продукты',
        'yogʻli baliq, tuxum yoki vitaminlashtirilgan sut',
        'ёғли балиқ, тухум ёки витаминлаштирилган сут',
      ],
      'vit_e': [
        'vegetable oil, nuts, or seeds',
        'растительное масло, орехи или семечки',
        'oʻsimlik yogʻi, yongʻoq yoki urugʻ',
        'ўсимлик ёғи, ёнғоқ ёки уруғ',
      ],
      'vit_k': [
        'leafy greens, broccoli, or vegetable oil',
        'листовая зелень, брокколи или растительное масло',
        'bargli koʻkat, brokkoli yoki oʻsimlik yogʻi',
        'баргли кўкат, брокколи ёки ўсимлик ёғи',
      ],
      'vit_b1': [
        'whole grains, legumes, or sunflower seeds',
        'цельные злаки, бобовые или семечки подсолнуха',
        'toʻliq don, dukkakli yoki kungaboqar urugʻi',
        'тўлиқ дон, дуккакли ёки кунгабоқар уруғи',
      ],
      'vit_b2': [
        'milk, eggs, or almonds',
        'молоко, яйца или миндаль',
        'sut, tuxum yoki bodom',
        'сут, тухум ёки бодом',
      ],
      'vit_b3': [
        'poultry, fish, or peanuts',
        'птица, рыба или арахис',
        'parranda goʻshti, baliq yoki yeryongʻoq',
        'парранда гўшти, балиқ ёки ерёнғоқ',
      ],
      'vit_b6': [
        'poultry, fish, or potatoes',
        'птица, рыба или картофель',
        'parranda goʻshti, baliq yoki kartoshka',
        'парранда гўшти, балиқ ёки картошка',
      ],
      'vit_b9': [
        'leafy greens, legumes, or liver',
        'листовая зелень, бобовые или печень',
        'bargli koʻkat, dukkakli yoki jigar',
        'баргли кўкат, дуккакли ёки жигар',
      ],
      'vit_b12': [
        'meat, fish, or dairy',
        'мясо, рыба или молочные продукты',
        'goʻsht, baliq yoki sut mahsuloti',
        'гўшт, балиқ ёки сут маҳсулоти',
      ],
      'cu': [
        'liver, nuts, or seeds',
        'печень, орехи или семечки',
        'jigar, yongʻoq yoki urugʻ',
        'жигар, ёнғоқ ёки уруғ',
      ],
      'mn': [
        'whole grains, nuts, or legumes',
        'цельные злаки, орехи или бобовые',
        'toʻliq don, yongʻoq yoki dukkakli',
        'тўлиқ дон, ёнғоқ ёки дуккакли',
      ],
      'se': [
        'fish, eggs, or nuts',
        'рыба, яйца или орехи',
        'baliq, tuxum yoki yongʻoq',
        'балиқ, тухум ёки ёнғоқ',
      ],
      'i': [
        'iodized salt, fish, or dairy',
        'йодированная соль, рыба или молочные продукты',
        'yodlangan tuz, baliq yoki sut mahsuloti',
        'йодланган туз, балиқ ёки сут маҳсулоти',
      ],
      'mo': [
        'legumes, whole grains, or nuts',
        'бобовые, цельные злаки или орехи',
        'dukkakli, toʻliq don yoki yongʻoq',
        'дуккакли, тўлиқ дон ёки ёнғоқ',
      ],
      'cr': [
        'whole grains, broccoli, or nuts',
        'цельные злаки, брокколи или орехи',
        'toʻliq don, brokkoli yoki yongʻoq',
        'тўлиқ дон, брокколи ёки ёнғоқ',
      ],
      'cl': [
        'table salt or vegetables',
        'поваренная соль или овощи',
        'osh tuzi yoki sabzavot',
        'ош тузи ёки сабзавот',
      ],
      'f': [
        'fluoridated water, tea, or fish',
        'фторированная вода, чай или рыба',
        'ftorlangan suv, choy yoki baliq',
        'фторланган сув, чой ёки балиқ',
      ],
      'vit_b4': [
        'eggs, meat, or fish',
        'яйца, мясо или рыба',
        'tuxum, goʻsht yoki baliq',
        'тухум, гўшт ёки балиқ',
      ],
      'vit_h': [
        'eggs, nuts, or legumes',
        'яйца, орехи или бобовые',
        'tuxum, yongʻoq yoki dukkakli',
        'тухум, ёнғоқ ёки дуккакли',
      ],
      'vit_b5': [
        'eggs, whole grains, or legumes',
        'яйца, цельные злаки или бобовые',
        'tuxum, toʻliq don yoki dukkakli',
        'тухум, тўлиқ дон ёки дуккакли',
      ],
    };
    return sources[key]?[language.index] ?? '';
  }

  String _sodiumAdvice({
    required double amount,
    required String amountText,
    required double limit,
    required String unit,
    required AppLanguage language,
  }) {
    final limitText = _localizedNumber(limit, language);
    final over = amount > limit;
    final gapText = _localizedNumber((amount - limit).abs(), language);
    return switch ((language, over)) {
      (AppLanguage.en, true) =>
        '$amountText $unit against a $limitText $unit limit; $gapText $unit over. A persistent excess raises blood-pressure risk; reduce sausages, chips, or salty sauces.',
      (AppLanguage.ru, true) =>
        '$amountText $unit при лимите $limitText $unit; превышение $gapText $unit. Постоянный избыток повышает риск высокого давления; сократите колбасы, чипсы или солёные соусы.',
      (AppLanguage.uzLatn, true) =>
        '$amountText $unit, chegara $limitText $unit; $gapText $unit ortiq. Doimiy ortiqcha miqdor yuqori qon bosimi xavfini oshiradi; kolbasa, chips yoki shoʻr sousni kamaytiring.',
      (AppLanguage.uzCyrl, true) =>
        '$amountText $unit, чегара $limitText $unit; $gapText $unit ортиқ. Доимий ортиқча миқдор юқори қон босими хавфини оширади; колбаса, чипс ёки шўр соусни камайтиринг.',
      (AppLanguage.en, false) =>
        '$amountText $unit against the $limitText $unit limit; there is no excess. Keep limiting sausages, chips, and salty sauces because regular excess raises blood pressure.',
      (AppLanguage.ru, false) =>
        '$amountText $unit при лимите $limitText $unit; превышения нет. Сохраняйте умеренность в колбасах, чипсах и солёных соусах: регулярный избыток повышает давление.',
      (AppLanguage.uzLatn, false) =>
        '$amountText $unit, chegara $limitText $unit; ortiqcha emas. Kolbasa, chips va shoʻr sousni cheklang: muntazam ortiqcha miqdor qon bosimini oshiradi.',
      (AppLanguage.uzCyrl, false) =>
        '$amountText $unit, чегара $limitText $unit; ортиқча эмас. Колбаса, чипс ва шўр соусни чекланг: мунтазам ортиқча миқдор қон босимини оширади.',
    };
  }

  String _dataUnavailable(AppLanguage language) {
    return switch (language) {
      AppLanguage.en =>
        'There is not enough profile or food-composition data to estimate this item reliably yet.',
      AppLanguage.ru =>
        'Пока недостаточно данных профиля или состава продуктов, чтобы надёжно оценить этот пункт.',
      AppLanguage.uzLatn =>
        'Bu bandni ishonchli baholash uchun profil yoki mahsulot tarkibi maʼlumoti yetarli emas.',
      AppLanguage.uzCyrl =>
        'Бу бандни ишончли баҳолаш учун профиль ёки маҳсулот таркиби маълумоти етарли эмас.',
    };
  }

  String _localizedMicroUnit(String unit, AppLanguage language) {
    // Reference units include mcg, mcg_rae (vit A) and mcg_dfe (folate) — all
    // shown as micrograms — versus mg and mg_ne (niacin), shown as milligrams.
    final isMicrograms = unit.startsWith('mcg');
    if (language == AppLanguage.ru || language == AppLanguage.uzCyrl) {
      return isMicrograms ? 'мкг' : 'мг';
    }
    return isMicrograms ? 'mcg' : 'mg';
  }

  String _localizedNumber(double value, AppLanguage language) {
    final rounded = value.abs() >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    return language == AppLanguage.ru || language == AppLanguage.uzCyrl
        ? rounded.replaceAll('.', ',')
        : rounded;
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

  // Маппит код серверной ошибки на категорию, понятную UI. Серверный message
  // намеренно не используется как текст для пользователя — он уходит только в
  // debugMessage/debugPrint.
  AiAdviceErrorKind _functionErrorKind(FirebaseFunctionsException error) =>
      switch (error.code) {
        'resource-exhausted' => AiAdviceErrorKind.rateLimited,
        'deadline-exceeded' => AiAdviceErrorKind.timeout,
        'unavailable' => AiAdviceErrorKind.network,
        _ => AiAdviceErrorKind.generic,
      };

  static double _round(double value) => double.parse(value.toStringAsFixed(2));

  static String _languageName(AppLanguage language) => switch (language) {
        AppLanguage.en => 'English',
        AppLanguage.ru => 'Russian',
        AppLanguage.uzLatn => 'Uzbek in Latin script',
        AppLanguage.uzCyrl => 'Uzbek in Cyrillic script',
      };

  static const _microNames = {
    'fiber': 'fiber',
    'sugar': 'sugar',
    'fe': 'iron',
    'mg': 'magnesium',
    'ca': 'calcium',
    'p': 'phosphorus',
    'k': 'potassium',
    'na': 'sodium',
    'zn': 'zinc',
    'cl': 'chloride',
    's': 'sulfur',
    'mn': 'manganese',
    'cu': 'copper',
    'se': 'selenium',
    'i': 'iodine',
    'f': 'fluoride',
    'cr': 'chromium',
    'mo': 'molybdenum',
    'co': 'cobalt',
    'vit_c': 'vitamin C',
    'vit_a': 'vitamin A',
    'vit_d': 'vitamin D',
    'vit_e': 'vitamin E',
    'vit_k': 'vitamin K',
    'vit_h': 'biotin (vitamin B7)',
    'vit_b1': 'thiamin (vitamin B1)',
    'vit_b2': 'riboflavin (vitamin B2)',
    'vit_b3': 'niacin (vitamin B3)',
    'vit_b4': 'choline (vitamin B4)',
    'vit_b5': 'pantothenic acid (vitamin B5)',
    'vit_b6': 'vitamin B6',
    'vit_b9': 'folate (vitamin B9)',
    'vit_b12': 'vitamin B12',
  };

  static const _microUnits = {
    'fiber': 'g',
    'sugar': 'g',
    'fe': 'mg',
    'mg': 'mg',
    'ca': 'mg',
    'p': 'mg',
    'k': 'mg',
    'na': 'mg',
    'zn': 'mg',
    'cl': 'mg',
    's': 'mg',
    'mn': 'mg',
    'cu': 'mg',
    'se': 'mcg',
    'i': 'mcg',
    'f': 'mcg',
    'cr': 'mcg',
    'mo': 'mcg',
    'co': 'mcg',
    'vit_c': 'mg',
    'vit_a': 'mcg',
    'vit_d': 'mcg',
    'vit_e': 'mg',
    'vit_k': 'mcg',
    'vit_h': 'mcg',
    'vit_b1': 'mg',
    'vit_b2': 'mg',
    'vit_b3': 'mg_ne',
    'vit_b4': 'mg',
    'vit_b5': 'mg',
    'vit_b6': 'mg',
    'vit_b9': 'mcg_dfe',
    'vit_b12': 'mcg',
  };
}

/// Категория ошибки ИИ-совета, понятная UI. Имя значения совпадает с суффиксом
/// ключа локализации `ai.error.*`, поэтому экран берёт текст как
/// `l.t('ai.error.${kind.name}')` — без англоязычных серверных строк.
enum AiAdviceErrorKind { rateLimited, network, timeout, generic }

class AiAdviceException implements Exception {
  final AiAdviceErrorKind kind;

  /// Технические детали (серверный message, код исключения) — только для
  /// debugPrint; пользователю не показываются.
  final String debugMessage;

  const AiAdviceException(this.kind, [this.debugMessage = '']);

  /// Ключ локализации для этой ошибки (`ai.error.rateLimited` и т.п.).
  String get l10nKey => 'ai.error.${kind.name}';

  @override
  String toString() => debugMessage.isEmpty
      ? 'AiAdviceException(${kind.name})'
      : 'AiAdviceException(${kind.name}): $debugMessage';
}
