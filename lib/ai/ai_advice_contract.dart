import '../l10n/app_language.dart';

enum AiAdviceTopic {
  calories('calories'),
  protein('protein'),
  fat('fat'),
  carbohydrates('carbohydrates'),
  iron('iron'),
  magnesium('magnesium'),
  calcium('calcium'),
  phosphorus('phosphorus'),
  potassium('potassium'),
  sodium('sodium'),
  zinc('zinc'),
  vitaminA('vitamin_a'),
  vitaminC('vitamin_c'),
  vitaminD('vitamin_d'),
  vitaminE('vitamin_e'),
  vitaminK('vitamin_k'),
  vitaminB1('vitamin_b1'),
  vitaminB2('vitamin_b2'),
  vitaminB3('vitamin_b3'),
  vitaminB6('vitamin_b6'),
  vitaminB9('vitamin_b9'),
  vitaminB12('vitamin_b12'),
  copper('copper'),
  manganese('manganese'),
  selenium('selenium'),
  iodine('iodine'),
  molybdenum('molybdenum'),
  chromium('chromium'),
  chloride('chloride'),
  fluoride('fluoride'),
  choline('choline'),
  biotin('biotin'),
  pantothenicAcid('pantothenic_acid');

  final String id;

  const AiAdviceTopic(this.id);

  static AiAdviceTopic? fromId(Object? value) {
    if (value is! String) return null;
    for (final topic in values) {
      if (topic.id == value) return topic;
    }
    return null;
  }

  /// Maps a micronutrient DB key (`nutrients.code`) to its advice topic, or
  /// null for keys without a dedicated topic (sulfur `s`, cobalt `co`, fiber,
  /// sugar). Single source of truth shared by advice generation
  /// (`AiAdviceService`) and the critical-values detection on the AI screen —
  /// keep every key that carries a UL/CDRR here so it can surface as critical.
  static AiAdviceTopic? forMicroKey(String key) => switch (key) {
        'fe' => iron,
        'mg' => magnesium,
        'ca' => calcium,
        'p' => phosphorus,
        'k' => potassium,
        'na' => sodium,
        'zn' => zinc,
        'vit_a' => vitaminA,
        'vit_c' => vitaminC,
        'vit_d' => vitaminD,
        'vit_e' => vitaminE,
        'vit_k' => vitaminK,
        'vit_b1' => vitaminB1,
        'vit_b2' => vitaminB2,
        'vit_b3' => vitaminB3,
        'vit_b6' => vitaminB6,
        'vit_b9' => vitaminB9,
        'vit_b12' => vitaminB12,
        'cu' => copper,
        'mn' => manganese,
        'se' => selenium,
        'i' => iodine,
        'mo' => molybdenum,
        'cr' => chromium,
        'cl' => chloride,
        'f' => fluoride,
        'vit_b4' => choline,
        'vit_h' => biotin,
        'vit_b5' => pantothenicAcid,
        _ => null,
      };
}

class AiAdviceEntry {
  final AiAdviceTopic topic;
  final String text;

  const AiAdviceEntry(this.topic, this.text);
}

class AiAdviceContract {
  AiAdviceContract._();

  static List<AiAdviceEntry> parseFunctionResult(Object? data) {
    if (data is! Map || data['schemaVersion'] != 2) return const [];
    final rawItems = data['items'];
    if (rawItems is! List) return const [];

    final seen = <AiAdviceTopic>{};
    final parsed = <AiAdviceEntry>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final topic = AiAdviceTopic.fromId(rawItem['id']);
      final text = _clean(rawItem['text']);
      if (topic == null || text.length < 12 || !seen.add(topic)) continue;
      parsed.add(AiAdviceEntry(topic, text));
    }
    return parsed;
  }

  static List<AiAdviceEntry> merge({
    required Iterable<AiAdviceEntry> aiItems,
    required Iterable<AiAdviceEntry> fallbackItems,
  }) {
    final byTopic = <AiAdviceTopic, AiAdviceEntry>{};
    for (final item in fallbackItems) {
      byTopic.putIfAbsent(item.topic, () => item);
    }
    for (final item in aiItems) {
      if (item.text.length >= 12) byTopic[item.topic] = item;
    }
    return [
      for (final topic in AiAdviceTopic.values)
        if (byTopic[topic] case final item?) item,
    ];
  }

  static String format(Iterable<AiAdviceEntry> items, AppLanguage language) {
    final byTopic = {for (final item in items) item.topic: item};
    return [
      for (final topic in AiAdviceTopic.values)
        if (byTopic[topic] case final item?)
          '${title(topic, language)}: ${_withFinalPunctuation(_withoutLeadingTitle(topic, item.text))}',
    ].join('\n');
  }

  static String title(AiAdviceTopic topic, AppLanguage language) {
    const titles = {
      AiAdviceTopic.calories: ['Calories', 'Калории', 'Kaloriya', 'Калория'],
      AiAdviceTopic.protein: ['Protein', 'Белок', 'Oqsil', 'Оқсил'],
      AiAdviceTopic.fat: ['Fat', 'Жиры', "Yog'lar", 'Ёғлар'],
      AiAdviceTopic.carbohydrates: [
        'Carbohydrates',
        'Углеводы',
        'Uglevodlar',
        'Углеводлар',
      ],
      AiAdviceTopic.iron: ['Iron', 'Железо', 'Temir', 'Темир'],
      AiAdviceTopic.magnesium: ['Magnesium', 'Магний', 'Magniy', 'Магний'],
      AiAdviceTopic.calcium: ['Calcium', 'Кальций', 'Kalsiy', 'Кальций'],
      AiAdviceTopic.phosphorus: ['Phosphorus', 'Фосфор', 'Fosfor', 'Фосфор'],
      AiAdviceTopic.potassium: ['Potassium', 'Калий', 'Kaliy', 'Калий'],
      AiAdviceTopic.sodium: ['Sodium', 'Натрий', 'Natriy', 'Натрий'],
      AiAdviceTopic.zinc: ['Zinc', 'Цинк', 'Rux', 'Рух'],
      AiAdviceTopic.vitaminA: [
        'Vitamin A',
        'Витамин A',
        'Vitamin A',
        'Витамин A',
      ],
      AiAdviceTopic.vitaminC: [
        'Vitamin C',
        'Витамин C',
        'Vitamin C',
        'Витамин C',
      ],
      AiAdviceTopic.vitaminD: [
        'Vitamin D',
        'Витамин D',
        'Vitamin D',
        'Витамин D',
      ],
      AiAdviceTopic.vitaminE: [
        'Vitamin E',
        'Витамин E',
        'Vitamin E',
        'Витамин E',
      ],
      AiAdviceTopic.vitaminK: [
        'Vitamin K',
        'Витамин K',
        'Vitamin K',
        'Витамин K',
      ],
      AiAdviceTopic.vitaminB1: [
        'Vitamin B1',
        'Витамин B1',
        'Vitamin B1',
        'Витамин B1',
      ],
      AiAdviceTopic.vitaminB2: [
        'Vitamin B2',
        'Витамин B2',
        'Vitamin B2',
        'Витамин B2',
      ],
      AiAdviceTopic.vitaminB3: [
        'Vitamin B3',
        'Витамин B3',
        'Vitamin B3',
        'Витамин B3',
      ],
      AiAdviceTopic.vitaminB6: [
        'Vitamin B6',
        'Витамин B6',
        'Vitamin B6',
        'Витамин B6',
      ],
      AiAdviceTopic.vitaminB9: [
        'Folate (B9)',
        'Фолат (B9)',
        'Folat (B9)',
        'Фолат (B9)',
      ],
      AiAdviceTopic.vitaminB12: [
        'Vitamin B12',
        'Витамин B12',
        'Vitamin B12',
        'Витамин B12',
      ],
      AiAdviceTopic.copper: ['Copper', 'Медь', 'Mis', 'Мис'],
      AiAdviceTopic.manganese: [
        'Manganese',
        'Марганец',
        'Marganes',
        'Марганес',
      ],
      AiAdviceTopic.selenium: ['Selenium', 'Селен', 'Selen', 'Селен'],
      AiAdviceTopic.iodine: ['Iodine', 'Йод', 'Yod', 'Йод'],
      AiAdviceTopic.molybdenum: [
        'Molybdenum',
        'Молибден',
        'Molibden',
        'Молибден',
      ],
      AiAdviceTopic.chromium: ['Chromium', 'Хром', 'Xrom', 'Хром'],
      AiAdviceTopic.chloride: ['Chloride', 'Хлор', 'Xlor', 'Хлор'],
      AiAdviceTopic.fluoride: ['Fluoride', 'Фтор', 'Ftor', 'Фтор'],
      AiAdviceTopic.choline: ['Choline', 'Холин', 'Xolin', 'Холин'],
      AiAdviceTopic.biotin: ['Biotin', 'Биотин', 'Biotin', 'Биотин'],
      AiAdviceTopic.pantothenicAcid: [
        'Vitamin B5',
        'Витамин B5',
        'Vitamin B5',
        'Витамин B5',
      ],
    };
    return titles[topic]![language.index];
  }

  static String _clean(Object? value) {
    if (value is! String) return '';
    final cleaned = value
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp('^\\s*(?:[-*]|\\u2022)\\s*'), '')
        .replaceAll(RegExp(r'^\s*\d+[\).]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length <= 700 ? cleaned : cleaned.substring(0, 700).trim();
  }

  static String _withoutLeadingTitle(AiAdviceTopic topic, String value) {
    var result = value.trim();
    for (final language in AppLanguage.values) {
      final heading = RegExp.escape(title(topic, language));
      result = result.replaceFirst(
        RegExp('^$heading\\s*[:—-]\\s*', caseSensitive: false),
        '',
      );
    }
    return result.trim();
  }

  static String _withFinalPunctuation(String value) {
    if (value.isEmpty || RegExp(r'[.!?]$').hasMatch(value)) return value;
    return '$value.';
  }
}
