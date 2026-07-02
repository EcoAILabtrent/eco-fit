/// Energy and body-metric formulas for Eco Fit.
///
/// Resting metabolism uses Mifflin–St Jeor for adults (validated for ~19–78 y)
/// and the Schofield (WHO/FAO) weight-based equations for anyone under 18, where
/// Mifflin–St Jeor is not valid. Calorie goals are clamped to a safe floor so a
/// small or older user is never pushed to an unsafe deficit.
library;

/// Basal metabolic rate (kcal/day). Schofield for ages < 18, Mifflin–St Jeor
/// for adults. [sex] is 'm' or 'f'.
int basalMetabolicRate({
  required int ageYears,
  required String sex,
  required double weightKg,
  required double heightCm,
}) {
  final male = sex == 'm';
  if (ageYears < 18) {
    return _schofieldBmr(ageYears: ageYears, male: male, weightKg: weightKg);
  }
  return (10 * weightKg + 6.25 * heightCm - 5 * ageYears + (male ? 5 : -161))
      .round();
}

// Schofield (1985) weight-based BMR, kcal/day. Brackets 3–10 y and 10–18 y;
// the app's minimum age is 5, so the younger bracket also covers 5–9 y.
int _schofieldBmr({
  required int ageYears,
  required bool male,
  required double weightKg,
}) {
  if (ageYears < 10) {
    return male
        ? (22.7 * weightKg + 495).round()
        : (22.5 * weightKg + 499).round();
  }
  return male
      ? (17.5 * weightKg + 651).round()
      : (12.2 * weightKg + 746).round();
}

/// Physical-activity multiplier (PAL). Three UI tiers mapped to standard values:
/// sedentary 1.2, moderate 1.45, very active 1.725.
double activityMultiplier(String activity) => switch (activity) {
      'low' => 1.2,
      'high' => 1.725,
      _ => 1.45,
    };

/// Total daily energy expenditure (kcal/day).
int totalDailyEnergy({required int bmr, required String activity}) =>
    (bmr * activityMultiplier(activity)).round();

/// Minimum safe daily calorie goal (kcal): ~1500 for men, ~1200 for women, per
/// mainstream guidance against unsupervised very-low-calorie intake.
int minimumCalorieGoal(String sex) => sex == 'm' ? 1500 : 1200;

/// Daily calorie goal from TDEE, adjusted for [goal] ('lose' | 'gain' |
/// 'maintain') and clamped to [minimumCalorieGoal].
int calorieGoal({
  required int tdee,
  required String goal,
  required String sex,
}) {
  final adjusted = switch (goal) {
    'lose' => tdee - 400,
    'gain' => tdee + 350,
    _ => tdee,
  };
  final floor = minimumCalorieGoal(sex);
  return adjusted < floor ? floor : adjusted;
}

/// Full pipeline: profile → daily calorie goal.
int calorieGoalFor({
  required int ageYears,
  required String sex,
  required double weightKg,
  required double heightCm,
  required String activity,
  required String goal,
}) {
  final bmr = basalMetabolicRate(
    ageYears: ageYears,
    sex: sex,
    weightKg: weightKg,
    heightCm: heightCm,
  );
  final tdee = totalDailyEnergy(bmr: bmr, activity: activity);
  return calorieGoal(tdee: tdee, goal: goal, sex: sex);
}

/// Estimated body-water as a percentage of body mass, from body-fat percentage.
/// Fat-free mass is ~73% water, so TBW% = (100 − bodyFat%) × 0.73.
double bodyWaterPercent(double bodyFatPercent) =>
    (100 - bodyFatPercent) * 0.73;

/// Active calories (kcal) burned from a step count at a given body weight.
/// ~0.00065 kcal per step per kg ≈ 0.045 kcal/step at 70 kg (~4 METs, matching
/// the app's 110 steps/min active-minute assumption).
int walkingCalories({required int steps, required double weightKg}) =>
    (steps * weightKg * 0.00065).round();
