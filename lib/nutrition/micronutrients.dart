/// Personalized Dietary Reference Intake (DRI) targets used by Eco Fit.
///
/// Targets are selected by life stage. Weight and height are validated and
/// used for BMI, but they do not scale vitamin or mineral requirements.
library;

enum ProfileSex { male, female }

enum DriBasis { rda, ai }

enum MicroUnit {
  mg('mg'),
  mcg('mcg'),
  mcgRae('mcg_rae'),
  mcgDfe('mcg_dfe'),
  mgNe('mg_ne'),
  g('g');

  final String code;
  const MicroUnit(this.code);
}

enum LifeStage {
  months0To6('0_6mo'),
  months7To12('7_12mo'),
  years1To3('1_3y'),
  years4To8('4_8y'),
  maleYears9To13('male_9_13y'),
  maleYears14To18('male_14_18y'),
  maleYears19To30('male_19_30y'),
  maleYears31To50('male_31_50y'),
  maleYears51To70('male_51_70y'),
  maleYears70Plus('male_70y_plus'),
  femaleYears9To13('female_9_13y'),
  femaleYears14To18('female_14_18y'),
  femaleYears19To30('female_19_30y'),
  femaleYears31To50('female_31_50y'),
  femaleYears51To70('female_51_70y'),
  femaleYears70Plus('female_70y_plus');

  final String code;
  const LifeStage(this.code);
}

class NutritionProfile {
  final int ageYears;
  final int? ageMonths;
  final ProfileSex sex;
  final double weightKg;
  final double heightCm;

  const NutritionProfile({
    required this.ageYears,
    this.ageMonths,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
  });

  double get bmi {
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  void validate() {
    if (ageYears < 0 || (ageMonths != null && ageMonths! < 0)) {
      throw ArgumentError.value(
        ageYears,
        'ageYears',
        'Age cannot be negative.',
      );
    }
    if (ageYears == 0 && ageMonths != null && ageMonths! > 12) {
      throw ArgumentError.value(
        ageMonths,
        'ageMonths',
        'Infant age must be between 0 and 12 months.',
      );
    }
    if (weightKg <= 0) {
      throw ArgumentError.value(
        weightKg,
        'weightKg',
        'Weight must be positive.',
      );
    }
    if (heightCm <= 0) {
      throw ArgumentError.value(
        heightCm,
        'heightCm',
        'Height must be positive.',
      );
    }
  }
}

class DriValue {
  final MicroUnit unit;
  final double? ear;
  final double? rda;
  final double? ai;
  final double? ul;
  final double? cdrr;

  const DriValue({
    required this.unit,
    this.ear,
    this.rda,
    this.ai,
    this.ul,
    this.cdrr,
  }) : assert(rda != null || ai != null);
}

class MicroTarget {
  final String key;
  final double target;
  final MicroUnit unit;
  final DriBasis basis;
  final double? ear;
  final double? ul;
  final double? cdrr;
  final List<String> notes;

  const MicroTarget({
    required this.key,
    required this.target,
    required this.unit,
    required this.basis,
    this.ear,
    this.ul,
    this.cdrr,
    this.notes = const [],
  });

  Map<String, Object?> toMap() => {
        'key': key,
        'target': target,
        'unit': unit.code,
        'basis': basis.name,
        if (ear != null) 'ear': ear,
        if (ul != null) 'ul': ul,
        if (cdrr != null) 'cdrr': cdrr,
        if (notes.isNotEmpty) 'notes': notes,
      };
}

LifeStage resolveLifeStage(NutritionProfile profile) {
  profile.validate();

  if (profile.ageYears == 0) {
    return (profile.ageMonths ?? 0) <= 6
        ? LifeStage.months0To6
        : LifeStage.months7To12;
  }
  if (profile.ageYears <= 3) return LifeStage.years1To3;
  if (profile.ageYears <= 8) return LifeStage.years4To8;

  if (profile.sex == ProfileSex.male) {
    if (profile.ageYears <= 13) return LifeStage.maleYears9To13;
    if (profile.ageYears <= 18) return LifeStage.maleYears14To18;
    if (profile.ageYears <= 30) return LifeStage.maleYears19To30;
    if (profile.ageYears <= 50) return LifeStage.maleYears31To50;
    if (profile.ageYears <= 70) return LifeStage.maleYears51To70;
    return LifeStage.maleYears70Plus;
  }

  if (profile.ageYears <= 13) return LifeStage.femaleYears9To13;
  if (profile.ageYears <= 18) return LifeStage.femaleYears14To18;
  if (profile.ageYears <= 30) return LifeStage.femaleYears19To30;
  if (profile.ageYears <= 50) return LifeStage.femaleYears31To50;
  if (profile.ageYears <= 70) return LifeStage.femaleYears51To70;
  return LifeStage.femaleYears70Plus;
}

/// Maps database codes and localized nutrient names to the canonical keys used
/// by the diary and DRI table. Unknown or unsupported nutrients return null.
String? canonicalMicronutrientKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');
  return _micronutrientAliases[normalized];
}

// Keys below are already run through the same normalization as
// [canonicalMicronutrientKey] (lowercase, `ё`→`е`, non-alphanumerics stripped —
// so `vit_c` is looked up as `vitc`). Every value is a canonical code that
// matches `nutrients.code` in assets/db/eco_fit.db.
const _micronutrientAliases = <String, String>{
  // Macro-adjacent nutrients tracked alongside micros.
  'fiber': 'fiber',
  'fibre': 'fiber',
  'клетчатка': 'fiber',
  'tolasi': 'fiber',
  'sugar': 'sugar',
  'sugars': 'sugar',
  'сахар': 'sugar',
  'shakar': 'sugar',
  // Minerals.
  'fe': 'fe',
  'iron': 'fe',
  'ferrum': 'fe',
  'железо': 'fe',
  'temir': 'fe',
  'темир': 'fe',
  'mg': 'mg',
  'magnesium': 'mg',
  'магний': 'mg',
  'magniy': 'mg',
  'ca': 'ca',
  'calcium': 'ca',
  'кальций': 'ca',
  'kalsiy': 'ca',
  'p': 'p',
  'phosphorus': 'p',
  'phosphor': 'p',
  'фосфор': 'p',
  'fosfor': 'p',
  'k': 'k',
  'potassium': 'k',
  'kalium': 'k',
  'калий': 'k',
  'kaliy': 'k',
  'na': 'na',
  'sodium': 'na',
  'натрий': 'na',
  'natriy': 'na',
  'zn': 'zn',
  'zinc': 'zn',
  'цинк': 'zn',
  'rux': 'zn',
  'рух': 'zn',
  'cl': 'cl',
  'chloride': 'cl',
  'chlorine': 'cl',
  'хлор': 'cl',
  'xlor': 'cl',
  's': 's',
  'sulfur': 's',
  'sulphur': 's',
  'сера': 's',
  'oltingugurt': 's',
  'олтингугурт': 's',
  'mn': 'mn',
  'manganese': 'mn',
  'марганец': 'mn',
  'marganes': 'mn',
  'марганес': 'mn',
  'cu': 'cu',
  'copper': 'cu',
  'медь': 'cu',
  'mis': 'cu',
  'мис': 'cu',
  'se': 'se',
  'selenium': 'se',
  'селен': 'se',
  'selen': 'se',
  'i': 'i',
  'iodine': 'i',
  'iodide': 'i',
  'йод': 'i',
  'yod': 'i',
  'f': 'f',
  'fluoride': 'f',
  'fluorine': 'f',
  'фтор': 'f',
  'ftor': 'f',
  'cr': 'cr',
  'chromium': 'cr',
  'хром': 'cr',
  'xrom': 'cr',
  'mo': 'mo',
  'molybdenum': 'mo',
  'молибден': 'mo',
  'molibden': 'mo',
  'co': 'co',
  'cobalt': 'co',
  'кобальт': 'co',
  'kobalt': 'co',
  // Vitamins (normalization drops the underscore, e.g. `vit_c` → `vitc`).
  'vitc': 'vit_c',
  'vitaminc': 'vit_c',
  'витаминc': 'vit_c',
  'витаминс': 'vit_c',
  'ascorbicacid': 'vit_c',
  'vita': 'vit_a',
  'vitamina': 'vit_a',
  'витаминa': 'vit_a',
  'retinol': 'vit_a',
  'vitd': 'vit_d',
  'vitamind': 'vit_d',
  'витаминd': 'vit_d',
  'vite': 'vit_e',
  'vitamine': 'vit_e',
  'витаминe': 'vit_e',
  'tocopherol': 'vit_e',
  'vitk': 'vit_k',
  'vitamink': 'vit_k',
  'витаминk': 'vit_k',
  'phylloquinone': 'vit_k',
  'vith': 'vit_h',
  'biotin': 'vit_h',
  'биотин': 'vit_h',
  'vitb1': 'vit_b1',
  'thiamin': 'vit_b1',
  'thiamine': 'vit_b1',
  'тиамин': 'vit_b1',
  'vitb2': 'vit_b2',
  'riboflavin': 'vit_b2',
  'рибофлавин': 'vit_b2',
  'vitb3': 'vit_b3',
  'niacin': 'vit_b3',
  'ниацин': 'vit_b3',
  'vitb4': 'vit_b4',
  'choline': 'vit_b4',
  'холин': 'vit_b4',
  'vitb5': 'vit_b5',
  'pantothenicacid': 'vit_b5',
  'pantothenate': 'vit_b5',
  'пантотеноваякислота': 'vit_b5',
  'vitb6': 'vit_b6',
  'pyridoxine': 'vit_b6',
  'пиридоксин': 'vit_b6',
  'vitb9': 'vit_b9',
  'folate': 'vit_b9',
  'folacin': 'vit_b9',
  'folicacid': 'vit_b9',
  'фолат': 'vit_b9',
  'фолиеваякислота': 'vit_b9',
  'vitb12': 'vit_b12',
  'cobalamin': 'vit_b12',
  'кобаламин': 'vit_b12',
};

/// Canonical micronutrient codes surfaced in the UI, in display priority order.
/// Every entry matches a `nutrients.code` value in assets/db/eco_fit.db.
const List<String> kMicronutrientDisplayOrder = [
  'fiber',
  'k',
  'ca',
  'p',
  'mg',
  'na',
  'fe',
  'zn',
  'cu',
  'mn',
  'se',
  'i',
  'vit_a',
  'vit_c',
  'vit_d',
  'vit_e',
  'vit_k',
  'vit_b1',
  'vit_b2',
  'vit_b3',
  'vit_b5',
  'vit_b6',
  'vit_b9',
  'vit_b12',
  'cl',
  's',
  'f',
  'cr',
  'mo',
  'co',
  'vit_b4',
  'vit_h',
  'sugar',
];

/// Default measurement unit per micronutrient, mirroring
/// `nutrients.default_unit_code` in the offline DB.
const Map<String, MicroUnit> _microDefaultUnits = {
  'fe': MicroUnit.mg,
  'mg': MicroUnit.mg,
  'ca': MicroUnit.mg,
  'p': MicroUnit.mg,
  'k': MicroUnit.mg,
  'na': MicroUnit.mg,
  'zn': MicroUnit.mg,
  'cl': MicroUnit.mg,
  's': MicroUnit.mg,
  'mn': MicroUnit.mg,
  'cu': MicroUnit.mg,
  'se': MicroUnit.mcg,
  'i': MicroUnit.mcg,
  'f': MicroUnit.mcg,
  'cr': MicroUnit.mcg,
  'mo': MicroUnit.mcg,
  'co': MicroUnit.mcg,
  'vit_c': MicroUnit.mg,
  'vit_a': MicroUnit.mcg,
  'vit_d': MicroUnit.mcg,
  'vit_e': MicroUnit.mg,
  'vit_k': MicroUnit.mcg,
  'vit_h': MicroUnit.mcg,
  'vit_b1': MicroUnit.mg,
  'vit_b2': MicroUnit.mg,
  'vit_b3': MicroUnit.mg,
  'vit_b4': MicroUnit.mg,
  'vit_b5': MicroUnit.mg,
  'vit_b6': MicroUnit.mg,
  'vit_b9': MicroUnit.mcg,
  'vit_b12': MicroUnit.mcg,
};

/// Default [MicroUnit] for [key]; falls back to milligrams for unknown codes.
MicroUnit microDefaultUnit(String key) =>
    _microDefaultUnits[key] ?? MicroUnit.mg;

/// Display unit code (`'g'` | `'mg'` | `'mcg'`) for a micronutrient [key].
/// Matches the `unit.*` localization keys in AppStrings.
String microUnitCode(String key) {
  if (key == 'fiber' || key == 'sugar') return 'g';
  return switch (microDefaultUnit(key)) {
    MicroUnit.mcg || MicroUnit.mcgRae || MicroUnit.mcgDfe => 'mcg',
    MicroUnit.mg || MicroUnit.mgNe => 'mg',
    MicroUnit.g => 'g',
  };
}

/// Adult reference intake (RDA/AI) used as a daily target when the age/sex
/// specific [_driTable] has no entry for [key]. Values are expressed in the
/// nutrient's [microDefaultUnit]. Returns null when no consensus reference
/// exists (sulfur, cobalt): the UI then shows the intake without a goal ring.
double? adultMicronutrientTarget(String key, {required bool female}) =>
    switch (key) {
      'fiber' => female ? 25 : 38,
      'k' => female ? 2600 : 3400,
      'ca' => 1000,
      'p' => 700,
      'mg' => female ? 310 : 400,
      'na' => 2300,
      'fe' => female ? 18 : 8,
      'zn' => female ? 8 : 11,
      'cu' => 0.9,
      'mn' => female ? 1.8 : 2.3,
      'se' => 55,
      'i' => 150,
      'cl' => 2300,
      'f' => female ? 3000 : 4000,
      'cr' => female ? 25 : 35,
      'mo' => 45,
      'vit_a' => female ? 700 : 900,
      'vit_c' => female ? 75 : 90,
      'vit_d' => 15,
      'vit_e' => 15,
      'vit_k' => female ? 90 : 120,
      'vit_h' => 30,
      'vit_b1' => female ? 1.1 : 1.2,
      'vit_b2' => female ? 1.1 : 1.3,
      'vit_b3' => female ? 14 : 16,
      'vit_b4' => female ? 425 : 550,
      'vit_b5' => 5,
      'vit_b6' => 1.3,
      'vit_b9' => 400,
      'vit_b12' => 2.4,
      _ => null,
    };

/// Calculates targets only for nutrient keys that are actually populated in
/// the local food database. The database list is required deliberately: an
/// absent nutrient must never be interpreted as zero intake. [_driTable] carries
/// a life-stage row for every advice nutrient; sulfur and cobalt are absent
/// because no consensus reference exists for them, so they never get a target.
List<MicroTarget> calculateMicroTargets(
  NutritionProfile profile, {
  required Iterable<String> databaseNutrientKeys,
}) {
  final stage = resolveLifeStage(profile);
  final row = _driTable[stage]!;
  final availableKeys = databaseNutrientKeys
      .map(canonicalMicronutrientKey)
      .whereType<String>()
      .toSet();
  return [
    for (final entry in row.entries)
      if (availableKeys.contains(entry.key)) _targetFor(entry.key, entry.value),
  ];
}

MicroTarget _targetFor(String key, DriValue value) {
  final basis = value.rda != null ? DriBasis.rda : DriBasis.ai;
  final baseTarget = value.rda ?? value.ai!;
  return MicroTarget(
    key: key,
    target: baseTarget,
    unit: value.unit,
    basis: basis,
    ear: value.ear,
    ul: value.ul,
    cdrr: value.cdrr,
    notes: [...?_nutrientNotes[key]],
  );
}

const _nutrientNotes = <String, List<String>>{
  'vit_a': ['UL applies only to preformed vitamin A, not beta-carotene.'],
  'vit_d': ['Target assumes minimal sun exposure.'],
  'vit_e': ['UL applies to supplemental or synthetic vitamin E.'],
  'vit_b3': ['UL applies to niacin from supplements or fortified foods.'],
  'vit_b12': [
    'Adults over 50 should preferably use fortified foods or supplements.',
  ],
  'vit_b9': ['UL applies to folic acid, not naturally occurring food folate.'],
  'mg': ['UL applies only to magnesium from supplements or medications.'],
  'na': ['CDRR is a risk-reduction limit, not a target to reach.'],
};

const _mg = MicroUnit.mg;
const _mcg = MicroUnit.mcg;
const _mcgRae = MicroUnit.mcgRae;
const _mcgDfe = MicroUnit.mcgDfe;
const _mgNe = MicroUnit.mgNe;
const _g = MicroUnit.g;

DriValue _r(MicroUnit unit, double target,
        {double? ear, double? ul, double? cdrr}) =>
    DriValue(unit: unit, rda: target, ear: ear, ul: ul, cdrr: cdrr);

DriValue _a(MicroUnit unit, double target,
        {double? ear, double? ul, double? cdrr}) =>
    DriValue(unit: unit, ai: target, ear: ear, ul: ul, cdrr: cdrr);

/// Personalized DRI table: every populated micronutrient that has an official
/// US DRI, keyed by life stage. Values are RDA (basis rda) or AI (basis ai),
/// with EAR where one exists, UL where set, and CDRR for sodium. Generated
/// from verified NASEM/IOM values (see docs); do not hand-edit individual
/// numbers without re-verifying against the DRI source tables.
final Map<LifeStage, Map<String, DriValue>> _driTable = {
  LifeStage.months0To6: {
    'fe': _a(_mg, 0.27, ul: 40),
    'mg': _a(_mg, 30),
    'ca': _a(_mg, 200, ul: 1000),
    'p': _a(_mg, 100),
    'k': _a(_mg, 400),
    'na': _a(_mg, 110),
    'zn': _a(_mg, 2, ul: 4),
    'cu': _a(_mg, 0.2),
    'mn': _a(_mg, 0.003),
    'se': _a(_mcg, 15, ul: 45),
    'i': _a(_mcg, 110),
    'cl': _a(_mg, 180),
    'f': _a(_mcg, 10, ul: 700),
    'cr': _a(_mcg, 0.2),
    'mo': _a(_mcg, 2),
    'vit_a': _a(_mcgRae, 400, ul: 600),
    'vit_c': _a(_mg, 40),
    'vit_d': _a(_mcg, 10, ul: 25),
    'vit_e': _a(_mg, 4),
    'vit_k': _a(_mcg, 2),
    'vit_b1': _a(_mg, 0.2),
    'vit_b2': _a(_mg, 0.3),
    'vit_b3': _a(_mgNe, 2),
    'vit_b6': _a(_mg, 0.1),
    'vit_b9': _a(_mcgDfe, 65),
    'vit_b12': _a(_mcg, 0.4),
    'vit_b4': _a(_mg, 125),
    'vit_b5': _a(_mg, 1.7),
    'vit_h': _a(_mcg, 5),
  },
  LifeStage.months7To12: {
    'fe': _r(_mg, 11, ear: 6.9, ul: 40),
    'mg': _a(_mg, 75),
    'ca': _a(_mg, 260, ul: 1500),
    'p': _a(_mg, 275),
    'k': _a(_mg, 860),
    'na': _a(_mg, 370),
    'zn': _r(_mg, 3, ear: 2.5, ul: 5),
    'cu': _a(_mg, 0.22),
    'mn': _a(_mg, 0.6),
    'se': _a(_mcg, 20, ul: 60),
    'i': _a(_mcg, 130),
    'cl': _a(_mg, 570),
    'f': _a(_mcg, 500, ul: 900),
    'cr': _a(_mcg, 5.5),
    'mo': _a(_mcg, 3),
    'vit_a': _a(_mcgRae, 500, ul: 600),
    'vit_c': _a(_mg, 50),
    'vit_d': _a(_mcg, 10, ul: 38),
    'vit_e': _a(_mg, 5),
    'vit_k': _a(_mcg, 2.5),
    'vit_b1': _a(_mg, 0.3),
    'vit_b2': _a(_mg, 0.4),
    'vit_b3': _a(_mgNe, 4),
    'vit_b6': _a(_mg, 0.3),
    'vit_b9': _a(_mcgDfe, 80),
    'vit_b12': _a(_mcg, 0.5),
    'vit_b4': _a(_mg, 150),
    'vit_b5': _a(_mg, 1.8),
    'vit_h': _a(_mcg, 6),
  },
  LifeStage.years1To3: {
    'fe': _r(_mg, 7, ear: 3, ul: 40),
    'mg': _r(_mg, 80, ear: 65, ul: 65),
    'ca': _r(_mg, 700, ear: 500, ul: 2500),
    'p': _r(_mg, 460, ear: 380, ul: 3000),
    'k': _a(_mg, 2000),
    'na': _a(_mg, 800, cdrr: 1200),
    'zn': _r(_mg, 3, ear: 2.5, ul: 7),
    'cu': _r(_mg, 0.34, ear: 0.26, ul: 1),
    'mn': _a(_mg, 1.2, ul: 2),
    'se': _r(_mcg, 20, ear: 17, ul: 90),
    'i': _r(_mcg, 90, ear: 65, ul: 200),
    'cl': _a(_mg, 1500, ul: 2300),
    'f': _a(_mcg, 700, ul: 1300),
    'cr': _a(_mcg, 11),
    'mo': _r(_mcg, 17, ear: 13, ul: 300),
    'vit_a': _r(_mcgRae, 300, ear: 210, ul: 600),
    'vit_c': _r(_mg, 15, ear: 13, ul: 400),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 63),
    'vit_e': _r(_mg, 6, ear: 5, ul: 200),
    'vit_k': _a(_mcg, 30),
    'vit_b1': _r(_mg, 0.5, ear: 0.4),
    'vit_b2': _r(_mg, 0.5, ear: 0.4),
    'vit_b3': _r(_mgNe, 6, ear: 5, ul: 10),
    'vit_b6': _r(_mg, 0.5, ear: 0.4, ul: 30),
    'vit_b9': _r(_mcgDfe, 150, ear: 120, ul: 300),
    'vit_b12': _r(_mcg, 0.9, ear: 0.7),
    'vit_b4': _a(_mg, 200, ul: 1000),
    'vit_b5': _a(_mg, 2),
    'vit_h': _a(_mcg, 8),
    'fiber': _a(_g, 19),
  },
  LifeStage.years4To8: {
    'fe': _r(_mg, 10, ear: 4.1, ul: 40),
    'mg': _r(_mg, 130, ear: 110, ul: 110),
    'ca': _r(_mg, 1000, ear: 800, ul: 2500),
    'p': _r(_mg, 500, ear: 405, ul: 3000),
    'k': _a(_mg, 2300),
    'na': _a(_mg, 1000, cdrr: 1500),
    'zn': _r(_mg, 5, ear: 4, ul: 12),
    'cu': _r(_mg, 0.44, ear: 0.34, ul: 3),
    'mn': _a(_mg, 1.5, ul: 3),
    'se': _r(_mcg, 30, ear: 23, ul: 150),
    'i': _r(_mcg, 90, ear: 65, ul: 300),
    'cl': _a(_mg, 1900, ul: 2900),
    'f': _a(_mcg, 1000, ul: 2200),
    'cr': _a(_mcg, 15),
    'mo': _r(_mcg, 22, ear: 17, ul: 600),
    'vit_a': _r(_mcgRae, 400, ear: 275, ul: 900),
    'vit_c': _r(_mg, 25, ear: 22, ul: 650),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 75),
    'vit_e': _r(_mg, 7, ear: 6, ul: 300),
    'vit_k': _a(_mcg, 55),
    'vit_b1': _r(_mg, 0.6, ear: 0.5),
    'vit_b2': _r(_mg, 0.6, ear: 0.5),
    'vit_b3': _r(_mgNe, 8, ear: 6, ul: 15),
    'vit_b6': _r(_mg, 0.6, ear: 0.5, ul: 40),
    'vit_b9': _r(_mcgDfe, 200, ear: 160, ul: 400),
    'vit_b12': _r(_mcg, 1.2, ear: 1),
    'vit_b4': _a(_mg, 250, ul: 1000),
    'vit_b5': _a(_mg, 3),
    'vit_h': _a(_mcg, 12),
    'fiber': _a(_g, 25),
  },
  LifeStage.maleYears9To13: {
    'fe': _r(_mg, 8, ear: 5.9, ul: 40),
    'mg': _r(_mg, 240, ear: 200, ul: 350),
    'ca': _r(_mg, 1300, ear: 1100, ul: 3000),
    'p': _r(_mg, 1250, ear: 1055, ul: 4000),
    'k': _a(_mg, 2500),
    'na': _a(_mg, 1200, cdrr: 1800),
    'zn': _r(_mg, 8, ear: 7, ul: 23),
    'cu': _r(_mg, 0.7, ear: 0.54, ul: 5),
    'mn': _a(_mg, 1.9, ul: 6),
    'se': _r(_mcg, 40, ear: 35, ul: 280),
    'i': _r(_mcg, 120, ear: 73, ul: 600),
    'cl': _a(_mg, 2300, ul: 3400),
    'f': _a(_mcg, 2000, ul: 10000),
    'cr': _a(_mcg, 25),
    'mo': _r(_mcg, 34, ear: 26, ul: 1100),
    'vit_a': _r(_mcgRae, 600, ear: 445, ul: 1700),
    'vit_c': _r(_mg, 45, ear: 39, ul: 1200),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 11, ear: 9, ul: 600),
    'vit_k': _a(_mcg, 60),
    'vit_b1': _r(_mg, 0.9, ear: 0.7),
    'vit_b2': _r(_mg, 0.9, ear: 0.8),
    'vit_b3': _r(_mgNe, 12, ear: 9, ul: 20),
    'vit_b6': _r(_mg, 1, ear: 0.8, ul: 60),
    'vit_b9': _r(_mcgDfe, 300, ear: 250, ul: 600),
    'vit_b12': _r(_mcg, 1.8, ear: 1.5),
    'vit_b4': _a(_mg, 375, ul: 2000),
    'vit_b5': _a(_mg, 4),
    'vit_h': _a(_mcg, 20),
    'fiber': _a(_g, 31),
  },
  LifeStage.maleYears14To18: {
    'fe': _r(_mg, 11, ear: 7.7, ul: 45),
    'mg': _r(_mg, 410, ear: 340, ul: 350),
    'ca': _r(_mg, 1300, ear: 1100, ul: 3000),
    'p': _r(_mg, 1250, ear: 1055, ul: 4000),
    'k': _a(_mg, 3000),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 11, ear: 8.5, ul: 34),
    'cu': _r(_mg, 0.89, ear: 0.685, ul: 8),
    'mn': _a(_mg, 2.2, ul: 9),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 900),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 35),
    'mo': _r(_mcg, 43, ear: 33, ul: 1700),
    'vit_a': _r(_mcgRae, 900, ear: 630, ul: 2800),
    'vit_c': _r(_mg, 75, ear: 63, ul: 1800),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 800),
    'vit_k': _a(_mcg, 75),
    'vit_b1': _r(_mg, 1.2, ear: 1),
    'vit_b2': _r(_mg, 1.3, ear: 1.1),
    'vit_b3': _r(_mgNe, 16, ear: 12, ul: 30),
    'vit_b6': _r(_mg, 1.3, ear: 1.1, ul: 80),
    'vit_b9': _r(_mcgDfe, 400, ear: 330, ul: 800),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 550, ul: 3000),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 25),
    'fiber': _a(_g, 38),
  },
  LifeStage.maleYears19To30: {
    'fe': _r(_mg, 8, ear: 6, ul: 45),
    'mg': _r(_mg, 400, ear: 330, ul: 350),
    'ca': _r(_mg, 1000, ear: 800, ul: 2500),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 3400),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 11, ear: 9.4, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 2.3, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 4000, ul: 10000),
    'cr': _a(_mcg, 35),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 900, ear: 625, ul: 3000),
    'vit_c': _r(_mg, 90, ear: 75, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 120),
    'vit_b1': _r(_mg, 1.2, ear: 1),
    'vit_b2': _r(_mg, 1.3, ear: 1.1),
    'vit_b3': _r(_mgNe, 16, ear: 12, ul: 35),
    'vit_b6': _r(_mg, 1.3, ear: 1.1, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 550, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 38),
  },
  LifeStage.maleYears31To50: {
    'fe': _r(_mg, 8, ear: 6, ul: 45),
    'mg': _r(_mg, 420, ear: 350, ul: 350),
    'ca': _r(_mg, 1000, ear: 800, ul: 2500),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 3400),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 11, ear: 9.4, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 2.3, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 4000, ul: 10000),
    'cr': _a(_mcg, 35),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 900, ear: 625, ul: 3000),
    'vit_c': _r(_mg, 90, ear: 75, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 120),
    'vit_b1': _r(_mg, 1.2, ear: 1),
    'vit_b2': _r(_mg, 1.3, ear: 1.1),
    'vit_b3': _r(_mgNe, 16, ear: 12, ul: 35),
    'vit_b6': _r(_mg, 1.3, ear: 1.1, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 550, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 38),
  },
  LifeStage.maleYears51To70: {
    'fe': _r(_mg, 8, ear: 6, ul: 45),
    'mg': _r(_mg, 420, ear: 350, ul: 350),
    'ca': _r(_mg, 1000, ear: 800, ul: 2000),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 3400),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 11, ear: 9.4, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 2.3, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2000, ul: 3600),
    'f': _a(_mcg, 4000, ul: 10000),
    'cr': _a(_mcg, 30),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 900, ear: 625, ul: 3000),
    'vit_c': _r(_mg, 90, ear: 75, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 120),
    'vit_b1': _r(_mg, 1.2, ear: 1),
    'vit_b2': _r(_mg, 1.3, ear: 1.1),
    'vit_b3': _r(_mgNe, 16, ear: 12, ul: 35),
    'vit_b6': _r(_mg, 1.7, ear: 1.4, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 550, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 30),
  },
  LifeStage.maleYears70Plus: {
    'fe': _r(_mg, 8, ear: 6, ul: 45),
    'mg': _r(_mg, 420, ear: 350, ul: 350),
    'ca': _r(_mg, 1200, ear: 1000, ul: 2000),
    'p': _r(_mg, 700, ear: 580, ul: 3000),
    'k': _a(_mg, 3400),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 11, ear: 9.4, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 2.3, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 1800, ul: 3600),
    'f': _a(_mcg, 4000, ul: 10000),
    'cr': _a(_mcg, 30),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 900, ear: 625, ul: 3000),
    'vit_c': _r(_mg, 90, ear: 75, ul: 2000),
    'vit_d': _r(_mcg, 20, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 120),
    'vit_b1': _r(_mg, 1.2, ear: 1),
    'vit_b2': _r(_mg, 1.3, ear: 1.1),
    'vit_b3': _r(_mgNe, 16, ear: 12, ul: 35),
    'vit_b6': _r(_mg, 1.7, ear: 1.4, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 550, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 30),
  },
  LifeStage.femaleYears9To13: {
    'fe': _r(_mg, 8, ear: 5.7, ul: 40),
    'mg': _r(_mg, 240, ear: 200, ul: 350),
    'ca': _r(_mg, 1300, ear: 1100, ul: 3000),
    'p': _r(_mg, 1250, ear: 1055, ul: 4000),
    'k': _a(_mg, 2300),
    'na': _a(_mg, 1200, cdrr: 1800),
    'zn': _r(_mg, 8, ear: 7, ul: 23),
    'cu': _r(_mg, 0.7, ear: 0.54, ul: 5),
    'mn': _a(_mg, 1.6, ul: 6),
    'se': _r(_mcg, 40, ear: 35, ul: 280),
    'i': _r(_mcg, 120, ear: 73, ul: 600),
    'cl': _a(_mg, 2300, ul: 3400),
    'f': _a(_mcg, 2000, ul: 10000),
    'cr': _a(_mcg, 21),
    'mo': _r(_mcg, 34, ear: 26, ul: 1100),
    'vit_a': _r(_mcgRae, 600, ear: 420, ul: 1700),
    'vit_c': _r(_mg, 45, ear: 39, ul: 1200),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 11, ear: 9, ul: 600),
    'vit_k': _a(_mcg, 60),
    'vit_b1': _r(_mg, 0.9, ear: 0.7),
    'vit_b2': _r(_mg, 0.9, ear: 0.8),
    'vit_b3': _r(_mgNe, 12, ear: 9, ul: 20),
    'vit_b6': _r(_mg, 1, ear: 0.8, ul: 60),
    'vit_b9': _r(_mcgDfe, 300, ear: 250, ul: 600),
    'vit_b12': _r(_mcg, 1.8, ear: 1.5),
    'vit_b4': _a(_mg, 375, ul: 2000),
    'vit_b5': _a(_mg, 4),
    'vit_h': _a(_mcg, 20),
    'fiber': _a(_g, 26),
  },
  LifeStage.femaleYears14To18: {
    'fe': _r(_mg, 15, ear: 7.9, ul: 45),
    'mg': _r(_mg, 360, ear: 300, ul: 350),
    'ca': _r(_mg, 1300, ear: 1100, ul: 3000),
    'p': _r(_mg, 1250, ear: 1055, ul: 4000),
    'k': _a(_mg, 2300),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 9, ear: 7.3, ul: 34),
    'cu': _r(_mg, 0.89, ear: 0.685, ul: 8),
    'mn': _a(_mg, 1.6, ul: 9),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 900),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 24),
    'mo': _r(_mcg, 43, ear: 33, ul: 1700),
    'vit_a': _r(_mcgRae, 700, ear: 485, ul: 2800),
    'vit_c': _r(_mg, 65, ear: 56, ul: 1800),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 800),
    'vit_k': _a(_mcg, 75),
    'vit_b1': _r(_mg, 1, ear: 0.9),
    'vit_b2': _r(_mg, 1, ear: 0.9),
    'vit_b3': _r(_mgNe, 14, ear: 11, ul: 30),
    'vit_b6': _r(_mg, 1.2, ear: 1, ul: 80),
    'vit_b9': _r(_mcgDfe, 400, ear: 330, ul: 800),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 400, ul: 3000),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 25),
    'fiber': _a(_g, 26),
  },
  LifeStage.femaleYears19To30: {
    'fe': _r(_mg, 18, ear: 8.1, ul: 45),
    'mg': _r(_mg, 310, ear: 255, ul: 350),
    'ca': _r(_mg, 1000, ear: 800, ul: 2500),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 2600),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 8, ear: 6.8, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 1.8, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 25),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 700, ear: 500, ul: 3000),
    'vit_c': _r(_mg, 75, ear: 60, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 90),
    'vit_b1': _r(_mg, 1.1, ear: 0.9),
    'vit_b2': _r(_mg, 1.1, ear: 0.9),
    'vit_b3': _r(_mgNe, 14, ear: 11, ul: 35),
    'vit_b6': _r(_mg, 1.3, ear: 1.1, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 425, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 25),
  },
  LifeStage.femaleYears31To50: {
    'fe': _r(_mg, 18, ear: 8.1, ul: 45),
    'mg': _r(_mg, 320, ear: 265, ul: 350),
    'ca': _r(_mg, 1000, ear: 800, ul: 2500),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 2600),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 8, ear: 6.8, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 1.8, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2300, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 25),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 700, ear: 500, ul: 3000),
    'vit_c': _r(_mg, 75, ear: 60, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 90),
    'vit_b1': _r(_mg, 1.1, ear: 0.9),
    'vit_b2': _r(_mg, 1.1, ear: 0.9),
    'vit_b3': _r(_mgNe, 14, ear: 11, ul: 35),
    'vit_b6': _r(_mg, 1.3, ear: 1.1, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 425, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 25),
  },
  LifeStage.femaleYears51To70: {
    'fe': _r(_mg, 8, ear: 5, ul: 45),
    'mg': _r(_mg, 320, ear: 265, ul: 350),
    'ca': _r(_mg, 1200, ear: 1000, ul: 2000),
    'p': _r(_mg, 700, ear: 580, ul: 4000),
    'k': _a(_mg, 2600),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 8, ear: 6.8, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 1.8, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 2000, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 20),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 700, ear: 500, ul: 3000),
    'vit_c': _r(_mg, 75, ear: 60, ul: 2000),
    'vit_d': _r(_mcg, 15, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 90),
    'vit_b1': _r(_mg, 1.1, ear: 0.9),
    'vit_b2': _r(_mg, 1.1, ear: 0.9),
    'vit_b3': _r(_mgNe, 14, ear: 11, ul: 35),
    'vit_b6': _r(_mg, 1.5, ear: 1.3, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 425, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 21),
  },
  LifeStage.femaleYears70Plus: {
    'fe': _r(_mg, 8, ear: 5, ul: 45),
    'mg': _r(_mg, 320, ear: 265, ul: 350),
    'ca': _r(_mg, 1200, ear: 1000, ul: 2000),
    'p': _r(_mg, 700, ear: 580, ul: 3000),
    'k': _a(_mg, 2600),
    'na': _a(_mg, 1500, cdrr: 2300),
    'zn': _r(_mg, 8, ear: 6.8, ul: 40),
    'cu': _r(_mg, 0.9, ear: 0.7, ul: 10),
    'mn': _a(_mg, 1.8, ul: 11),
    'se': _r(_mcg, 55, ear: 45, ul: 400),
    'i': _r(_mcg, 150, ear: 95, ul: 1100),
    'cl': _a(_mg, 1800, ul: 3600),
    'f': _a(_mcg, 3000, ul: 10000),
    'cr': _a(_mcg, 20),
    'mo': _r(_mcg, 45, ear: 34, ul: 2000),
    'vit_a': _r(_mcgRae, 700, ear: 500, ul: 3000),
    'vit_c': _r(_mg, 75, ear: 60, ul: 2000),
    'vit_d': _r(_mcg, 20, ear: 10, ul: 100),
    'vit_e': _r(_mg, 15, ear: 12, ul: 1000),
    'vit_k': _a(_mcg, 90),
    'vit_b1': _r(_mg, 1.1, ear: 0.9),
    'vit_b2': _r(_mg, 1.1, ear: 0.9),
    'vit_b3': _r(_mgNe, 14, ear: 11, ul: 35),
    'vit_b6': _r(_mg, 1.5, ear: 1.3, ul: 100),
    'vit_b9': _r(_mcgDfe, 400, ear: 320, ul: 1000),
    'vit_b12': _r(_mcg, 2.4, ear: 2),
    'vit_b4': _a(_mg, 425, ul: 3500),
    'vit_b5': _a(_mg, 5),
    'vit_h': _a(_mcg, 30),
    'fiber': _a(_g, 21),
  },
};
