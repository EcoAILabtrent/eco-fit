import 'package:flutter/widgets.dart';

enum AppLanguage {
  en(
    code: 'en',
    productLocale: 'en',
    locale: Locale('en'),
    nativeName: 'English',
    shortName: 'EN',
  ),
  ru(
    code: 'ru',
    productLocale: 'ru',
    locale: Locale('ru'),
    nativeName: 'Русский',
    shortName: 'RU',
  ),
  uzLatn(
    code: 'uz_latn',
    productLocale: 'uz_latn',
    locale: Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Latn'),
    nativeName: "O'zbekcha",
    shortName: 'UZ',
  ),
  uzCyrl(
    code: 'uz_cyrl',
    productLocale: 'uz_cyrl',
    locale: Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    nativeName: 'Ўзбекча',
    shortName: 'ЎЗ',
  );

  final String code;
  final String productLocale;
  final Locale locale;
  final String nativeName;
  final String shortName;

  const AppLanguage({
    required this.code,
    required this.productLocale,
    required this.locale,
    required this.nativeName,
    required this.shortName,
  });

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return AppLanguage.ru;
  }

  static List<Locale> get supportedLocales => [
        for (final language in values) language.locale,
      ];
}
