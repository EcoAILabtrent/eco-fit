import 'package:flutter/cupertino.dart';
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
  static const total = 8;

  int step = 0;
  String profileName = '';
  String sex = 'm';
  late DateTime birthDate;
  int height = 178;
  int weight = 66;
  String activity = 'mid';
  String goal = 'lose';
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    profileName = store.profileName ?? '';
    sex = store.gender == 'f' ? 'f' : 'm';
    birthDate = store.birthDate ?? DateTime(DateTime.now().year - 25, 1, 1);
    height = store.heightCm ?? 178;
    weight = (store.weightKg ?? (store.weight > 0 ? store.weight : 66))
        .round()
        .clamp(30, 200)
        .toInt();
    activity = store.activity ?? 'mid';
    goal = store.goal ?? 'lose';
    _nameCtrl = TextEditingController(text: profileName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Mifflin–St Jeor daily norm (as in the design).
  int get _bmr {
    final age = AppStore.ageFromBirth(birthDate);
    return (10 * weight + 6.25 * height - 5 * age + (sex == 'm' ? 5 : -161))
        .round();
  }

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
          profileName: profileName,
          gender: sex,
          birthDate: birthDate,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(child: EcoGlassBackground(t: t)),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _ProgressHeader(
                        t: t,
                        step: step,
                        total: total,
                        onBack: _prev,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: box.maxHeight,
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: _buildStep(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: bottomInset + 24,
                          top: 8,
                        ),
                        child: SizedBox(
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
                      ),
                    ],
                  ),
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
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                  letterSpacing: 0,
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
          ),
        );
      case 1:
        return _Step(
          title: l.t('onboarding.nameTitle'),
          sub: l.t('onboarding.nameSub'),
          children: [
            EcoCard(
              t: t,
              child: TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (v) => profileName = v,
                decoration: InputDecoration(
                  hintText: l.t('profile.myProfile'),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.ink,
                ),
              ),
            ),
          ],
        );
      case 2:
        return _Step(
          title: l.t('onboarding.genderTitle'),
          children: [
            _OptionCard(
              icon: 'male',
              title: l.t('profile.male'),
              active: sex == 'm',
              onTap: () => setState(() => sex = 'm'),
            ),
            _OptionCard(
              icon: 'female',
              title: l.t('profile.female'),
              active: sex == 'f',
              onTap: () => setState(() => sex = 'f'),
            ),
          ],
        );
      case 3:
        return _Step(
          title: l.t('onboarding.ageTitle'),
          children: [
            EcoCard(
              t: t,
              child: SizedBox(
                height: 200,
                child: EcoDatePicker(
                  t: t,
                  initialDate: birthDate,
                  minYear: DateTime.now().year - 100,
                  maxYear: DateTime.now().year - 12,
                  monthNames: [for (var m = 1; m <= 12; m++) l.monthName(m)],
                  onChanged: (d) => setState(() => birthDate = d),
                ),
              ),
            ),
          ],
        );
      case 4:
        return _Step(
          title: l.t('onboarding.heightTitle'),
          children: [
            EcoCard(
              t: t,
              child: _WheelValuePicker(
                value: height,
                min: 120,
                max: 220,
                unit: l.unit('cm'),
                onChanged: (v) => setState(() => height = v),
              ),
            ),
          ],
        );
      case 5:
        return _Step(
          title: l.t('onboarding.weightTitle'),
          children: [
            EcoCard(
              t: t,
              child: _WheelValuePicker(
                value: weight,
                min: 30,
                max: 200,
                unit: l.unit('kg'),
                onChanged: (v) => setState(() => weight = v),
              ),
            ),
          ],
        );
      case 6:
        return _Step(
          title: l.t('onboarding.activityTitle'),
          children: [
            _OptionCard(
              icon: 'seat',
              title: l.t('onboarding.activityLow'),
              sub: l.t('onboarding.activityLowSub'),
              active: activity == 'low',
              onTap: () => setState(() => activity = 'low'),
            ),
            _OptionCard(
              icon: 'walk',
              title: l.t('onboarding.activityMid'),
              sub: l.t('onboarding.activityMidSub'),
              active: activity == 'mid',
              onTap: () => setState(() => activity = 'mid'),
            ),
            _OptionCard(
              icon: 'fitness',
              title: l.t('onboarding.activityHigh'),
              sub: l.t('onboarding.activityHighSub'),
              active: activity == 'high',
              onTap: () => setState(() => activity = 'high'),
            ),
          ],
        );
      case 7:
        return _Step(
          title: l.t('onboarding.goalTitle'),
          children: [
            _OptionCard(
              icon: 'trendDown',
              title: l.t('onboarding.goalLose'),
              active: goal == 'lose',
              onTap: () => setState(() => goal = 'lose'),
            ),
            _OptionCard(
              icon: 'balance',
              title: l.t('onboarding.goalKeep'),
              active: goal == 'keep',
              onTap: () => setState(() => goal = 'keep'),
            ),
            _OptionCard(
              icon: 'trendUp',
              title: l.t('onboarding.goalGain'),
              active: goal == 'gain',
              onTap: () => setState(() => goal = 'gain'),
            ),
          ],
        );
      default:
        final norm = _norm;
        final carbs = (norm * 0.45 / 4).round();
        final protein = (norm * 0.3 / 4).round();
        final fat = (norm * 0.25 / 9).round();
        return _Step(
          title: l.t('onboarding.dailyNorm'),
          sub: l.t('onboarding.dailyNormSub'),
          children: [
            EcoCard(
              t: t,
              pad: 18,
              child: SizedBox(
                height: 234,
                child: Row(
                  children: [
                    SizedBox(
                      width: 145,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MacroRings(
                            size: 138,
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
                          const SizedBox(height: 10),
                          Text(
                            '$norm',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.unit('kcalPerDay'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: EcoColors.sub,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _macroLine(
                            l.nutrient('carbs'),
                            '$carbs ${l.unit('g')}',
                            EcoColors.carb,
                          ),
                          const SizedBox(height: 20),
                          _macroLine(
                            l.nutrient('fat'),
                            '$fat ${l.unit('g')}',
                            EcoColors.fat,
                          ),
                          const SizedBox(height: 20),
                          _macroLine(
                            l.nutrient('protein'),
                            '$protein ${l.unit('g')}',
                            EcoColors.prot,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _macroLine(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: EcoColors.sub,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final EcoTheme t;
  final int step;
  final int total;
  final VoidCallback onBack;

  const _ProgressHeader({
    required this.t,
    required this.step,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: EcoColors.sub,
          ),
        ),
        const SizedBox(width: 8),
        const LanguageSelector(t: EcoTheme.meadow, compact: true),
      ],
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: const TextStyle(
                fontSize: 14,
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
      ),
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
                size: 30,
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
                      fontSize: 16,
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
                          fontSize: 12,
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
class _WheelValuePicker extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _WheelValuePicker({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_WheelValuePicker> createState() => _WheelValuePickerState();
}

class _WheelValuePickerState extends State<_WheelValuePicker> {
  late FixedExtentScrollController _controller;

  int get _index =>
      (widget.value - widget.min).clamp(0, widget.max - widget.min).toInt();
  int get _count => widget.max - widget.min + 1;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant _WheelValuePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min || oldWidget.max != widget.max) {
      _controller.dispose();
      _controller = FixedExtentScrollController(initialItem: _index);
      return;
    }
    if (oldWidget.value != widget.value && _controller.selectedItem != _index) {
      _controller.jumpToItem(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 216,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const EcoPickerSelectionOverlay(
            t: EcoTheme.meadow,
            margin: EdgeInsets.symmetric(horizontal: 28, vertical: 79),
            radius: 22,
          ),
          CupertinoPicker.builder(
            scrollController: _controller,
            itemExtent: 58,
            diameterRatio: 1.35,
            squeeze: 0.92,
            useMagnifier: true,
            magnification: 1.12,
            selectionOverlay: const SizedBox.shrink(),
            childCount: _count,
            onSelectedItemChanged: (index) =>
                widget.onChanged(widget.min + index),
            itemBuilder: (context, index) {
              final value = widget.min + index;
              return Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: EcoColors.ink,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.unit}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: EcoColors.sub,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
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
