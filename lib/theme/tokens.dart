import 'package:flutter/material.dart';

/// Eco design tokens — ported 1:1 from the Eco 1.1.3 design canvas
/// (src/tokens.jsx). Static brand constants that are never re-skinned.
class EcoColors {
  EcoColors._();

  // Macro colours (from Figma)
  static const carb = Color(0xFF6B87FB);
  static const carbSoft = Color(0xFFAEC0F9);
  static const fat = Color(0xFFD68B5B);
  static const fatSoft = Color(0xFFE7C2A0);
  static const prot = Color(0xFFFF9500);
  static const protSoft = Color(0xFFF4D98A);

  // Water
  static const water = Color(0xFF6CCBF7);
  static const waterDeep = Color(0xFF4E7FC4);

  // Calorie band fill
  static const cal = Color(0xFF9F7255);
  static const calSoft = Color(0xFFCBB99E);

  // Neutral text
  static const ink = Color(0xFF16170B);
  static const sub = Color(0xFF686868);
  static const faint = Color(0xFF9CA086);
  static const white = Color(0xFFFFFFFF);
}

/// Themeable part: accent (meadow/forest/clay/indigo) + surface
/// (green/sage/cream). Default per the design canvas: meadow + green, r=20.
class EcoTheme {
  final Color dark;
  final Color band;
  final Color bandSoft;
  final Color pill;
  final Color olive;
  final Color ring;
  final Color bg;
  final Color card;
  final Color cardAlt;
  final double r;

  const EcoTheme({
    required this.dark,
    required this.band,
    required this.bandSoft,
    required this.pill,
    required this.olive,
    required this.ring,
    required this.bg,
    required this.card,
    required this.cardAlt,
    this.r = 20,
  });

  /// Accent "Луг" + surface "Зелёная" — the canvas defaults.
  static const meadow = EcoTheme(
    dark: Color(0xFF364025),
    band: Color(0xFFAFCC90),
    bandSoft: Color(0xFFC7DCAA),
    pill: Color(0xFFD4EFAC),
    olive: Color(0xFF7E8757),
    ring: Color(0xFFAFCC90),
    bg: Color(0xFFF4F4F0),
    card: Color(0xFFEBF3DF),
    cardAlt: Color(0xFFE2EDD1),
  );
}
