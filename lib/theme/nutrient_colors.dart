import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Канонические цвета нутриентов — единый источник для дневника (`dayview`) и
/// карточки блюда (`dish`).
///
/// Раньше две почти одинаковые карты (`_microColor` в dayview и `_nutrientColor`
/// в dish) разъехались: например `vit_c` был жёлтым на одном экране и зелёным на
/// другом. Здесь закреплён вариант дневника как канонический, и оба экрана берут
/// цвет отсюда.
Color nutrientColor(String code) => switch (code) {
      'fiber' => const Color(0xFF86A85A),
      'sugar' => const Color(0xFFC98BB0),
      // Vitamins.
      'vit_a' => const Color(0xFFE08B3E),
      'vit_c' => const Color(0xFFE6C430),
      'vit_d' => const Color(0xFF7A77C8),
      'vit_e' => const Color(0xFFC08A3E),
      'vit_k' => const Color(0xFF4F8F5B),
      'vit_h' => const Color(0xFFB0885B),
      'vit_b1' => const Color(0xFFD98A6A),
      'vit_b2' => const Color(0xFFD9A24A),
      'vit_b3' => const Color(0xFFC7A057),
      'vit_b4' => const Color(0xFFA88FBF),
      'vit_b5' => const Color(0xFF8FB07A),
      'vit_b6' => const Color(0xFF6FA890),
      'vit_b9' => const Color(0xFF5FA06A),
      'vit_b12' => const Color(0xFFB06A8F),
      // Minerals.
      'k' => const Color(0xFF54A866),
      'mg' => const Color(0xFF4F8F7A),
      'ca' => const Color(0xFF5E86B8),
      'p' => const Color(0xFF8A6FB4),
      'fe' => const Color(0xFFB85B3C),
      'zn' => const Color(0xFF6A8A90),
      'na' => const Color(0xFFB59349),
      'cu' => const Color(0xFFB87333),
      'mn' => const Color(0xFF9C7BB0),
      'se' => const Color(0xFF7E9AA6),
      'i' => const Color(0xFF5B6FB0),
      'cl' => const Color(0xFF7FB0A8),
      's' => const Color(0xFFC7B24A),
      'f' => const Color(0xFF6FA0C0),
      'cr' => const Color(0xFF8FA05B),
      'mo' => const Color(0xFF9A8A5B),
      'co' => const Color(0xFF5B8AA0),
      _ => EcoTheme.meadow.olive,
    };
