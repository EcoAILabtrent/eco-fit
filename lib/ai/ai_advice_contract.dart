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
  sodium('sodium');

  final String id;

  const AiAdviceTopic(this.id);

  static AiAdviceTopic? fromId(Object? value) {
    if (value is! String) return null;
    for (final topic in values) {
      if (topic.id == value) return topic;
    }
    return null;
  }
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
