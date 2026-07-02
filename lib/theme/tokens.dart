import 'package:flutter/material.dart';

/// Единая «скорость» приложения для всех анимаций открытия/закрытия — переходы
/// между экранами, выезд панели приёма пищи, всплывающие меню, смена контента
/// карточки ИИ. Один источник правды: меняешь здесь — меняется везде.
const Duration kEcoMotionDuration = Duration(milliseconds: 100);
const Curve kEcoMotionCurve = Curves.easeOutCubic;

class EcoColors {
  EcoColors._();

  // Акцентные цвета нутриентов/статусов — одинаковы в обеих темах.
  // Палитра колец Apple Fitness (Activity rings):
  //   carb  -> Stand    (cyan)  #1BE8EF
  //   fat   -> Move     (red)   #FA114F
  //   prot  -> Exercise (green) #92E82A
  static const carb = Color(0xFF1BE8EF);
  static const carbSoft = Color(0xFFA6F4F8);
  static const fat = Color(0xFFFA114F);
  static const fatSoft = Color(0xFFFCAEC0);
  static const prot = Color(0xFF92E82A);
  static const protSoft = Color(0xFFCDF59C);
  // Акцент «Шаги»: тёмно-зелёный; превышение цели отмечается ещё темнее.
  static const stepAccent = Color(0xFF2E7D52);
  static const stepAccentDeep = Color(0xFF14532D);

  static const water = Color(0xFF6BD2FB);
  static const waterDeep = Color(0xFF6B99FB);

  static const cal = Color(0xFF6E4A2B);
  static const calSoft = Color(0x4A686868);

  static const statusGood = Color(0xFF3D806A);
  static const statusWarn = Color(0xFFA96666);

  // Базовые текстовые цвета (СВЕТЛАЯ тема). Для тёмной темы используйте
  // токены t.ink / t.sub / t.faint из EcoTheme — они инвертируются.
  static const ink = Color(0xFF010103);
  static const sub = Color(0xFF3C3C3C);
  static const faint = Color(0xFF686868);
  static const white = Color(0xFFFFFFFF);
}

class EcoTheme {
  final Color bgTop;
  final Color bgBottom;
  final Color dark;
  final Color darkPill;
  final Color band;
  final Color bandSoft;
  final Color track;
  final Color pill;
  final Color olive;
  final Color ring;
  final Color bg;
  final Color card;
  final Color cardAlt;
  final Color glassBorder;

  // Тонированное стекло карточек здоровья (тело/шаги/вода). Как и card,
  // задают только RGB — альфу переопределяет ползунок cardOpacity.
  final Color cardBody;
  final Color cardSteps;
  final Color cardWater;

  // Текстовые/контентные токены (инвертируются между темами).
  final Color ink; // основной текст
  final Color sub; // вторичный текст
  final Color faint; // приглушённый текст/иконки
  final Color onDark; // текст/иконки на тёмных пилюлях и кнопках

  final bool isDark;
  final double blur;
  final double r;

  const EcoTheme({
    required this.bgTop,
    required this.bgBottom,
    required this.dark,
    required this.darkPill,
    required this.band,
    required this.bandSoft,
    required this.track,
    required this.pill,
    required this.olive,
    required this.ring,
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.glassBorder,
    required this.cardBody,
    required this.cardSteps,
    required this.cardWater,
    required this.ink,
    required this.sub,
    required this.faint,
    required this.onDark,
    this.isDark = false,
    this.blur = 16,
    this.r = 20,
  });

  static const meadow = EcoTheme(
    bgTop: Color(0xFFBCBCBC),
    bgBottom: Color(0xFFEDE9E9),
    dark: Color(0xFF2A2A2C),
    darkPill: Color(0xB31C1C1C),
    band: Color(0x8CFFFFFF),
    bandSoft: Color(0x7AFFFFFF),
    track: Color(0x4A686868),
    pill: Color(0xFFFFFFFF),
    olive: Color(0xFF3D806A),
    ring: Color(0xFF4B99FF),
    bg: Color(0xFFE7E4E2),
    card: Color(0x33FFFFFF),
    cardAlt: Color(0x57FFFFFF),
    glassBorder: Color(0x66FFFFFF),
    cardBody: Color(0xFFDCEDE2),
    cardSteps: Color(0xFFE4EDD6),
    cardWater: Color(0xFFDBECF8),
    ink: Color(0xFF010103),
    sub: Color(0xFF3C3C3C),
    faint: Color(0xFF686868),
    onDark: Color(0xFFFFFFFF),
    isDark: false,
    blur: 16,
    r: 20,
  );

  // Тёмная тема — для всех элементов (фон, карточки, пилюли, текст).
  static const night = EcoTheme(
    bgTop: Color(0xFF202327),
    bgBottom: Color(0xFF0E0F11),
    dark: Color(
        0xFF34343A), // поверхность тёмных пилюль/кнопок (с onDark-текстом)
    darkPill: Color(0xE60A0A0C),
    band: Color(0x1FFFFFFF), // матовое стекло на тёмном
    bandSoft: Color(0x12FFFFFF),
    track: Color(0x33FFFFFF),
    pill: Color(0xFF2A2A30),
    olive: Color(0xFF54A98C),
    ring: Color(0xFF4B99FF),
    bg: Color(0xFF151619),
    // Базовый цвет карточки — ТЁМНО-СЕРЫЙ (а не белый). Ползунок задаёт альфу:
    // плотнее -> сплошная тёмно-серая карточка (светлый текст читается);
    // прозрачнее -> тёмное стекло, сквозь которое виден фон. RGB важен, альфа
    // переопределяется cardOpacity в EcoGlassSurface.
    card: Color(0xFF30333A),
    cardAlt: Color(0xFF3A3E46),
    glassBorder: Color(0x33FFFFFF),
    cardBody: Color(0xFF2C3B33),
    cardSteps: Color(0xFF333D2B),
    cardWater: Color(0xFF2B3846),
    ink: Color(0xFFF1F1F4),
    sub: Color(0xFFB6B8BE),
    faint: Color(0xFF85878F),
    onDark: Color(0xFFF1F1F4),
    isDark: true,
    blur: 16,
    r: 20,
  );
}
