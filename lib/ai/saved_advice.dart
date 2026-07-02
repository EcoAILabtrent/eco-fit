import 'ai_advice_service.dart';

/// Один сохранённый нутриент со значением и нормой — чтобы вкладка
/// «Сохранённые» могла отрисовать те же шкалы, что и свежий совет.
class SavedNutrient {
  final String key;
  final double value;
  final double target;

  /// true — превышение (для критичного нутриента-избытка), иначе дефицит/бар.
  final bool excess;

  const SavedNutrient({
    required this.key,
    required this.value,
    required this.target,
    this.excess = false,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'target': target,
        if (excess) 'excess': true,
      };

  static SavedNutrient fromMap(Map<dynamic, dynamic> m) => SavedNutrient(
        key: (m['key'] as String?) ?? '',
        value: (m['value'] as num?)?.toDouble() ?? 0,
        target: (m['target'] as num?)?.toDouble() ?? 0,
        excess: m['excess'] == true,
      );
}

/// An AI nutrition advice the user chose to keep. Persisted in Hive as part of
/// the app store (see `AppStore.aiAdvices`) so saved advice survives restarts.
class SavedAiAdvice {
  /// Stable id (milliseconds-since-epoch string) used for deletion.
  final String id;

  /// Raw advice text (newline-separated bullet points).
  final String text;

  /// Period the advice was generated for (day / week / month).
  final AiAdvicePeriod period;

  /// When the advice was generated/saved.
  final DateTime createdAt;

  /// Language the advice was generated in (`AppLanguage.code`).
  final String languageCode;

  /// Критичные нутриенты на момент сохранения (заголовок + шкала + текст).
  final List<SavedNutrient> criticals;

  /// Все микронутриенты за период на момент сохранения (шкалы без текста).
  final List<SavedNutrient> micros;

  const SavedAiAdvice({
    required this.id,
    required this.text,
    required this.period,
    required this.createdAt,
    required this.languageCode,
    this.criticals = const [],
    this.micros = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'period': period.name,
        'createdAt': createdAt.toIso8601String(),
        'languageCode': languageCode,
        if (criticals.isNotEmpty)
          'criticals': criticals.map((e) => e.toMap()).toList(),
        if (micros.isNotEmpty) 'micros': micros.map((e) => e.toMap()).toList(),
      };

  static SavedAiAdvice fromMap(Map<dynamic, dynamic> m) {
    final rawCreated = m['createdAt'] as String?;
    List<SavedNutrient> parseList(Object? raw) => raw is List
        ? raw
            .whereType<Map<dynamic, dynamic>>()
            .map(SavedNutrient.fromMap)
            .toList()
        : const <SavedNutrient>[];
    return SavedAiAdvice(
      id: (m['id'] as String?) ?? rawCreated ?? '',
      text: (m['text'] as String?) ?? '',
      period: AiAdvicePeriod.values.firstWhere(
        (p) => p.name == m['period'],
        orElse: () => AiAdvicePeriod.day,
      ),
      createdAt: rawCreated == null
          ? DateTime.now()
          : DateTime.tryParse(rawCreated) ?? DateTime.now(),
      languageCode: (m['languageCode'] as String?) ?? 'ru',
      criticals: parseList(m['criticals']),
      micros: parseList(m['micros']),
    );
  }
}
