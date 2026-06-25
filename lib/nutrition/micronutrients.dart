/// Personalized Dietary Reference Intake (DRI) targets used by Eco Fit.
///
/// Targets are selected by life stage. Weight and height are validated and
/// used for BMI, but they do not scale vitamin or mineral requirements.
library;

enum ProfileSex { male, female }

enum PregnancyStatus { none, pregnant }

enum LactationStatus { none, months0To6, months7To12 }

enum DriBasis { rda, ai }

enum MicroUnit {
  mg('mg'),
  mcg('mcg'),
  mcgRae('mcg_rae'),
  mcgDfe('mcg_dfe'),
  mgNe('mg_ne');

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
  femaleYears70Plus('female_70y_plus'),
  pregnancyUnder19('pregnancy_le_18'),
  pregnancyYears19To30('pregnancy_19_30'),
  pregnancyYears31To50('pregnancy_31_50'),
  lactationUnder19('lactation_le_18'),
  lactationYears19To30('lactation_19_30'),
  lactationYears31To50('lactation_31_50');

  final String code;
  const LifeStage(this.code);
}

class NutritionProfile {
  final int ageYears;
  final int? ageMonths;
  final ProfileSex sex;
  final double weightKg;
  final double heightCm;
  final PregnancyStatus pregnancyStatus;
  final LactationStatus lactationStatus;
  final bool smoker;

  const NutritionProfile({
    required this.ageYears,
    this.ageMonths,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    this.pregnancyStatus = PregnancyStatus.none,
    this.lactationStatus = LactationStatus.none,
    this.smoker = false,
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
    if (sex != ProfileSex.female &&
        (pregnancyStatus != PregnancyStatus.none ||
            lactationStatus != LactationStatus.none)) {
      throw ArgumentError(
        'Pregnancy and lactation are only valid for female profiles.',
      );
    }
    if (pregnancyStatus != PregnancyStatus.none &&
        lactationStatus != LactationStatus.none) {
      throw ArgumentError('Pregnancy and lactation cannot both be active.');
    }
    if ((pregnancyStatus != PregnancyStatus.none ||
            lactationStatus != LactationStatus.none) &&
        ageYears > 50) {
      throw ArgumentError('DRI pregnancy and lactation groups end at age 50.');
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

  if (profile.pregnancyStatus == PregnancyStatus.pregnant) {
    if (profile.ageYears <= 18) return LifeStage.pregnancyUnder19;
    if (profile.ageYears <= 30) return LifeStage.pregnancyYears19To30;
    return LifeStage.pregnancyYears31To50;
  }
  if (profile.lactationStatus != LactationStatus.none) {
    if (profile.ageYears <= 18) return LifeStage.lactationUnder19;
    if (profile.ageYears <= 30) return LifeStage.lactationYears19To30;
    return LifeStage.lactationYears31To50;
  }

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

const _micronutrientAliases = <String, String>{
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
};

/// Calculates targets only for nutrient keys that are actually populated in
/// the local food database. The database list is required deliberately: an
/// absent nutrient must never be interpreted as zero intake.
List<MicroTarget> calculateMicroTargets(
  NutritionProfile profile, {
  required Iterable<String> databaseNutrientKeys,
}) {
  final stage = resolveLifeStage(profile);
  final row = {..._driTable[stage]!, ..._additionalVitaminTable[stage]!};
  final availableKeys = databaseNutrientKeys
      .map(canonicalMicronutrientKey)
      .whereType<String>()
      .toSet();
  return [
    for (final entry in row.entries)
      if (availableKeys.contains(entry.key))
        _targetFor(
          entry.key,
          entry.value,
          smoker: profile.smoker && entry.key == 'vit_c',
        ),
  ];
}

MicroTarget _targetFor(String key, DriValue value, {required bool smoker}) {
  final basis = value.rda != null ? DriBasis.rda : DriBasis.ai;
  final baseTarget = value.rda ?? value.ai!;
  final notes = [...?_nutrientNotes[key]];
  if (smoker) {
    notes.add(
      'Vitamin C target includes the additional 35 mg/day for smokers.',
    );
  }
  return MicroTarget(
    key: key,
    target: baseTarget + (smoker ? 35 : 0),
    unit: value.unit,
    basis: basis,
    ear: value.ear,
    ul: value.ul,
    cdrr: value.cdrr,
    notes: notes,
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
  'folate': ['UL applies to folic acid, not naturally occurring food folate.'],
  'mg': ['UL applies only to magnesium from supplements or medications.'],
  'na': ['CDRR is a risk-reduction limit, not a target to reach.'],
};

const _mg = MicroUnit.mg;
const _mcg = MicroUnit.mcg;
const _mcgRae = MicroUnit.mcgRae;
const _mcgDfe = MicroUnit.mcgDfe;
const _mgNe = MicroUnit.mgNe;

DriValue _r(MicroUnit unit, double target, {double? ul, double? cdrr}) =>
    DriValue(unit: unit, rda: target, ul: ul, cdrr: cdrr);

DriValue _a(MicroUnit unit, double target, {double? ul, double? cdrr}) =>
    DriValue(unit: unit, ai: target, ul: ul, cdrr: cdrr);

Map<String, DriValue> _row({
  required DriValue iron,
  required DriValue magnesium,
  required DriValue calcium,
  required DriValue phosphorus,
  required DriValue potassium,
  required DriValue sodium,
  required DriValue zinc,
  required DriValue vitaminC,
  required DriValue vitaminA,
  required DriValue vitaminD,
}) =>
    {
      'fe': iron,
      'mg': magnesium,
      'ca': calcium,
      'p': phosphorus,
      'k': potassium,
      'na': sodium,
      'zn': zinc,
      'vit_c': vitaminC,
      'vit_a': vitaminA,
      'vit_d': vitaminD,
    };

final Map<LifeStage, Map<String, DriValue>> _driTable = {
  LifeStage.months0To6: _row(
    iron: _a(_mg, 0.27, ul: 40),
    magnesium: _a(_mg, 30),
    calcium: _a(_mg, 200, ul: 1000),
    phosphorus: _a(_mg, 100),
    potassium: _a(_mg, 400),
    sodium: _a(_mg, 110),
    zinc: _a(_mg, 2, ul: 4),
    vitaminC: _a(_mg, 40),
    vitaminA: _a(_mcgRae, 400, ul: 600),
    vitaminD: _a(_mcg, 10, ul: 25),
  ),
  LifeStage.months7To12: _row(
    iron: _r(_mg, 11, ul: 40),
    magnesium: _a(_mg, 75),
    calcium: _a(_mg, 260, ul: 1500),
    phosphorus: _a(_mg, 275),
    potassium: _a(_mg, 860),
    sodium: _a(_mg, 370),
    zinc: _r(_mg, 3, ul: 5),
    vitaminC: _a(_mg, 50),
    vitaminA: _a(_mcgRae, 500, ul: 600),
    vitaminD: _a(_mcg, 10, ul: 38),
  ),
  LifeStage.years1To3: _row(
    iron: _r(_mg, 7, ul: 40),
    magnesium: _r(_mg, 80, ul: 65),
    calcium: _r(_mg, 700, ul: 2500),
    phosphorus: _r(_mg, 460, ul: 3000),
    potassium: _a(_mg, 2000),
    sodium: _a(_mg, 800, cdrr: 1200),
    zinc: _r(_mg, 3, ul: 7),
    vitaminC: _r(_mg, 15, ul: 400),
    vitaminA: _r(_mcgRae, 300, ul: 600),
    vitaminD: _r(_mcg, 15, ul: 63),
  ),
  LifeStage.years4To8: _row(
    iron: _r(_mg, 10, ul: 40),
    magnesium: _r(_mg, 130, ul: 110),
    calcium: _r(_mg, 1000, ul: 2500),
    phosphorus: _r(_mg, 500, ul: 3000),
    potassium: _a(_mg, 2300),
    sodium: _a(_mg, 1000, cdrr: 1500),
    zinc: _r(_mg, 5, ul: 12),
    vitaminC: _r(_mg, 25, ul: 650),
    vitaminA: _r(_mcgRae, 400, ul: 900),
    vitaminD: _r(_mcg, 15, ul: 75),
  ),
  LifeStage.maleYears9To13: _adolescentRow(
    iron: 8,
    magnesium: 240,
    potassium: 2500,
    zinc: 8,
    vitaminC: 45,
    vitaminA: 600,
    under14: true,
  ),
  LifeStage.femaleYears9To13: _adolescentRow(
    iron: 8,
    magnesium: 240,
    potassium: 2300,
    zinc: 8,
    vitaminC: 45,
    vitaminA: 600,
    under14: true,
  ),
  LifeStage.maleYears14To18: _adolescentRow(
    iron: 11,
    magnesium: 410,
    potassium: 3000,
    zinc: 11,
    vitaminC: 75,
    vitaminA: 900,
  ),
  LifeStage.femaleYears14To18: _adolescentRow(
    iron: 15,
    magnesium: 360,
    potassium: 2300,
    zinc: 9,
    vitaminC: 65,
    vitaminA: 700,
  ),
  LifeStage.maleYears19To30: _adultRow(
    iron: 8,
    magnesium: 400,
    calcium: 1000,
    potassium: 3400,
    zinc: 11,
    vitaminC: 90,
    vitaminA: 900,
  ),
  LifeStage.maleYears31To50: _adultRow(
    iron: 8,
    magnesium: 420,
    calcium: 1000,
    potassium: 3400,
    zinc: 11,
    vitaminC: 90,
    vitaminA: 900,
  ),
  LifeStage.maleYears51To70: _adultRow(
    iron: 8,
    magnesium: 420,
    calcium: 1000,
    calciumUl: 2000,
    potassium: 3400,
    zinc: 11,
    vitaminC: 90,
    vitaminA: 900,
  ),
  LifeStage.maleYears70Plus: _adultRow(
    iron: 8,
    magnesium: 420,
    calcium: 1200,
    calciumUl: 2000,
    phosphorusUl: 3000,
    potassium: 3400,
    zinc: 11,
    vitaminC: 90,
    vitaminA: 900,
    vitaminD: 20,
  ),
  LifeStage.femaleYears19To30: _adultRow(
    iron: 18,
    magnesium: 310,
    calcium: 1000,
    potassium: 2600,
    zinc: 8,
    vitaminC: 75,
    vitaminA: 700,
  ),
  LifeStage.femaleYears31To50: _adultRow(
    iron: 18,
    magnesium: 320,
    calcium: 1000,
    potassium: 2600,
    zinc: 8,
    vitaminC: 75,
    vitaminA: 700,
  ),
  LifeStage.femaleYears51To70: _adultRow(
    iron: 8,
    magnesium: 320,
    calcium: 1200,
    calciumUl: 2000,
    potassium: 2600,
    zinc: 8,
    vitaminC: 75,
    vitaminA: 700,
  ),
  LifeStage.femaleYears70Plus: _adultRow(
    iron: 8,
    magnesium: 320,
    calcium: 1200,
    calciumUl: 2000,
    phosphorusUl: 3000,
    potassium: 2600,
    zinc: 8,
    vitaminC: 75,
    vitaminA: 700,
    vitaminD: 20,
  ),
  LifeStage.pregnancyUnder19: _pregnancyRow(
    magnesium: 400,
    calcium: 1300,
    calciumUl: 3000,
    phosphorus: 1250,
    potassium: 2600,
    zinc: 12,
    vitaminC: 80,
    vitaminA: 750,
    zincUl: 34,
    vitaminCUl: 1800,
    vitaminAUl: 2800,
  ),
  LifeStage.pregnancyYears19To30: _pregnancyRow(
    magnesium: 350,
    calcium: 1000,
    calciumUl: 2500,
    phosphorus: 700,
    potassium: 2900,
    zinc: 11,
    vitaminC: 85,
    vitaminA: 770,
  ),
  LifeStage.pregnancyYears31To50: _pregnancyRow(
    magnesium: 360,
    calcium: 1000,
    calciumUl: 2500,
    phosphorus: 700,
    potassium: 2900,
    zinc: 11,
    vitaminC: 85,
    vitaminA: 770,
  ),
  LifeStage.lactationUnder19: _lactationRow(
    magnesium: 360,
    calcium: 1300,
    calciumUl: 3000,
    phosphorus: 1250,
    potassium: 2500,
    zinc: 13,
    vitaminC: 115,
    vitaminA: 1200,
    zincUl: 34,
    vitaminCUl: 1800,
    vitaminAUl: 2800,
  ),
  LifeStage.lactationYears19To30: _lactationRow(
    magnesium: 310,
    calcium: 1000,
    calciumUl: 2500,
    phosphorus: 700,
    potassium: 2800,
    zinc: 12,
    vitaminC: 120,
    vitaminA: 1300,
  ),
  LifeStage.lactationYears31To50: _lactationRow(
    magnesium: 320,
    calcium: 1000,
    calciumUl: 2500,
    phosphorus: 700,
    potassium: 2800,
    zinc: 12,
    vitaminC: 120,
    vitaminA: 1300,
  ),
};

Map<String, DriValue> _adolescentRow({
  required double iron,
  required double magnesium,
  required double potassium,
  required double zinc,
  required double vitaminC,
  required double vitaminA,
  bool under14 = false,
}) =>
    _row(
      iron: _r(_mg, iron, ul: under14 ? 40 : 45),
      magnesium: _r(_mg, magnesium, ul: 350),
      calcium: _r(_mg, 1300, ul: 3000),
      phosphorus: _r(_mg, 1250, ul: 4000),
      potassium: _a(_mg, potassium),
      sodium: _a(_mg, under14 ? 1200 : 1500, cdrr: under14 ? 1800 : 2300),
      zinc: _r(_mg, zinc, ul: under14 ? 23 : 34),
      vitaminC: _r(_mg, vitaminC, ul: under14 ? 1200 : 1800),
      vitaminA: _r(_mcgRae, vitaminA, ul: under14 ? 1700 : 2800),
      vitaminD: _r(_mcg, 15, ul: 100),
    );

Map<String, DriValue> _adultRow({
  required double iron,
  required double magnesium,
  required double calcium,
  double calciumUl = 2500,
  double phosphorusUl = 4000,
  required double potassium,
  required double zinc,
  required double vitaminC,
  required double vitaminA,
  double vitaminD = 15,
}) =>
    _row(
      iron: _r(_mg, iron, ul: 45),
      magnesium: _r(_mg, magnesium, ul: 350),
      calcium: _r(_mg, calcium, ul: calciumUl),
      phosphorus: _r(_mg, 700, ul: phosphorusUl),
      potassium: _a(_mg, potassium),
      sodium: _a(_mg, 1500, cdrr: 2300),
      zinc: _r(_mg, zinc, ul: 40),
      vitaminC: _r(_mg, vitaminC, ul: 2000),
      vitaminA: _r(_mcgRae, vitaminA, ul: 3000),
      vitaminD: _r(_mcg, vitaminD, ul: 100),
    );

Map<String, DriValue> _pregnancyRow({
  required double magnesium,
  required double calcium,
  required double calciumUl,
  required double phosphorus,
  required double potassium,
  required double zinc,
  required double vitaminC,
  required double vitaminA,
  double zincUl = 40,
  double vitaminCUl = 2000,
  double vitaminAUl = 3000,
}) =>
    _row(
      iron: _r(_mg, 27, ul: 45),
      magnesium: _r(_mg, magnesium, ul: 350),
      calcium: _r(_mg, calcium, ul: calciumUl),
      phosphorus: _r(_mg, phosphorus, ul: 3500),
      potassium: _a(_mg, potassium),
      sodium: _a(_mg, 1500, cdrr: 2300),
      zinc: _r(_mg, zinc, ul: zincUl),
      vitaminC: _r(_mg, vitaminC, ul: vitaminCUl),
      vitaminA: _r(_mcgRae, vitaminA, ul: vitaminAUl),
      vitaminD: _r(_mcg, 15, ul: 100),
    );

Map<String, DriValue> _lactationRow({
  required double magnesium,
  required double calcium,
  required double calciumUl,
  required double phosphorus,
  required double potassium,
  required double zinc,
  required double vitaminC,
  required double vitaminA,
  double zincUl = 40,
  double vitaminCUl = 2000,
  double vitaminAUl = 3000,
}) =>
    _row(
      iron: _r(_mg, phosphorus == 1250 ? 10 : 9, ul: 45),
      magnesium: _r(_mg, magnesium, ul: 350),
      calcium: _r(_mg, calcium, ul: calciumUl),
      phosphorus: _r(_mg, phosphorus, ul: 4000),
      potassium: _a(_mg, potassium),
      sodium: _a(_mg, 1500, cdrr: 2300),
      zinc: _r(_mg, zinc, ul: zincUl),
      vitaminC: _r(_mg, vitaminC, ul: vitaminCUl),
      vitaminA: _r(_mcgRae, vitaminA, ul: vitaminAUl),
      vitaminD: _r(_mcg, 15, ul: 100),
    );

Map<String, DriValue> _vitaminRow({
  required DriValue vitaminE,
  required DriValue vitaminK,
  required DriValue vitaminB1,
  required DriValue vitaminB2,
  required DriValue vitaminB3,
  required DriValue vitaminB6,
  required DriValue vitaminB12,
  required DriValue folate,
}) =>
    {
      'vit_e': vitaminE,
      'vit_k': vitaminK,
      'vit_b1': vitaminB1,
      'vit_b2': vitaminB2,
      'vit_b3': vitaminB3,
      'vit_b6': vitaminB6,
      'vit_b12': vitaminB12,
      'folate': folate,
    };

Map<String, DriValue> _infantVitamins({required bool older}) => _vitaminRow(
      vitaminE: _a(_mg, older ? 5 : 4),
      vitaminK: _a(_mcg, older ? 2.5 : 2),
      vitaminB1: _a(_mg, older ? 0.3 : 0.2),
      vitaminB2: _a(_mg, older ? 0.4 : 0.3),
      vitaminB3: _a(_mgNe, older ? 4 : 2),
      vitaminB6: _a(_mg, older ? 0.3 : 0.1),
      vitaminB12: _a(_mcg, older ? 0.5 : 0.4),
      folate: _a(_mcgDfe, older ? 80 : 65),
    );

Map<String, DriValue> _childVitamins({required bool older}) => _vitaminRow(
      vitaminE: _r(_mg, older ? 7 : 6, ul: older ? 300 : 200),
      vitaminK: _a(_mcg, older ? 55 : 30),
      vitaminB1: _r(_mg, older ? 0.6 : 0.5),
      vitaminB2: _r(_mg, older ? 0.6 : 0.5),
      vitaminB3: _r(_mgNe, older ? 8 : 6, ul: older ? 15 : 10),
      vitaminB6: _r(_mg, older ? 0.6 : 0.5, ul: older ? 40 : 30),
      vitaminB12: _r(_mcg, older ? 1.2 : 0.9),
      folate: _r(_mcgDfe, older ? 200 : 150, ul: older ? 400 : 300),
    );

Map<String, DriValue> _teenVitamins({
  required bool male,
  required bool under14,
}) =>
    _vitaminRow(
      vitaminE: _r(_mg, under14 ? 11 : 15, ul: under14 ? 600 : 800),
      vitaminK: _a(_mcg, under14 ? 60 : 75),
      vitaminB1: _r(_mg, under14 ? 0.9 : (male ? 1.2 : 1.0)),
      vitaminB2: _r(_mg, under14 ? 0.9 : (male ? 1.3 : 1.0)),
      vitaminB3:
          _r(_mgNe, under14 ? 12 : (male ? 16 : 14), ul: under14 ? 20 : 30),
      vitaminB6:
          _r(_mg, under14 ? 1.0 : (male ? 1.3 : 1.2), ul: under14 ? 60 : 80),
      vitaminB12: _r(_mcg, under14 ? 1.8 : 2.4),
      folate: _r(_mcgDfe, under14 ? 300 : 400, ul: under14 ? 600 : 800),
    );

Map<String, DriValue> _adultVitamins({
  required bool male,
  bool olderThan50 = false,
}) =>
    _vitaminRow(
      vitaminE: _r(_mg, 15, ul: 1000),
      vitaminK: _a(_mcg, male ? 120 : 90),
      vitaminB1: _r(_mg, male ? 1.2 : 1.1),
      vitaminB2: _r(_mg, male ? 1.3 : 1.1),
      vitaminB3: _r(_mgNe, male ? 16 : 14, ul: 35),
      vitaminB6: _r(_mg, olderThan50 ? (male ? 1.7 : 1.5) : 1.3, ul: 100),
      vitaminB12: _r(_mcg, 2.4),
      folate: _r(_mcgDfe, 400, ul: 1000),
    );

Map<String, DriValue> _pregnancyVitamins({required bool under19}) =>
    _vitaminRow(
      vitaminE: _r(_mg, 15, ul: under19 ? 800 : 1000),
      vitaminK: _a(_mcg, under19 ? 75 : 90),
      vitaminB1: _r(_mg, 1.4),
      vitaminB2: _r(_mg, 1.4),
      vitaminB3: _r(_mgNe, 18, ul: under19 ? 30 : 35),
      vitaminB6: _r(_mg, 1.9, ul: under19 ? 80 : 100),
      vitaminB12: _r(_mcg, 2.6),
      folate: _r(_mcgDfe, 600, ul: under19 ? 800 : 1000),
    );

Map<String, DriValue> _lactationVitamins({required bool under19}) =>
    _vitaminRow(
      vitaminE: _r(_mg, 19, ul: under19 ? 800 : 1000),
      vitaminK: _a(_mcg, under19 ? 75 : 90),
      vitaminB1: _r(_mg, 1.4),
      vitaminB2: _r(_mg, 1.6),
      vitaminB3: _r(_mgNe, 17, ul: under19 ? 30 : 35),
      vitaminB6: _r(_mg, 2.0, ul: under19 ? 80 : 100),
      vitaminB12: _r(_mcg, 2.8),
      folate: _r(_mcgDfe, 500, ul: under19 ? 800 : 1000),
    );

final Map<LifeStage, Map<String, DriValue>> _additionalVitaminTable = {
  LifeStage.months0To6: _infantVitamins(older: false),
  LifeStage.months7To12: _infantVitamins(older: true),
  LifeStage.years1To3: _childVitamins(older: false),
  LifeStage.years4To8: _childVitamins(older: true),
  LifeStage.maleYears9To13: _teenVitamins(male: true, under14: true),
  LifeStage.femaleYears9To13: _teenVitamins(male: false, under14: true),
  LifeStage.maleYears14To18: _teenVitamins(male: true, under14: false),
  LifeStage.femaleYears14To18: _teenVitamins(male: false, under14: false),
  LifeStage.maleYears19To30: _adultVitamins(male: true),
  LifeStage.maleYears31To50: _adultVitamins(male: true),
  LifeStage.maleYears51To70: _adultVitamins(male: true, olderThan50: true),
  LifeStage.maleYears70Plus: _adultVitamins(male: true, olderThan50: true),
  LifeStage.femaleYears19To30: _adultVitamins(male: false),
  LifeStage.femaleYears31To50: _adultVitamins(male: false),
  LifeStage.femaleYears51To70: _adultVitamins(male: false, olderThan50: true),
  LifeStage.femaleYears70Plus: _adultVitamins(male: false, olderThan50: true),
  LifeStage.pregnancyUnder19: _pregnancyVitamins(under19: true),
  LifeStage.pregnancyYears19To30: _pregnancyVitamins(under19: false),
  LifeStage.pregnancyYears31To50: _pregnancyVitamins(under19: false),
  LifeStage.lactationUnder19: _lactationVitamins(under19: true),
  LifeStage.lactationYears19To30: _lactationVitamins(under19: false),
  LifeStage.lactationYears31To50: _lactationVitamins(under19: false),
};
