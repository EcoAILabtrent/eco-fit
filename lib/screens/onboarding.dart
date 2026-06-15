import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/language_selector.dart';
import '../ui/ui.dart';

/// Onboarding — 8-step port of Eco design profile.jsx::Onboarding.
/// welcome → пол → возраст → рост → вес → активность → цель → норма.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const t = EcoTheme.meadow;
  static const total = 7;

  int step = 0;
  String sex = 'm';
  int age = 28;
  int height = 178;
  int weight = 66;
  String activity = 'mid';
  String goal = 'lose';

  // Mifflin–St Jeor daily norm (as in the design).
  int get _bmr =>
      (10 * weight + 6.25 * height - 5 * age + (sex == 'm' ? 5 : -161)).round();
  double get _actMul => switch (activity) {
    'low' => 1.2,
    'high' => 1.7,
    _ => 1.45,
  };
  int get _norm {
    final tdee = (_bmr * _actMul).round();
    return goal == 'lose'
        ? tdee - 400
        : goal == 'gain'
        ? tdee + 350
        : tdee;
  }

  void _next() {
    if (step < total) {
      setState(() => step++);
      return;
    }
    final norm = _norm;
    context.read<AppStore>().completeOnboarding(
      gender: sex,
      age: age,
      heightCm: height,
      weightKg: weight.toDouble(),
      activity: activity,
      goal: goal,
      targetKcal: norm,
    );
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _prev() {
    if (step > 0) setState(() => step--);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoScreen(
      t: t,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress row: back chevron + bar + counter
            Row(
              children: [
                GestureDetector(
                  onTap: _prev,
                  child: Icon(
                    Icons.chevron_left,
                    size: 26,
                    color: step > 0 ? EcoColors.ink : EcoColors.faint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Container(color: t.card),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 300),
                            widthFactor: (step + 1) / (total + 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: t.dark,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${step + 1}/${total + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: EcoColors.sub,
                  ),
                ),
                const SizedBox(width: 8),
                const LanguageSelector(t: t, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: EcoBtn(
                t: t,
                onTap: _next,
                child: Text(
                  step == 0
                      ? l.t('onboarding.start')
                      : step == total
                      ? l.t('onboarding.enterApp')
                      : l.t('onboarding.next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    final l = context.l10n;
    switch (step) {
      case 0:
        return Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: t.dark,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(Icons.restaurant, size: 48, color: t.pill),
            ),
            const SizedBox(height: 28),
            const Text(
              'Eco',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: Text(
                l.t('onboarding.intro'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: EcoColors.sub,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      case 1:
        return _Step(
          title: l.t('onboarding.genderTitle'),
          sub: l.t('onboarding.genderSub'),
          children: [
            _OptionCard(
              icon: 'user',
              title: l.t('profile.male'),
              active: sex == 'm',
              onTap: () => setState(() => sex = 'm'),
            ),
            _OptionCard(
              icon: 'user',
              title: l.t('profile.female'),
              active: sex == 'f',
              onTap: () => setState(() => sex = 'f'),
            ),
          ],
        );
      case 2:
        return _Step(
          title: l.t('onboarding.ageTitle'),
          children: [
            EcoCard(
              t: t,
              child: _BigStepper(
                value: age,
                unit: l.unit('years'),
                onChanged: (v) => setState(() => age = v.clamp(12, 100)),
              ),
            ),
          ],
        );
      case 3:
        return _Step(
          title: l.t('onboarding.heightTitle'),
          children: [
            EcoCard(
              t: t,
              child: _BigStepper(
                value: height,
                unit: l.unit('cm'),
                onChanged: (v) => setState(() => height = v.clamp(120, 220)),
              ),
            ),
          ],
        );
      case 4:
        return _Step(
          title: l.t('onboarding.weightTitle'),
          sub: l.t('onboarding.weightSub'),
          children: [
            EcoCard(
              t: t,
              child: _BigStepper(
                value: weight,
                unit: l.unit('kg'),
                onChanged: (v) => setState(() => weight = v.clamp(30, 200)),
              ),
            ),
          ],
        );
      case 5:
        return _Step(
          title: l.t('onboarding.activityTitle'),
          children: [
            _OptionCard(
              icon: 'bed',
              title: l.t('onboarding.activityLow'),
              sub: l.t('onboarding.activityLowSub'),
              active: activity == 'low',
              onTap: () => setState(() => activity = 'low'),
            ),
            _OptionCard(
              icon: 'steps',
              title: l.t('onboarding.activityMid'),
              sub: l.t('onboarding.activityMidSub'),
              active: activity == 'mid',
              onTap: () => setState(() => activity = 'mid'),
            ),
            _OptionCard(
              icon: 'pulse',
              title: l.t('onboarding.activityHigh'),
              sub: l.t('onboarding.activityHighSub'),
              active: activity == 'high',
              onTap: () => setState(() => activity = 'high'),
            ),
          ],
        );
      case 6:
        return _Step(
          title: l.t('onboarding.goalTitle'),
          children: [
            _OptionCard(
              icon: 'water',
              title: l.t('onboarding.goalLose'),
              active: goal == 'lose',
              onTap: () => setState(() => goal = 'lose'),
            ),
            _OptionCard(
              icon: 'gauge',
              title: l.t('onboarding.goalKeep'),
              active: goal == 'keep',
              onTap: () => setState(() => goal = 'keep'),
            ),
            _OptionCard(
              icon: 'pulse',
              title: l.t('onboarding.goalGain'),
              active: goal == 'gain',
              onTap: () => setState(() => goal = 'gain'),
            ),
          ],
        );
      default:
        final norm = _norm;
        return _Step(
          title: l.t('onboarding.dailyNorm'),
          sub: l.t('onboarding.dailyNormSub'),
          children: [
            EcoCard(
              t: t,
              child: SizedBox(
                height: 178,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const MacroRings(
                        size: 170,
                        data: [
                          MacroRingData(
                            value: 1,
                            goal: 1,
                            color: EcoColors.carb,
                            soft: EcoColors.carbSoft,
                          ),
                          MacroRingData(
                            value: 0.74,
                            goal: 1,
                            color: EcoColors.fat,
                            soft: EcoColors.fatSoft,
                          ),
                          MacroRingData(
                            value: 0.48,
                            goal: 1,
                            color: EcoColors.prot,
                            soft: EcoColors.protSoft,
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$norm',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l.unit('kcalPerDay'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: EcoColors.sub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _macroCard(
                  l.nutrient('carbs'),
                  '${(norm * 0.45 / 4).round()} ${l.unit('g')}',
                  EcoColors.carb,
                ),
                const SizedBox(width: 12),
                _macroCard(
                  l.nutrient('protein'),
                  '${(norm * 0.3 / 4).round()} ${l.unit('g')}',
                  EcoColors.prot,
                ),
                const SizedBox(width: 12),
                _macroCard(
                  l.nutrient('fat'),
                  '${(norm * 0.25 / 9).round()} ${l.unit('g')}',
                  EcoColors.fat,
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _macroCard(String label, String value, Color color) {
    return Expanded(
      child: EcoCard(
        t: t,
        pad: 14,
        child: Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: EcoColors.sub),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step layout: title + optional sub + content.
class _Step extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> children;

  const _Step({required this.title, this.sub, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(
            sub!,
            style: const TextStyle(
              fontSize: 14.5,
              color: EcoColors.sub,
              height: 1.4,
            ),
          ),
        ],
        SizedBox(height: sub != null ? 22 : 20),
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          c,
        ],
      ],
    );
  }
}

/// Selectable option row: icon badge + title/sub + radio check.
class _OptionCard extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final String icon;
  final String title;
  final String? sub;
  final bool active;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? t.dark : t.card,
          borderRadius: BorderRadius.circular(t.r),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? t.olive : t.pill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ecoIcon(icon),
                size: 20,
                color: active ? t.pill : t.dark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: active ? t.pill : EcoColors.ink,
                    ),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sub!,
                        style: TextStyle(
                          fontSize: 13,
                          color: active
                              ? Colors.white.withValues(alpha: 0.65)
                              : EcoColors.sub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active ? t.pill : Colors.transparent,
                shape: BoxShape.circle,
                border: active ? null : Border.all(color: t.bandSoft, width: 2),
              ),
              child: active ? Icon(Icons.check, size: 15, color: t.dark) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Big −/+ stepper around a large value.
class _BigStepper extends StatelessWidget {
  static const t = EcoTheme.meadow;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  const _BigStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _round(Icons.remove, () => onChanged(value - 1)),
          SizedBox(
            width: 170,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$value',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 18,
                      color: EcoColors.sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _round(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: t.pill),
      ),
    );
  }
}
