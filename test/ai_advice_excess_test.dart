import 'package:eco_mobile/ai/ai_advice_service.dart';
import 'package:eco_mobile/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression: when a micronutrient is over its safe upper limit (UL), the
// screen shows an «Excess» chip, but the advice text used to fall through to
// the "target met, here are food sources" branch — telling the user to eat
// MORE of a nutrient they already have in dangerous excess. The text must now
// name the excess and its consequence instead. Mirrors the iron/zinc case from
// the bug report (101 mg iron vs 8 mg target; 65 mg zinc vs 11 mg target).
const _service = AiAdviceService();

Map<Object?, Object?> _excessData({
  required double amount,
  required double reference,
  required double ul,
  String unit = 'mg',
}) =>
    {
      'average_per_logged_day': amount,
      'reference_per_day': reference,
      'unit': unit,
      // Above the RDA/AI but not below EAR → status is meets_or_above_target.
      'status': 'meets_or_above_target',
      'safety_status': 'above_ul',
      'ul': ul,
      'data_quality': 'high',
    };

void main() {
  test('over-UL iron warns about excess, not deficiency', () {
    final text = _service.micronutrientClauseForTesting(
      'fe',
      _excessData(amount: 101, reference: 8, ul: 40),
      AppLanguage.uzLatn,
    );
    expect(text, contains('xavfsiz chegaradan yuqori'));
    expect(text.toLowerCase(), contains('kamaytiring')); // "reduce"
    // Must NOT tell the user there is no deficiency / to add more.
    expect(text, isNot(contains('kamlik yoʻq')));
    expect(text, isNot(contains('Manbalar')));
  });

  test('over-UL excess text is provided in every language', () {
    for (final lang in AppLanguage.values) {
      final text = _service.micronutrientClauseForTesting(
        'zn',
        _excessData(amount: 65, reference: 11, ul: 40),
        lang,
      );
      expect(text.trim(), isNotEmpty, reason: 'empty excess text for $lang');
      expect(text, contains('65'), reason: 'amount missing for $lang');
      expect(text, contains('40'), reason: 'upper limit missing for $lang');
    }
  });

  test('nutrient without a specific excess note still gets a warning', () {
    // 'k' (potassium) has no per-nutrient excess note → generic fallback.
    final text = _service.micronutrientClauseForTesting(
      'k',
      _excessData(amount: 9000, reference: 3500, ul: 4000),
      AppLanguage.en,
    );
    expect(text, contains('safe upper limit'));
    expect(text.toLowerCase(), contains('excess'));
  });

  test('within-limit intake is unchanged (target met branch)', () {
    final text = _service.micronutrientClauseForTesting(
      'fe',
      {
        'average_per_logged_day': 12.0,
        'reference_per_day': 8.0,
        'unit': 'mg',
        'status': 'meets_or_above_target',
        'safety_status': 'within_ul',
        'ul': 40.0,
        'data_quality': 'high',
      },
      AppLanguage.uzLatn,
    );
    expect(text, contains('kamlik yoʻq'));
    expect(text, contains('Manbalar'));
  });

  test('deficiency branch is unchanged', () {
    final text = _service.micronutrientClauseForTesting(
      'fe',
      {
        'average_per_logged_day': 3.0,
        'reference_per_day': 8.0,
        'unit': 'mg',
        'status': 'below_target_by',
        'safety_status': 'within_ul',
        'ul': 40.0,
        'data_quality': 'high',
      },
      AppLanguage.uzLatn,
    );
    expect(text, contains('kam'));
    expect(text, isNot(contains('xavfsiz chegaradan yuqori')));
  });
}
