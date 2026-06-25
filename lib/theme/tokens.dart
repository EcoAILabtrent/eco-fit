import 'package:flutter/material.dart';

class EcoColors {
  EcoColors._();

  static const carb = Color(0xFF4B99FF);
  static const carbSoft = Color(0xFFA9CCFF);
  static const fat = Color(0xFFD97332);
  static const fatSoft = Color(0xFFECC1A3);
  static const prot = Color(0xFF32D94B);
  static const protSoft = Color(0xFFA9E6B5);

  static const water = Color(0xFF6BD2FB);
  static const waterDeep = Color(0xFF6B99FB);

  static const cal = Color(0xFF6E4A2B);
  static const calSoft = Color(0x4A686868);

  static const statusGood = Color(0xFF3D806A);
  static const statusWarn = Color(0xFFA96666);

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
    blur: 16,
    r: 20,
  );
}
