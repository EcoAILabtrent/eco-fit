import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai_advice_card.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Home dashboard — port of Eco design home.jsx (Frame-1).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const t = EcoTheme.meadow;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    // Пересобираем главный экран только когда меняется одно из ПОКАЗАННЫХ
    // значений, а не на любой notify стора (тоггл избранного, смена времени
    // приёма, аватар и т.п.). Фоновые тики, не меняющие эти числа, экран не
    // трогают.
    context.select<AppStore, int>(
      (s) => Object.hash(
        s.macros.carbs,
        s.macros.fat,
        s.macros.protein,
        s.carbGoal,
        s.fatGoal,
        s.protGoal,
        s.consumed,
        s.goalKcal,
        s.weight,
        s.steps,
        s.stepsGoal,
        s.water,
        s.waterGoal,
      ),
    );
    final l = context.l10n;
    final waterPct =
        (s.waterGoal > 0 ? s.water / s.waterGoal * 100 : 0).round();
    final stepsPct =
        (s.stepsGoal > 0 ? s.steps / s.stepsGoal * 100 : 0).round();

    return EcoScreen(
      t: t,
      footer: EcoBottomNav(
        t: t,
        active: 'home',
        onHome: () {},
        onProfile: () => Navigator.of(context).pushNamed('/profile'),
        onPlus: () => showMealPicker(context),
      ),
      child: Padding(
        // SafeArea handles the status bar. Bottom clears the fixed nav band
        // (91 + 16 float + system inset) so the last card scrolls fully out.
        padding: EdgeInsets.only(
          top: 24,
          bottom: 132 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 18, top: 4),
              child: Text(
                l.t('common.today'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),

            const AiAdviceCard(t: t),

            // Еда
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.of(context).pushNamed('/dayview'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EcoCardHead(
                    t: t,
                    icon: 'food',
                    title: l.t('home.food'),
                    mb: 8,
                  ),
                  SizedBox(
                    height: 174,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MacroRings(
                          size: 168,
                          data: [
                            MacroRingData(
                              value: s.macros.carbs,
                              goal: s.carbGoal.toDouble(),
                              color: EcoColors.carb,
                              soft: EcoColors.carbSoft,
                            ),
                            MacroRingData(
                              value: s.macros.fat,
                              goal: s.fatGoal.toDouble(),
                              color: EcoColors.fat,
                              soft: EcoColors.fatSoft,
                            ),
                            MacroRingData(
                              value: s.macros.protein,
                              goal: s.protGoal.toDouble(),
                              color: EcoColors.prot,
                              soft: EcoColors.protSoft,
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: const Offset(-10, 0),
                              child: MacroLegend(
                                t: t,
                                // Macros shown in kcal (как в прототипе): carbs/protein ×4, fat ×9.
                                items: [
                                  (
                                    label: l.nutrient('carbs'),
                                    value: (s.macros.carbs * 4).round(),
                                    goal: s.carbGoal * 4,
                                    color: EcoColors.carb,
                                  ),
                                  (
                                    label: l.nutrient('fat'),
                                    value: (s.macros.fat * 9).round(),
                                    goal: s.fatGoal * 9,
                                    color: EcoColors.fat,
                                  ),
                                  (
                                    label: l.nutrient('protein'),
                                    value: (s.macros.protein * 4).round(),
                                    goal: s.protGoal * 4,
                                    color: EcoColors.prot,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  CalorieTrack(t: t, value: s.consumed, goal: s.goalKcal),
                ],
              ),
            ),

            // Параметры тела
            _MetricCard(
              icon: 'body',
              title: l.t('home.bodyParams'),
              onTap: () => Navigator.of(context).pushNamed('/body'),
              left: EcoPill(
                t: t,
                bg: t.dark,
                color: EcoColors.white,
                fontSize: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                text: '${s.weight > 0 ? s.weight : '—'} ${l.unit('kg')}',
              ),
              right: _BodyStatusProgress(status: _BodyStatus.fromStore(s, l)),
            ),

            // Шаги — тап включает шагомер (разрешение) либо обновляет счёт
            _MetricCard(
              icon: 'steps',
              title: l.t('home.steps'),
              onTap: () => context.read<AppStore>().enableSteps(),
              left: EcoPill(
                t: t,
                bg: t.dark,
                color: EcoColors.white,
                fontSize: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                text: '${s.steps} / ${s.stepsGoal}',
              ),
              right: _MiniProgress(pct: stepsPct, label: '$stepsPct%'),
            ),

            // Сон
            _MetricCard(
              icon: 'bed',
              title: l.t('home.sleep'),
              onTap: () => Navigator.of(context).pushNamed('/stats'),
              left: EcoBtn(
                t: t,
                height: 44,
                fontSize: 16,
                onTap: () => Navigator.of(context).pushNamed('/stats'),
                child: Text(l.t('common.input')),
              ),
              right: const _MiniProgress(pct: 62, label: '?'),
            ),

            // Вода
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.of(context).pushNamed('/water'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EcoCardHead(t: t, icon: 'water', title: l.t('home.water')),
                  // Button band is 44 tall → standard 16px gap below the title.
                  // The glass is taller and bottom-aligns with the button via a
                  // non-clipping Stack, so it rises into the header area instead
                  // of drooping below the button.
                  SizedBox(
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: EcoBtn(
                            t: t,
                            height: 44,
                            fontSize: 16,
                            onTap: () => context.read<AppStore>().addWater(250),
                            child: Text('+ 250 ${l.unit('ml')}'),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Row(
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${s.water}',
                                      style: const TextStyle(
                                        color: EcoColors.ink,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / ${s.waterGoal} ${l.unit('ml')}',
                                      style: const TextStyle(
                                        color: EcoColors.sub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 14),
                              _WaterGlass(pct: waterPct.toDouble()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Приём пищи" meal-picker — the FAB modal from home.jsx.
bool _mealPickerShowing = false;

void showMealPicker(BuildContext context, {String active = 'home'}) {
  if (_mealPickerShowing) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _mealPickerShowing = true;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MealPickerOverlay(
      sourceContext: context,
      active: active,
      onClosed: () {
        entry.remove();
        _mealPickerShowing = false;
      },
    ),
  );
  overlay.insert(entry);
}

class _MealPickerOverlay extends StatefulWidget {
  final BuildContext sourceContext;
  final String active;
  final VoidCallback onClosed;

  const _MealPickerOverlay({
    required this.sourceContext,
    required this.active,
    required this.onClosed,
  });

  @override
  State<_MealPickerOverlay> createState() => _MealPickerOverlayState();
}

class _MealPickerOverlayState extends State<_MealPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close({VoidCallback? after}) async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    widget.onClosed();
    after?.call();
  }

  void _pushAfterClose(String route, String mealKey) {
    _close(
      after: () {
        if (!widget.sourceContext.mounted) return;
        Navigator.of(widget.sourceContext).pushNamed(route, arguments: mealKey);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final navBottom = math.max(30.0, bottomInset + 6.0);
    final navScale = math.min(0.964, (media.size.width - 32) / 310);
    final sheetBottom = navBottom + 83 * navScale;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          final panel =
              (_closing ? Curves.easeInCubic : Curves.easeOutBack).transform(v);
          final opacity = (_closing ? Curves.easeInCubic : Curves.easeOutCubic)
              .transform(v)
              .clamp(0.0, 1.0);
          final barrierColor = Color.lerp(
            Colors.transparent,
            const Color(0x00000000),
            opacity,
          )!;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(color: barrierColor),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: sheetBottom,
                child: Center(
                  child: Transform.scale(
                    scale: navScale,
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, (1 - panel) * 460),
                      child: Opacity(
                        opacity: opacity,
                        child: SizedBox(
                          width: 310,
                          child: _MealPickerSheet(
                            onOpenMeal: (mealKey) =>
                                _pushAfterClose('/meallog', mealKey),
                            onAddFood: (mealKey) =>
                                _pushAfterClose('/addfood', mealKey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              EcoBottomNav(
                t: t,
                active: widget.active,
                fabTurns: 0.125 * opacity,
                trackActive: false,
                darkGlass: false,
                onHome: _close,
                onProfile: _close,
                onPlus: _close,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MealPickerSheet extends StatelessWidget {
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddFood;

  const _MealPickerSheet({
    required this.onOpenMeal,
    required this.onAddFood,
  });

  static const _order = [
    'snackE',
    'snackD',
    'snackM',
    'dinner',
    'lunch',
    'breakfast',
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meals = [
      for (final key in _order)
        kMeals.firstWhere(
          (meal) => meal.key == key,
          orElse: () => kMeals.first,
        ),
    ];
    final store = context.watch<AppStore>();
    return SizedBox(
      height: 336,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _MealPickerShadowPainter()),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _MealPickerPanelClipper(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: ColoredBox(
                  color: const Color(0xEEF6F8F5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 18, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.t('home.mealPicker'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: EcoColors.ink,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final (i, meal) in meals.indexed) ...[
                          _MealPickerRow(
                            meal: meal,
                            kcal: store.mealKcal(meal.key),
                            onOpenMeal: onOpenMeal,
                            onAddFood: onAddFood,
                          ),
                          if (i < meals.length - 1) const _MealPickerDivider(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _MealPickerChromePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealPickerDivider extends StatelessWidget {
  const _MealPickerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 43, right: 28),
      child: Divider(
        height: 1,
        thickness: 1.4,
        color: Color(0xD8F4F4F4),
      ),
    );
  }
}

class _MealPickerPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _mealPickerPanelPath(size);

  @override
  bool shouldReclip(_MealPickerPanelClipper oldClipper) => false;
}

class _MealPickerShadowPainter extends CustomPainter {
  const _MealPickerShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mealPickerPanelPath(size);
    canvas.drawPath(
      path.shift(const Offset(-2, -3)),
      Paint()
        ..color = const Color(0x32FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_MealPickerShadowPainter oldDelegate) => false;
}

class _MealPickerChromePainter extends CustomPainter {
  const _MealPickerChromePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mealPickerPanelPath(size);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..color = const Color(0x3BFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = const Color(0x91FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.restore();

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.84),
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.08),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(_MealPickerChromePainter oldDelegate) => false;
}

Path _mealPickerPanelPath(Size size) {
  final w = size.width;
  final h = size.height;
  final r = math.min(28.0, w * 0.09);
  final sx = w / 310.0;
  final sy = sx;

  return Path()
    ..moveTo(r, 0)
    ..lineTo(w - r, 0)
    ..cubicTo(w - 12, 0, w, 12, w, r)
    ..lineTo(w, h - r)
    ..cubicTo(w, h - 12, w - 12, h, w - r, h)
    ..lineTo(228.8 * sx, h)
    ..cubicTo(
      222.803 * sx,
      h,
      219.805 * sx,
      h,
      218.07 * sx,
      h - 0.308 * sy,
    )
    ..cubicTo(
      211.108 * sx,
      h - 1.544 * sy,
      211.057 * sx,
      h - 1.573 * sy,
      206.434 * sx,
      h - 6.923 * sy,
    )
    ..cubicTo(
      205.282 * sx,
      h - 8.256 * sy,
      201.853 * sx,
      h - 14.017 * sy,
      194.995 * sx,
      h - 25.538 * sy,
    )
    ..cubicTo(
      186.276 * sx,
      h - 40.186 * sy,
      170.284 * sx,
      h - 50 * sy,
      152 * sx,
      h - 50 * sy,
    )
    ..cubicTo(
      133.716 * sx,
      h - 50 * sy,
      117.724 * sx,
      h - 40.186 * sy,
      109.005 * sx,
      h - 25.538 * sy,
    )
    ..cubicTo(
      102.147 * sx,
      h - 14.017 * sy,
      98.718 * sx,
      h - 8.256 * sy,
      97.566 * sx,
      h - 6.923 * sy,
    )
    ..cubicTo(
      92.943 * sx,
      h - 1.573 * sy,
      92.892 * sx,
      h - 1.544 * sy,
      85.93 * sx,
      h - 0.308 * sy,
    )
    ..cubicTo(
      84.196 * sx,
      h,
      81.197 * sx,
      h,
      75.2 * sx,
      h,
    )
    ..lineTo(r, h)
    ..cubicTo(12, h, 0, h - 12, 0, h - r)
    ..lineTo(0, r)
    ..cubicTo(0, 12, 12, 0, r, 0)
    ..close();
}

class _MealPickerRow extends StatelessWidget {
  final Meal meal;
  final int kcal;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddFood;

  const _MealPickerRow({
    required this.meal,
    required this.kcal,
    required this.onOpenMeal,
    required this.onAddFood,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpenMeal(meal.key),
              child: Row(
                children: [
                  _MealPickerCalBadge(value: kcal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.meal(meal.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EcoColors.ink,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onAddFood(meal.key),
            child: SizedBox(
              width: 42,
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 2,
                    height: 23,
                    decoration: BoxDecoration(
                      color: const Color(0x663C3C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.add,
                    size: 33,
                    color: Color(0xFF3C3C3C),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealPickerCalBadge extends StatelessWidget {
  final int value;

  const _MealPickerCalBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: 31,
      height: 31,
      decoration: const BoxDecoration(
        color: Color(0xDBD6D6D4),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: EcoColors.faint,
              height: 1,
            ),
          ),
          Text(
            l.unit('cal'),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: EcoColors.faint,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget left;
  final Widget right;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.left,
    required this.right,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    return EcoCard(
      t: t,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoCardHead(t: t, icon: icon, title: title),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [left, right],
          ),
        ],
      ),
    );
  }
}

enum _BodyStatusLevel {
  low,
  average,
  high;

  Color get color => switch (this) {
        _BodyStatusLevel.low => const Color(0xFFE1BE45),
        _BodyStatusLevel.average => EcoColors.statusGood,
        _BodyStatusLevel.high => const Color(0xFFD98445),
      };

  Alignment get labelAlignment => switch (this) {
        _BodyStatusLevel.low => Alignment.centerLeft,
        _BodyStatusLevel.average => Alignment.center,
        _BodyStatusLevel.high => Alignment.centerRight,
      };

  int get activeSegment => switch (this) {
        _BodyStatusLevel.low => 0,
        _BodyStatusLevel.average => 1,
        _BodyStatusLevel.high => 2,
      };

  String get labelKey => switch (this) {
        _BodyStatusLevel.low => 'bodyStatus.low',
        _BodyStatusLevel.average => 'bodyStatus.average',
        _BodyStatusLevel.high => 'bodyStatus.high',
      };
}

class _BodyStatus {
  final _BodyStatusLevel level;
  final String label;
  final double progress;

  const _BodyStatus({
    required this.level,
    required this.label,
    required this.progress,
  });

  static _BodyStatus fromStore(AppStore store, AppStrings strings) {
    final weightKg = store.weight > 0 ? store.weight : store.weightKg;
    final heightCm = store.heightCm;
    final bmi = weightKg != null && weightKg > 0 && heightCm != null
        ? weightKg / math.pow(heightCm / 100, 2)
        : null;
    final progress = _combineProgress(
      _progressForBodyFat(store.bodyFat, store.gender),
      bmi == null ? null : _progressForBmi(bmi.toDouble()),
    );
    final level = _levelForProgress(progress);

    return _BodyStatus(
      level: level,
      label: strings.t(level.labelKey),
      progress: progress,
    );
  }

  static double _combineProgress(
    double? bodyFatProgress,
    double? bmiProgress,
  ) {
    final values = [
      if (bodyFatProgress != null) bodyFatProgress,
      if (bmiProgress != null) bmiProgress,
    ];
    if (values.isEmpty) return 0.5;
    return (values.reduce((sum, value) => sum + value) / values.length)
        .clamp(0.0, 1.0);
  }

  static double? _progressForBodyFat(double value, String? gender) {
    if (value <= 0) return null;
    final lowLimit = gender == 'f'
        ? 21.0
        : gender == 'm'
            ? 14.0
            : 18.0;
    final highLimit = gender == 'f'
        ? 32.0
        : gender == 'm'
            ? 25.0
            : 30.0;
    final range = highLimit - lowLimit;

    return _progressFromRange(
      value: value,
      lowLimit: lowLimit,
      highLimit: highLimit,
      minValue: math.max(2.0, lowLimit - range),
      maxValue: highLimit + range,
    );
  }

  static double _progressForBmi(double value) => _progressFromRange(
        value: value,
        lowLimit: 18.5,
        highLimit: 25,
        minValue: 16,
        maxValue: 35,
      );

  static double _progressFromRange({
    required double value,
    required double lowLimit,
    required double highLimit,
    required double minValue,
    required double maxValue,
  }) {
    if (value < lowLimit) {
      final local =
          ((value - minValue) / (lowLimit - minValue)).clamp(0.0, 1.0);
      return local / 3;
    }
    if (value >= highLimit) {
      final local =
          ((value - highLimit) / (maxValue - highLimit)).clamp(0.0, 1.0);
      return 2 / 3 + local / 3;
    }
    final local = ((value - lowLimit) / (highLimit - lowLimit)).clamp(0.0, 1.0);
    return 1 / 3 + local / 3;
  }

  static _BodyStatusLevel _levelForProgress(double progress) {
    if (progress < 1 / 3) return _BodyStatusLevel.low;
    if (progress >= 2 / 3) return _BodyStatusLevel.high;
    return _BodyStatusLevel.average;
  }
}

class _BodyStatusProgress extends StatelessWidget {
  final _BodyStatus status;

  const _BodyStatusProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    return SizedBox(
      width: 132,
      child: Column(
        children: [
          Align(
            alignment: status.level.labelAlignment,
            child: EcoPill(
              t: t,
              bg: status.level.color,
              color: EcoColors.white,
              text: status.label,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 12,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, box) {
                return Stack(
                  children: [
                    // Track.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: EcoColors.white.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Coloured fill — rounded on both ends.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: (box.maxWidth * status.progress)
                          .clamp(0.0, box.maxWidth),
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: status.level.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    // Inset (recessed) shadow — adds depth.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x40000000), Color(0x00000000)],
                              stops: [0.0, 0.5],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final int pct;
  final String label;

  const _MiniProgress({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    final progress = (pct / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment(-1 + progress * 2, 0),
            child: EcoPill(
              t: t,
              text: label,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 12,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, box) {
                return Stack(
                  children: [
                    // Track.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.bandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Rounded fill.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: (box.maxWidth * progress).clamp(0.0, box.maxWidth),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.olive,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Inset (recessed) shadow — adds depth.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x40000000), Color(0x00000000)],
                              stops: [0.0, 0.5],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterGlass extends StatelessWidget {
  final double pct;
  const _WaterGlass({required this.pct});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 76,
      child: CustomPaint(painter: _GlassPainter(pct)),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double pct;
  _GlassPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Trapezoid cup: polygon(8% 0, 92% 0, 84% 100%, 16% 100%)
    final cup = Path()
      ..moveTo(w * 0.08, 0)
      ..lineTo(w * 0.92, 0)
      ..lineTo(w * 0.84, h)
      ..lineTo(w * 0.16, h)
      ..close();
    canvas.save();
    canvas.clipPath(cup);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFDCEAF6),
    );
    final fillH = h * (pct / 100).clamp(0.0, 1.0);
    final grad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [EcoColors.water, EcoColors.waterDeep],
      ).createShader(Rect.fromLTWH(0, h - fillH, w, fillH));
    canvas.drawRect(Rect.fromLTWH(0, h - fillH, w, fillH), grad);
    canvas.restore();
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4E7FC4).withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.pct != pct;
}
