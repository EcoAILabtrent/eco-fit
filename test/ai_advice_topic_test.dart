import 'package:eco_mobile/ai/ai_advice_contract.dart';
import 'package:flutter_test/flutter_test.dart';

// The 29 micronutrient DB codes that back the AI advice contract — every one
// can be flagged as critical (deficit or over-UL/CDRR), so every one MUST map
// to a topic via AiAdviceTopic.forMicroKey. Iodine (i) and chloride (cl) used
// to be missing from the screen's copy of this mapping, so a 1 kg salt entry
// pushed them far over their UL yet they never appeared under "critical".
const _adviceKeys = {
  'fe', 'mg', 'ca', 'p', 'k', 'na', 'zn',
  'vit_a', 'vit_c', 'vit_d', 'vit_e', 'vit_k',
  'vit_b1', 'vit_b2', 'vit_b3', 'vit_b6', 'vit_b9', 'vit_b12',
  'cu', 'mn', 'se', 'i', 'mo', 'cr', 'cl', 'f', 'vit_b4', 'vit_b5', 'vit_h',
};

void main() {
  test('every advice micronutrient key maps to a topic', () {
    for (final key in _adviceKeys) {
      expect(AiAdviceTopic.forMicroKey(key), isNotNull,
          reason: '$key can be critical but has no advice topic');
    }
  });

  test('iodine and chloride are mapped (regression: salt over-UL)', () {
    expect(AiAdviceTopic.forMicroKey('i'), AiAdviceTopic.iodine);
    expect(AiAdviceTopic.forMicroKey('cl'), AiAdviceTopic.chloride);
  });

  test('the mapping is a bijection over the 29 advice keys', () {
    final topics = {
      for (final key in _adviceKeys) AiAdviceTopic.forMicroKey(key),
    };
    expect(topics.length, _adviceKeys.length,
        reason: 'two keys must not collapse to the same topic');
  });

  test('keys without a consensus reference map to null', () {
    // Sulfur and cobalt never get a target, and macro nutrients are not micros.
    for (final key in ['s', 'co', 'calories', 'protein', '']) {
      expect(AiAdviceTopic.forMicroKey(key), isNull, reason: 'unexpected: $key');
    }
  });
}
