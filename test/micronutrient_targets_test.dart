import 'package:eco_mobile/nutrition/micronutrients.dart';
import 'package:flutter_test/flutter_test.dart';

// The 29 micronutrients that back the AI advice contract. Every one has a
// life-stage row in _driTable; sulfur and cobalt are deliberately absent
// because no consensus reference exists for them.
const _adviceKeys = {
  'fe', 'mg', 'ca', 'p', 'k', 'na', 'zn',
  'vit_a', 'vit_c', 'vit_d', 'vit_e', 'vit_k',
  'vit_b1', 'vit_b2', 'vit_b3', 'vit_b6', 'vit_b9', 'vit_b12',
  'cu', 'mn', 'se', 'i', 'mo', 'cr', 'cl', 'f', 'vit_b4', 'vit_b5', 'vit_h',
};

// The 11 nutrients added on top of the original 18 core minerals/vitamins.
const _extendedKeys = {
  'cu', 'mn', 'se', 'i', 'mo', 'cr', 'cl', 'f', 'vit_b4', 'vit_b5', 'vit_h',
};

// Every nutrient code the food database can supply, including sulfur/cobalt,
// which must never receive a target.
const _allDbKeys = {..._adviceKeys, 's', 'co'};

Set<String> _keysFor(int age, ProfileSex sex) => calculateMicroTargets(
      NutritionProfile(
        ageYears: age,
        sex: sex,
        weightKg: 70,
        heightCm: 175,
      ),
      databaseNutrientKeys: _allDbKeys,
    ).map((t) => t.key).toSet();

void main() {
  test('every life stage receives all 29 advice references', () {
    for (final (age, sex) in [
      (6, ProfileSex.female),
      (16, ProfileSex.male),
      (30, ProfileSex.male),
      (65, ProfileSex.female),
    ]) {
      final keys = _keysFor(age, sex);
      expect(keys, equals(_adviceKeys),
          reason: 'age $age should map to exactly the 29 advice nutrients');
    }
  });

  test('the 11 extended nutrients are personalized for non-adults too', () {
    final child = _keysFor(6, ProfileSex.female);
    final teen = _keysFor(16, ProfileSex.male);
    for (final key in _extendedKeys) {
      expect(child, contains(key), reason: 'child should include $key');
      expect(teen, contains(key), reason: 'teen should include $key');
    }
  });

  test('sulfur and cobalt never receive a target', () {
    for (final age in [3, 12, 30, 65]) {
      final keys = _keysFor(age, ProfileSex.female);
      expect(keys, isNot(contains('s')));
      expect(keys, isNot(contains('co')));
    }
  });

  test('a nutrient absent from the food DB is not invented', () {
    // Only iron present in the diary -> only iron gets a target.
    final targets = calculateMicroTargets(
      const NutritionProfile(
        ageYears: 30,
        sex: ProfileSex.male,
        weightKg: 70,
        heightCm: 175,
      ),
      databaseNutrientKeys: const {'fe'},
    );
    expect(targets.map((t) => t.key), ['fe']);
  });
}
