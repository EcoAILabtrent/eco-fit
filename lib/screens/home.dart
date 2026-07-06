import 'dart:math' as math;

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

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
        // Статус тела и BMI на карточке зависят ещё и от этих полей.
        s.weightKg,
        s.heightCm,
        s.bodyFat,
        s.gender,
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
      footer: MealPickerHost(
        t: t,
        active: 'home',
        onHome: () {},
        onProfile: () => Navigator.of(context).pushNamed('/profile'),
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
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/eco_logo.png',
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Eco',
                          style: TextStyle(
                            color: t.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' health',
                          style: TextStyle(
                            color: t.olive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  // Колокольчик уведомлений убран из шапки — настройки
                  // уведомлений доступны в профиле (Профиль → «/notifications»).
                ],
              ),
            ),

            AiAdviceCard(t: t),

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
                    // Выше прежних 174: в легенде теперь две строки на макрос
                    // (граммы + kcal), кольца (168) центрируются по вертикали.
                    height: 188,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // RepaintBoundary изолирует 3 размытых кольца от
                        // соседнего CalorieTrack: при анимации калорий кольца
                        // композитятся из кэша, а не перерисовывают blur каждый
                        // кадр (как уже сделано в dayview).
                        RepaintBoundary(
                          child: MacroRings(
                            t: t,
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
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: const Offset(-10, 0),
                              child: MacroLegend(
                                t: t,
                                // Две строки на макрос: сверху граммы
                                // (съедено/цель), снизу энергия в kcal
                                // (carbs/protein ×4, fat ×9).
                                items: [
                                  (
                                    label: l.nutrient('carbs'),
                                    grams: s.macros.carbs.round(),
                                    gramsGoal: s.carbGoal,
                                    value: (s.macros.carbs * 4).round(),
                                    goal: s.carbGoal * 4,
                                    color: EcoColors.carb,
                                  ),
                                  (
                                    label: l.nutrient('fat'),
                                    grams: s.macros.fat.round(),
                                    gramsGoal: s.fatGoal,
                                    value: (s.macros.fat * 9).round(),
                                    goal: s.fatGoal * 9,
                                    color: EcoColors.fat,
                                  ),
                                  (
                                    label: l.nutrient('protein'),
                                    grams: s.macros.protein.round(),
                                    gramsGoal: s.protGoal,
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

            // Параметры тела — «минимал»: вес, статус и BMI, без шкалы.
            _BodyCard(
              t: t,
              title: l.t('home.bodyParams'),
              // num1: «66»/«66,5» по локали, а не «66.0» с жёсткой точкой.
              weightText:
                  '${s.weight > 0 ? l.num1(s.weight) : '—'} ${l.unit('kg')}',
              status: _BodyStatus.fromStore(s, l),
              bmi: _BodyStatus.bmiFor(s),
              onTap: () => Navigator.of(context).pushNamed('/body'),
            ),

            // Шаги — тап открывает экран «Шаги» (недельный график + сводка);
            // сам шагомер включается/обновляется при открытии экрана.
            // Прогресс — дорожка из 10 следов (1 след = 1/10 цели).
            _StepsCard(
              t: t,
              title: l.t('home.steps'),
              steps: s.steps,
              goal: s.stepsGoal,
              pct: stepsPct,
              onTap: () => Navigator.of(context).pushNamed('/steps'),
            ),

            // Вода — прогресс показывает уровень в стакане, без процентов.
            _WaterCard(
              t: t,
              title: l.t('home.water'),
              water: s.water,
              goal: s.waterGoal,
              unitMl: l.unit('ml'),
              pct: waterPct.toDouble(),
              onTap: () => Navigator.of(context).pushNamed('/water'),
              onAdd: () => context.read<AppStore>().addWater(100),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Приём пищи" meal-picker — нижняя панель из home.jsx.
///
/// Живёт в `footer`-слоте [EcoScreen] как слой ВНУТРИ дерева экрана (а не
/// отдельным маршрутом). Раньше панель показывалась через `showGeneralDialog`,
/// но в Impeller маршрут экрана под прозрачным диалогом переставал
/// композититься и фон чернел. Теперь нажатие «+» просто выдвигает панель и
/// поворачивает «+» на 45° в «×» — контент сзади продолжает отрисовываться,
/// больше ничего не происходит.
class MealPickerHost extends StatefulWidget {
  final EcoTheme t;
  final String active;
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final bool hidden;

  const MealPickerHost({
    super.key,
    required this.t,
    required this.active,
    required this.onHome,
    required this.onProfile,
    this.hidden = false,
  });

  @override
  State<MealPickerHost> createState() => _MealPickerHostState();
}

class _MealPickerHostState extends State<MealPickerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _open = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Открытие («выход») панели — в 1.5 раза дольше/медленнее обычного.
      duration: kEcoMotionDuration * 1.5,
      // Закрытие оставляем как есть (обычная скорость).
      reverseDuration: kEcoMotionDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPicker() {
    if (_open) return;
    setState(() {
      _open = true;
      _closing = false;
    });
    _controller.forward(from: 0);
  }

  Future<void> _close({VoidCallback? after}) async {
    if (!_open || _closing) return;
    setState(() => _closing = true);
    await _controller.reverse();
    if (!mounted) return;
    setState(() {
      _open = false;
      _closing = false;
    });
    after?.call();
  }

  void _pushAfterClose(String route, String mealKey) {
    _close(
      after: () {
        if (!mounted) return;
        Navigator.of(context).pushNamed(route, arguments: mealKey);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final navBottom = math.max(30.0, bottomInset + 6.0);
    final navScale = math.min(0.964, (media.size.width - 32) / 310);
    final sheetBottom = navBottom + 83 * navScale;

    // Слой на весь экран: тапы мимо панели/нав-бара проваливаются к контенту,
    // пока панель закрыта (в Stack нет дочернего элемента под точкой касания).
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          // Единая кривая открытия/закрытия (без прежнего «отскока» easeOutBack),
          // чтобы выезд панели совпадал по ощущению с переходами экранов.
          final panel =
              (_closing ? Curves.easeInCubic : kEcoMotionCurve).transform(v);
          final opacity = (_closing ? Curves.easeInCubic : kEcoMotionCurve)
              .transform(v)
              .clamp(0.0, 1.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Прозрачный барьер: тап мимо панели закрывает её. Есть только
              // пока панель открыта — иначе контент сзади остаётся кликабельным.
              if (_open)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (_open)
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
                            // RepaintBoundary: три размытых painter'а панели
                            // (тень/хром σ16-18 + сложный ClipPath) растеризуются
                            // один раз и далее лишь композитятся при выезде, а не
                            // перерисовываются на каждом кадре анимации.
                            child: RepaintBoundary(
                              // Панель фиксированной высоты (432) с компактными
                              // строками (46) и бейджами (37×37): при системном
                              // textScale 1.3+ они переполняются. Ограничиваем
                              // масштаб текста внутри панели до 1.2.
                              child: MediaQuery.withClampedTextScaling(
                                maxScaleFactor: 1.2,
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
                  ),
                ),
              // Один постоянный нав-бар экрана. При открытой панели его «+»
              // поворачивается на 45° в «×», а нажатия закрывают панель.
              EcoBottomNav(
                t: t,
                active: widget.active,
                hidden: widget.hidden,
                fabTurns: 0.125 * opacity,
                onHome: _open ? () => _close() : widget.onHome,
                onProfile: _open ? () => _close() : widget.onProfile,
                onPlus: _open ? () => _close() : _openPicker,
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

  // Хронологический порядок сверху вниз: завтрак первым (как в «Журнале
  // питания»).
  static const _order = [
    'breakfast',
    'snackM',
    'lunch',
    'snackD',
    'dinner',
    'snackE',
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
    // Панель (432px) раньше висела на context.watch и перестраивалась на КАЖДЫЙ
    // тик шагомера/воды. Подписываемся точечно: тема (внешний вид) + diaryRevision
    // (kcal приёмов меняются только при правке дневника). Сам стор берём через
    // read — mealKcal ниже покрыт diaryRevision.
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>((s) => s.diaryRevision);
    final store = context.read<AppStore>();
    return SizedBox(
      // Высота увеличена (336 → 432): крупнее шрифты/строки + светлые полосы-
      // разделители. Ширина не меняется (310): вырез под FAB снизу
      // масштабируется по ширине (sx=1), поэтому остаётся корректным.
      height: 432,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MealPickerShadowPainter(isDark: t.isDark),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _MealPickerPanelClipper(),
              // Без BackdropFilter: панель почти непрозрачная, размытие там не
              // видно, а полноэкранный backdrop-сэмпл гасил фон экрана под пикером
              // (контент переставал отрисовываться).
              child: ColoredBox(
                // Фон панели по теме: светлый матовый / тёмный матовый.
                color: t.isDark
                    ? const Color(0xF21E2126)
                    : const Color(0xEEF6F8F5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 18, 38),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.t('home.mealPicker'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 17),
                      for (final (i, meal) in meals.indexed) ...[
                        _MealPickerRow(
                          t: t,
                          meal: meal,
                          kcal: store.mealKcal(meal.key),
                          onOpenMeal: onOpenMeal,
                          onAddFood: onAddFood,
                        ),
                        if (i < meals.length - 1) _MealPickerDivider(t: t),
                      ],
                    ],
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
  final EcoTheme t;

  const _MealPickerDivider({required this.t});

  @override
  Widget build(BuildContext context) {
    // Горизонтальное разделение списка — светлая полоса со скруглёнными краями
    // во всю ширину (как в «Журнале питания»).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Container(
        height: 2.5,
        decoration: BoxDecoration(
          color: t.isDark ? const Color(0x26FFFFFF) : const Color(0xFFE6EAE4),
          borderRadius: BorderRadius.circular(2),
        ),
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
  final bool isDark;

  const _MealPickerShadowPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mealPickerPanelPath(size);
    canvas.drawPath(
      path.shift(const Offset(-2, -3)),
      Paint()
        ..color = isDark ? const Color(0x55000000) : const Color(0x32FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_MealPickerShadowPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
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
    // Вырез под FAB снизу — тот же сдвиг +3, что и в баре навигации, чтобы
    // «×» сидел по центру выреза (центр панели = 155).
    ..lineTo(231.8 * sx, h)
    ..cubicTo(
      225.803 * sx,
      h,
      222.805 * sx,
      h,
      221.07 * sx,
      h - 0.308 * sy,
    )
    ..cubicTo(
      214.108 * sx,
      h - 1.544 * sy,
      214.057 * sx,
      h - 1.573 * sy,
      209.434 * sx,
      h - 6.923 * sy,
    )
    ..cubicTo(
      208.282 * sx,
      h - 8.256 * sy,
      204.853 * sx,
      h - 14.017 * sy,
      197.995 * sx,
      h - 25.538 * sy,
    )
    ..cubicTo(
      189.276 * sx,
      h - 40.186 * sy,
      173.284 * sx,
      h - 50 * sy,
      155 * sx,
      h - 50 * sy,
    )
    ..cubicTo(
      136.716 * sx,
      h - 50 * sy,
      120.724 * sx,
      h - 40.186 * sy,
      112.005 * sx,
      h - 25.538 * sy,
    )
    ..cubicTo(
      105.147 * sx,
      h - 14.017 * sy,
      101.718 * sx,
      h - 8.256 * sy,
      100.566 * sx,
      h - 6.923 * sy,
    )
    ..cubicTo(
      95.943 * sx,
      h - 1.573 * sy,
      95.892 * sx,
      h - 1.544 * sy,
      88.93 * sx,
      h - 0.308 * sy,
    )
    ..cubicTo(
      87.196 * sx,
      h,
      84.197 * sx,
      h,
      78.2 * sx,
      h,
    )
    ..lineTo(r, h)
    ..cubicTo(12, h, 0, h - 12, 0, h - r)
    ..lineTo(0, r)
    ..cubicTo(0, 12, 12, 0, r, 0)
    ..close();
}

class _MealPickerRow extends StatelessWidget {
  final EcoTheme t;
  final Meal meal;
  final int kcal;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddFood;

  const _MealPickerRow({
    required this.t,
    required this.meal,
    required this.kcal,
    required this.onOpenMeal,
    required this.onAddFood,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpenMeal(meal.key),
              child: Row(
                children: [
                  _MealPickerCalBadge(t: t, value: kcal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.meal(meal.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
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
              width: 46,
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 2,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.sub.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.add_rounded,
                    size: 40,
                    color: t.sub,
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
  final EcoTheme t;
  final int value;

  const _MealPickerCalBadge({required this.t, required this.value});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: 37,
      height: 37,
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0x2EFFFFFF) : const Color(0xDBD6D6D4),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: t.faint,
              height: 1,
            ),
          ),
          Text(
            l.unit('kcal'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: t.faint,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка «Параметры тела» — «минимал»: крупный вес, статус-пилюля и BMI.
class _BodyCard extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final String weightText;
  final _BodyStatus status;
  final double? bmi;
  final VoidCallback onTap;

  const _BodyCard({
    required this.t,
    required this.title,
    required this.weightText,
    required this.status,
    required this.bmi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoCard(
      t: t,
      bg: t.cardBody,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoCardHead(t: t, icon: 'body', title: title, mb: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  weightText,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    height: 1,
                  ),
                ),
              ),
              EcoPill(
                t: t,
                bg: t.pill,
                color: status.level.color,
                text: status.label,
                fontSize: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ],
          ),
          if (bmi != null) ...[
            const SizedBox(height: 6),
            Text(
              // Значение по локали (num1: «24,5» / «24.5»). Метка «BMI»
              // сохранена: ключа ИМТ в T4 не заведено (см. new_keys.md).
              'BMI ${l.num1(bmi!)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Карточка «Шаги»: крупное значение и дорожка из 10 следов вместо шкалы.
class _StepsCard extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final int steps;
  final int goal;
  final int pct;
  final VoidCallback onTap;

  const _StepsCard({
    required this.t,
    required this.title,
    required this.steps,
    required this.goal,
    required this.pct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Превышение цели — тёмно-зелёная пилюля, как в старой шкале шагов.
    final over = pct > 100;
    return EcoCard(
      t: t,
      bg: t.cardSteps,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoCardHead(
            t: t,
            icon: 'steps',
            title: title,
            mb: 12,
            right: EcoPill(
              t: t,
              bg: over ? EcoColors.stepAccentDeep : t.pill,
              color: over
                  ? t.onDark
                  : (t.isDark ? const Color(0xFF9ED1B4) : EcoColors.stepAccent),
              text: '$pct%',
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$steps',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                TextSpan(
                  text: ' / $goal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.sub,
                  ),
                ),
              ],
            ),
            style: const TextStyle(height: 1),
          ),
          const SizedBox(height: 10),
          _FootTrail(steps: steps, goal: goal, t: t),
        ],
      ),
    );
  }
}

/// Карточка «Вода»: значение + кнопка слева, большой стакан справа.
class _WaterCard extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final int water;
  final int goal;
  final String unitMl;
  final double pct;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _WaterCard({
    required this.t,
    required this.title,
    required this.water,
    required this.goal,
    required this.unitMl,
    required this.pct,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      t: t,
      bg: t.cardWater,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoCardHead(t: t, icon: 'water', title: title, mb: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$water',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                          TextSpan(
                            text: ' / $goal $unitMl',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.sub,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(height: 1),
                    ),
                    const SizedBox(height: 14),
                    // Row(min) даёт кнопке неограниченную ширину по контенту —
                    // иначе EcoBtn растягивается на всю колонку.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EcoBtn(
                          t: t,
                          height: 44,
                          fontSize: 16,
                          onTap: onAdd,
                          child: Text('+ 100 $unitMl'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              WaterGlass(pct: pct, t: t),
            ],
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

  String get labelKey => switch (this) {
        _BodyStatusLevel.low => 'bodyStatus.low',
        _BodyStatusLevel.average => 'bodyStatus.average',
        _BodyStatusLevel.high => 'bodyStatus.high',
      };
}

class _BodyStatus {
  final _BodyStatusLevel level;
  final String label;

  const _BodyStatus({required this.level, required this.label});

  /// BMI по весу/росту из стора; null, если данных нет.
  static double? bmiFor(AppStore store) {
    final weightKg = store.weight > 0 ? store.weight : store.weightKg;
    final heightCm = store.heightCm;
    if (weightKg == null || weightKg <= 0 || heightCm == null || heightCm <= 0) {
      return null;
    }
    return weightKg / math.pow(heightCm / 100, 2);
  }

  static _BodyStatus fromStore(AppStore store, AppStrings strings) {
    final bmi = bmiFor(store);
    final progress = _combineProgress(
      _progressForBodyFat(store.bodyFat, store.gender),
      bmi == null ? null : _progressForBmi(bmi),
    );
    final level = _levelForProgress(progress);

    return _BodyStatus(level: level, label: strings.t(level.labelKey));
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

/// Дорожка из 10 следов: пройденные — сплошные, текущий отрезок — светлее,
/// остальные — только контур. Следы чередуют левую/правую ногу, носком по
/// ходу движения (вправо).
class _FootTrail extends StatelessWidget {
  final int steps;
  final int goal;
  final EcoTheme t;

  const _FootTrail({required this.steps, required this.goal, required this.t});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: CustomPaint(
        painter: _FootTrailPainter(
          steps: steps,
          goal: goal,
          outline: t.isDark ? const Color(0xFF6F7F63) : const Color(0xFFA9BC8F),
        ),
      ),
    );
  }
}

class _FootTrailPainter extends CustomPainter {
  final int steps;
  final int goal;
  final Color outline;

  _FootTrailPainter({
    required this.steps,
    required this.goal,
    required this.outline,
  });

  // След (стопа + 5 пальцев) в координатах 24×38, носком вверх; поворот и
  // зеркалирование — трансформациями канвы.
  static final Path _foot = _buildFoot();

  static Path _buildFoot() {
    return Path()
      ..moveTo(12, 9.6)
      ..cubicTo(8, 9.6, 5.4, 12.4, 5.2, 16)
      ..cubicTo(5, 19, 6, 22, 6.6, 25)
      ..cubicTo(7.2, 28, 7.4, 31.5, 9, 34)
      ..cubicTo(10.4, 36.2, 14, 36.4, 15.6, 34.4)
      ..cubicTo(17, 32.6, 16.6, 30, 16.2, 27.6)
      ..cubicTo(15.8, 25.2, 14.4, 23.4, 14.6, 20.6)
      ..cubicTo(14.8, 18.4, 17.4, 16.6, 17.8, 14)
      ..cubicTo(18.2, 11.2, 15.6, 9.6, 12, 9.6)
      ..close()
      // Большой палец + четыре по убыванию.
      ..addOval(
        Rect.fromCenter(center: const Offset(17.8, 5), width: 6, height: 6.8),
      )
      ..addOval(Rect.fromCircle(center: const Offset(12.8, 3.6), radius: 2.1))
      ..addOval(Rect.fromCircle(center: const Offset(8.9, 4.2), radius: 1.8))
      ..addOval(Rect.fromCircle(center: const Offset(5.9, 5.6), radius: 1.5))
      ..addOval(Rect.fromCircle(center: const Offset(3.8, 7.5), radius: 1.2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const count = 10;
    final slotW = size.width / count;
    final seg = goal > 0 ? goal / count : 0.0;
    final over = goal > 0 && steps >= goal;
    final done =
        over ? count : (seg > 0 ? (steps / seg).floor().clamp(0, count) : 0);

    // След лежит горизонтально: длина 38 юнитов по X, высота 24 по Y.
    final s = math.min((slotW - 3) / 38, (size.height - 8) / 24);
    const off = 4.0; // чередование выше/ниже осевой линии

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = outline;

    for (var i = 0; i < count; i++) {
      final cx = slotW * (i + 0.5);
      final cy = size.height / 2 + (i.isEven ? -off : off);
      canvas.save();
      canvas.translate(cx, cy);
      if (i.isOdd) canvas.scale(1, -1); // левая/правая нога — зеркально
      canvas.rotate(math.pi / 2); // носком по ходу дорожки
      canvas.scale(s, s);
      canvas.translate(-12, -19);
      if (i < done) {
        fill.color = over ? EcoColors.stepAccentDeep : EcoColors.stepAccent;
        canvas.drawPath(_foot, fill);
      } else if (i == done && steps > seg * i) {
        // Текущая «десятая часть» цели — светлее сплошных.
        fill.color = const Color(0xFF7FA85C);
        canvas.drawPath(_foot, fill);
      } else {
        canvas.drawPath(_foot, stroke);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FootTrailPainter old) =>
      old.steps != steps || old.goal != goal || old.outline != outline;
}

/// Стакан воды (классика) — используется и на карточке главного экрана, и на
/// экране «Вода». Размер настраивается; [pct] — заполнение в процентах (0..100).
class WaterGlass extends StatelessWidget {
  final double pct;
  final EcoTheme t;
  final double width;
  final double height;

  const WaterGlass({
    super.key,
    required this.pct,
    required this.t,
    this.width = 64,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      // Плавный подъём уровня при «+250 мл».
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (pct / 100).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) =>
            CustomPaint(painter: _GlassPainter(v, t.isDark)),
      ),
    );
  }
}

/// Стакан «классика»: двойная стенка у кромки, волна с светлой поверхностью,
/// более тёмный слой воды у дна, пузырьки и блики на стекле.
class _GlassPainter extends CustomPainter {
  final double fill; // 0..1
  final bool isDark;

  _GlassPainter(this.fill, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final topY = h * 0.075, bottomY = h * 0.9;

    // Трапеция со скруглённым дном.
    final cup = Path()
      ..moveTo(w * 0.1667, topY)
      ..lineTo(w * 0.8333, topY)
      ..lineTo(w * 0.775, h * 0.775)
      ..cubicTo(w * 0.77, h * 0.85, w * 0.70, bottomY, w * 0.6083, bottomY)
      ..lineTo(w * 0.3917, bottomY)
      ..cubicTo(w * 0.30, bottomY, w * 0.23, h * 0.85, w * 0.225, h * 0.775)
      ..close();

    canvas.save();
    canvas.clipPath(cup);

    // Тело стакана.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark
            ? const Color(0x1AFFFFFF)
            : const Color(0x8CFFFFFF),
    );

    if (fill > 0) {
      final yw = bottomY - (bottomY - topY) * fill;
      const amp = 0.028; // амплитуда волны в долях высоты
      final a = h * amp;
      final segW = w / 4;

      // Волнистая поверхность + вода до дна.
      final water = Path()..moveTo(-segW / 2, yw);
      var up = true;
      for (var x = -segW / 2; x < w; x += segW) {
        water.quadraticBezierTo(
          x + segW / 2,
          yw + (up ? -a : a),
          x + segW,
          yw,
        );
        up = !up;
      }
      water
        ..lineTo(w, h)
        ..lineTo(-segW / 2, h)
        ..close();
      canvas.drawPath(water, Paint()..color = EcoColors.water);

      // Более тёмный слой у дна — глубина.
      canvas.drawRect(
        Rect.fromLTRB(0, yw + (bottomY - yw) * 0.52, w, h),
        Paint()..color = const Color(0xFF55B7EC).withValues(alpha: 0.85),
      );

      // Светлая кромка поверхности.
      final surface = Path()..moveTo(-segW / 2, yw);
      up = true;
      for (var x = -segW / 2; x < w; x += segW) {
        surface.quadraticBezierTo(
          x + segW / 2,
          yw + (up ? -a : a),
          x + segW,
          yw,
        );
        up = !up;
      }
      canvas.drawPath(
        surface,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB5E7FD),
      );

      // Пузырьки — только когда воды достаточно, чтобы им было где плавать.
      if (fill > 0.12) {
        final bubble = Paint()..color = const Color(0xFFCDEFFE);
        final depth = bottomY - yw;
        canvas.drawCircle(
            Offset(w * 0.40, yw + depth * 0.28), w * 0.030, bubble);
        canvas.drawCircle(
            Offset(w * 0.52, yw + depth * 0.44), w * 0.022, bubble);
        bubble.color = const Color(0xFFCDEFFE).withValues(alpha: 0.8);
        canvas.drawCircle(
            Offset(w * 0.45, yw + depth * 0.64), w * 0.017, bubble);
        canvas.drawCircle(
            Offset(w * 0.58, yw + depth * 0.20), w * 0.017, bubble);
      }
    }
    canvas.restore();

    // Внутренняя кромка — эффект двойной стенки.
    canvas.drawLine(
      Offset(w * 0.223, h * 0.131),
      Offset(w * 0.777, h * 0.131),
      Paint()
        ..strokeWidth = 1.5
        ..color =
            isDark ? const Color(0x3DFFFFFF) : const Color(0xFFC3D9F2),
    );

    // Блики на стекле.
    final gloss = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: isDark ? 0.35 : 0.75);
    canvas.drawLine(
      Offset(w * 0.2917, h * 0.1625),
      Offset(w * 0.3333, h * 0.55),
      gloss,
    );
    gloss
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);
    canvas.drawLine(
      Offset(w * 0.40, h * 0.1875),
      Offset(w * 0.425, h * 0.375),
      gloss,
    );

    // Контур стакана.
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color =
            isDark ? const Color(0xFF82ABE0) : const Color(0xFF6F9FD8),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill || old.isDark != isDark;
}
