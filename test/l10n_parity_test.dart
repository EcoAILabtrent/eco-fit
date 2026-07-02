import 'dart:io';

import 'package:eco_mobile/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// Гарантия, что во всех четырёх языках `AppStrings._strings` определён один и
/// тот же набор ключей. Тест читает исходник напрямую, поэтому ловит и
/// рассинхрон между языками, и случайные опечатки/дубликаты в ключах, не завися
/// от приватного поля.
void main() {
  final source = File('lib/l10n/app_strings.dart').readAsStringSync();
  final byLanguage = _parseKeys(source);

  test('парсер нашёл ровно четыре языковых блока', () {
    expect(byLanguage.keys.toSet(), {'en', 'ru', 'uzLatn', 'uzCyrl'});
    for (final entry in byLanguage.entries) {
      expect(entry.value, isNotEmpty, reason: 'блок ${entry.key} пуст');
    }
  });

  test('во всех языках одинаковый набор ключей', () {
    final reference = byLanguage['en']!.toSet();
    for (final entry in byLanguage.entries) {
      final keys = entry.value.toSet();
      final missing = reference.difference(keys);
      final extra = keys.difference(reference);
      expect(
        missing.isEmpty && extra.isEmpty,
        isTrue,
        reason: '${entry.key}: не хватает $missing, лишние $extra',
      );
    }
  });

  test('ни в одном языке ключи не повторяются', () {
    for (final entry in byLanguage.entries) {
      final seen = <String>{};
      final dupes = <String>{};
      for (final key in entry.value) {
        if (!seen.add(key)) dupes.add(key);
      }
      expect(dupes, isEmpty, reason: 'дубликаты в ${entry.key}: $dupes');
    }
  });

  test('enum AppLanguage покрывает разобранные блоки', () {
    expect(
      AppLanguage.values.map((language) => language.name).toSet(),
      byLanguage.keys.toSet(),
    );
  });
}

/// Достаёт ключи каждого языкового блока из карты `_strings`, разбирая исходник
/// построчно. Языковой блок начинается со строки `AppLanguage.<name>: {`
/// (в отличие от массивов месяцев/дней недели с `: [`).
Map<String, List<String>> _parseKeys(String source) {
  final result = <String, List<String>>{};
  final marker = RegExp(r'AppLanguage\.(en|ru|uzLatn|uzCyrl):\s*\{');
  final keyLine = RegExp("^\\s*'([^']+)':");
  String? current;
  var inStrings = false;
  for (final line in source.split(RegExp(r'\r?\n'))) {
    if (line.contains('static const _strings')) inStrings = true;
    if (!inStrings) continue;
    final markerMatch = marker.firstMatch(line);
    if (markerMatch != null) {
      current = markerMatch.group(1);
      result.putIfAbsent(current!, () => <String>[]);
      continue;
    }
    if (current == null) continue;
    final keyMatch = keyLine.firstMatch(line);
    if (keyMatch != null) result[current]!.add(keyMatch.group(1)!);
  }
  return result;
}
