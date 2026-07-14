import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        s.waterPortion,
      ),
    );
    final l = context.l10n;

    return EcoScreen(
      t: t,
      // Лого-шапка ЗАКРЕПЛЕНА сверху (как заголовок на остальных экранах):
      // карточки уезжают под неё и обрезаются со скруглением.
      header: Padding(
        padding: const EdgeInsets.only(left: 2, top: 18, bottom: 12),
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' health',
                    style: TextStyle(
                      color: t.olive,
                      fontWeight: FontWeight.w400,
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
          ],
        ),
      ),
      footer: MealPickerHost(
        t: t,
        active: 'home',
        onHome: () {},
        onProfile: () => Navigator.of(context).pushNamed('/profile'),
      ),
      child: Padding(
        // SafeArea + закреплённая лого-шапка сверху. Bottom clears the fixed nav
        // band (91 + 16 float + system inset) so the last card scrolls fully out.
        padding: EdgeInsets.only(
          bottom: 132 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiAdviceCard(t: t),

            // Еда
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.of(context).pushNamed('/dayview'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Шапка: брендовая эко-иконка «приборы» (SVG, олива, без белого
                  // бейджа) — консистентно с Body/Steps/Water. Макет FoodCard 55:22.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SvgPicture.asset('assets/icons/cutlery.svg',
                                height: 36,
                                colorFilter: ColorFilter.mode(
                                    t.iconOlive, BlendMode.srcIn)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l.t('home.food'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
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
                  CalorieTrack(
                      t: t,
                      value: s.consumed,
                      goal: s.goalKcal,
                      solidFill: true),
                ],
              ),
            ),

            // Параметры тела: вес в шапке + шкала статуса low/norm/high
            // (макет Figma 55:132). BMI-строка убрана по новому дизайну.
            _BodyCard(
              t: t,
              title: l.t('home.bodyParams'),
              // num1: «66»/«66,5» по локали, а не «66.0» с жёсткой точкой.
              weightText:
                  '${s.weight > 0 ? l.num1(s.weight) : '—'} ${l.unit('kg')}',
              status: _BodyStatus.fromStore(s, l),
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
              onTap: () => Navigator.of(context).pushNamed('/steps'),
            ),

            // Вода — прогресс показывает уровень в стакане, без процентов.
            _WaterCard(
              t: t,
              title: l.t('home.water'),
              water: s.water,
              goal: s.waterGoal,
              unitMl: l.unit('ml'),
              portion: s.waterPortion,
              onTap: () => Navigator.of(context).pushNamed('/water'),
              onAdd: () => context.read<AppStore>().addWater(s.waterPortion),
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
                            // RepaintBoundary СНЯТ намеренно: панель теперь стеклянная
                            // (BackdropFilter внутри), а RepaintBoundary изолировал бы
                            // слой и backdrop семплил бы пустоту вместо контента Home.
                            // Перф-цена: размытые painter'ы панели перерисовываются во
                            // время выезда (короткая анимация, на Impeller приемлемо).
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
              // Искажение фона (backdrop-blur σ8) сквозь панель — как у стеклянных
              // кнопок/навигации; поверх полупрозрачный тон (α~0.74/0.8), чтобы
              // строки оставались читаемыми. Backdrop корректно семплит контент
              // Home, т.к. панель живёт в footer-слое дерева экрана (не отдельный
              // маршрут) и RepaintBoundary над ней снят (иначе слой изолировал бы
              // backdrop). Прежняя проблема «чернел фон» была у showGeneralDialog.
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  // Фон панели по теме: светлый матовый / тёмный матовый.
                  color: t.isDark
                      ? const Color(0xCC1E2126)
                      : const Color(0xBCF6F8F5),
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
  final VoidCallback onTap;

  const _BodyCard({
    required this.t,
    required this.title,
    required this.weightText,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Раскладка синхронизирована из Figma (_BodyCard 53:52 / инстанс 55:132):
    // шапка одной строкой [фигура · заголовок · вес], ниже — шкала статуса.
    return EcoCard(
      t: t,
      bg: t.cardBody,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Кастомная фигура из макета (SVG-ассет, олива #555F3B) — без
              // белого кружка-бейджа. Бокс 40×40, фигура по центру.
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/body_figure.svg',
                    height: 40,
                    colorFilter:
                        ColorFilter.mode(t.iconOlive, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
              Text(
                weightText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: t.ink,
                  height: 1,
                ),
              ),
            ],
          ),
          // Зазор header→бар (Figma gap 30) уже заложен внутри _BodyScale:
          // его бокс = 30px сверху (там плавает пилюля) + бар 24. Отдельный
          // SizedBox тут не нужен — иначе отступ удваивается.
          _BodyScale(t: t, status: status),
        ],
      ),
    );
  }
}

/// Шкала статуса тела: 3 зоны (low/norm/high) с непрерывной заливкой по
/// [_BodyStatus.progress] и плавающей пилюлей у «головы» заливки. Макет 53:58.
class _BodyScale extends StatelessWidget {
  final EcoTheme t;
  final _BodyStatus status;

  const _BodyScale({required this.t, required this.status});

  @override
  Widget build(BuildContext context) {
    const gap = 5.0;
    const zoneH = 16.0; // шкала 16px по макету (компактная карточка 116)
    const third = 1 / 3;
    final p = status.progress.clamp(0.0, 1.0);

    // Доля залитой части зоны i (0=low, 1=norm, 2=high).
    double frac(int i) => ((p - i * third) / third).clamp(0.0, 1.0);
    Color zoneColor(int i) => _BodyStatusLevel.values[i].color;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final zoneW = (w - 2 * gap) / 3;
        // Активная зона и X «головы» заливки — для позиции пилюли.
        final active = p >= 2 * third ? 2 : (p >= third ? 1 : 0);
        final headX = active * (zoneW + gap) + zoneW * frac(active);

        Widget zone(int i) => Expanded(
              child: SizedBox(
                height: zoneH,
                child: Stack(
                  children: [
                    // Трек зоны — тинт 30%.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: zoneColor(i).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Inset-тень (утопленный жёлоб) на треке — глубина по макету
                    // 55:132 (inset 0 4 4 rgba(0,0,0,.25)). ПОД заливкой → видна
                    // только на незалитом остатке зоны. Тот же настоящий
                    // inner-shadow, что у полос и грувов колец.
                    const Positioned.fill(child: EcoInsetShadow()),
                    // Сплошная заливка слева до текущего значения зоны.
                    if (frac(i) > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: zoneW * frac(i),
                          height: zoneH,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: zoneColor(i),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );

        return SizedBox(
          // 36 = ~20px сверху под плавающую пилюлю + бар 16. Итог карточки:
          // pad20 + header40 + 36 + pad20 = 116 (как в макете 55:132).
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: zoneH,
                child: Row(
                  children: [
                    zone(0),
                    const SizedBox(width: gap),
                    zone(1),
                    const SizedBox(width: gap),
                    zone(2),
                  ],
                ),
              ),
              // Пилюля статуса — по центру «головы» заливки, над баром.
              // На краях (очень низкий/высокий статус) прижимаем внутрь, чтобы
              // пилюля не вылезала за карточку.
              Positioned(
                top: 0,
                left: w >= 60 ? headX.clamp(30.0, w - 30.0).toDouble() : w / 2,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: EcoPill(
                    t: t,
                    bg: status.level.color,
                    color: t.ink,
                    text: status.label,
                    fontSize: 10,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Карточка «Шаги»: крупное значение и дорожка из 10 следов вместо шкалы.
class _StepsCard extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final int steps;
  final int goal;
  final VoidCallback onTap;

  const _StepsCard({
    required this.t,
    required this.title,
    required this.steps,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Раскладка из Figma (55:145): шапка [иконка · «Шаги» · число «6432/10000»
    // справа], ниже — дорожка следов. Пилюля «%» и отдельная строка убраны.
    return EcoCard(
      t: t,
      bg: t.cardSteps,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Брендовая эко-иконка «шаги» (SVG, олива), без белого бейджа.
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgPicture.asset('assets/icons/steps.svg',
                      height: 40,
                      colorFilter:
                          ColorFilter.mode(t.iconOlive, BlendMode.srcIn)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$steps',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: t.ink,
                      ),
                    ),
                    TextSpan(
                      text: ' / $goal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.sub,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(height: 1),
              ),
            ],
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
  // Текущая порция (мл) с экрана «Вода» — кнопка «+» на карточке подтягивает её.
  final int portion;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _WaterCard({
    required this.t,
    required this.title,
    required this.water,
    required this.goal,
    required this.unitMl,
    required this.portion,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // Та же логика «переполнения», что на экране воды: каждая полностью выпитая
    // норма — отдельный маленький полный стакан рядом с большим; большой стакан
    // показывает прогресс к следующей норме.
    final over = (goal > 0 && water > goal) ? (water - 1) ~/ goal : 0;
    final shown = over > 3 ? 3 : over;
    final bigFill =
        goal > 0 ? ((water - over * goal) / goal).clamp(0.0, 1.0) : 0.0;
    // Счётчик «1200 / 2000 мл»: фиксированный размер (число 22 Bold, единицы 14
    // sub), одна строка, число и единицы по общей базовой линии; без
    // масштабирования системным шрифтом — размер и высота постоянны.
    final counter = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$water',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          TextSpan(
            text: ' / $goal $unitMl',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.sub,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(height: 1),
    );
    return EcoCard(
      t: t,
      bg: t.cardWater,
      margin: const EdgeInsets.only(bottom: 12),
      // Паддинг карточки из макета Figma (_WaterCard 140:547): px-16 / py-20.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      onTap: onTap,
      // Раскладка из Figma «_WaterCard» (140:547): ряд по центру из двух колонок
      // ФИКСИРОВАННОЙ высоты (шапка 40 + gap 16 + нижний ряд 36 = 92) и большого
      // стакана справа. За счёт фиксированных высот рядов переполнение не меняет
      // высоту карточки и не сдвигает счётчик — ничего не «дёргается».
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Левая колонка (макет w133): шапка [капля + «Вода»] и кнопка.
          SizedBox(
            width: 133,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка (h40, gap 12, по центру): эко-капля + заголовок.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SvgPicture.asset('assets/icons/water_drop.svg',
                            height: 40,
                            colorFilter: ColorFilter.mode(
                                t.iconOlive, BlendMode.srcIn)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Нижний ряд: кнопка добавления порции (h36).
                EcoGlassButton(
                  height: 36,
                  onTap: onAdd,
                  child: Text(
                    '+ $portion $unitMl',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Средняя колонка (макет w133; здесь Expanded для адаптивности).
          // ЕСТЬ переполнение — счётчик вверху (ряд h40) + маленькие стаканы в
          // нижнем ряду h36 (макет 140:547). НЕТ стаканов — счётчик по вертикали
          // ПО ЦЕНТРУ карточки (макет-вариант 298:1951). Высота карточки одна и
          // та же (её держит большой стакан), поэтому переключение аккуратное.
          Expanded(
            child: shown > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Счётчик вверху, влево, вертикальный центр в ряду h40.
                      SizedBox(
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: counter,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Нижний ряд (h36): маленькие полные стаканы за каждую
                      // выпитую норму — по правому краю и по низу, шаг 7 (макет).
                      SizedBox(
                        height: 36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < shown; i++)
                              Padding(
                                padding: EdgeInsets.only(left: i > 0 ? 7 : 0),
                                child: WaterGlass(
                                    fill: 1.0, t: t, width: 26, height: 36),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                // Без стаканов — счётчик по центру по вертикали (влево по
                // горизонтали), как во втором варианте макета.
                : Align(
                    alignment: Alignment.centerLeft,
                    child: counter,
                  ),
          ),
          const SizedBox(width: 4),
          // ── Большой стакан справа. Бокс = реальной ширине рисунка при высоте
          // 92 (пропорция ассета ≈0.71, т.е. 65×92): так стакан не резервирует
          // лишнюю ширину и счётчик «6000 / 2400 мл» помещается без обрезки.
          WaterGlass(fill: bigFill, t: t, width: 65, height: 92),
        ],
      ),
    );
  }
}

enum _BodyStatusLevel {
  low,
  average,
  high;

  // Палитра шкалы «Параметры тела» из макета (55:132): low=жёлтый,
  // norm=prot-зелёный, high=fat-красный. Общая для зон и для пилюли статуса.
  Color get color => switch (this) {
        _BodyStatusLevel.low => const Color(0xFFFFCC00),
        _BodyStatusLevel.average => EcoColors.prot,
        _BodyStatusLevel.high => EcoColors.fat,
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

  /// Непрерывная позиция [0..1] на шкале low/norm/high (среднее BMI и % жира).
  final double progress;

  const _BodyStatus({
    required this.level,
    required this.label,
    required this.progress,
  });

  /// BMI по весу/росту из стора; null, если данных нет.
  static double? bmiFor(AppStore store) {
    final weightKg = store.weight > 0 ? store.weight : store.weightKg;
    final heightCm = store.heightCm;
    if (weightKg == null ||
        weightKg <= 0 ||
        heightCm == null ||
        heightCm <= 0) {
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

/// Стакан воды с растущим внутри растением (Figma «Water Fill Icon» 141:72).
///
/// Три слоя в системе координат макета (viewBox 70.9×100):
///   1. `glass_plant.svg` — растение, плавно увеличивается в размере по мере
///      наполнения (Transform.scale с якорем у основания стебля); растёт чуть
///      быстрее воды, чтобы верхушка выглядывала над поверхностью.
///   2. [_WaterPainter] — параметрическая полупрозрачная вода: волнистая
///      анимированная поверхность, слой глубины, пузыри (цвета из макета).
///      Растение просвечивает сквозь воду.
///   3. `glass_cup.svg` — оливковый контур-стакан, сверху, статичный.
///
/// Уровень поднимается плавно ([TweenAnimationBuilder]) при изменении доли
/// (напр. «+250 мл»); поверхность непрерывно колышется ([_wave]).
class WaterGlass extends StatefulWidget {
  final double fill; // 0..1 — доля выпитого от цели
  final EcoTheme t;

  /// Размер стакана. По умолчанию 71×100 (карточка «Вода» на главной);
  /// экран воды передаёт крупнее с той же пропорцией.
  final double width;
  final double height;

  const WaterGlass({
    super.key,
    required this.fill,
    required this.t,
    this.width = 71,
    this.height = 100,
  });

  @override
  State<WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<WaterGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.fill.clamp(0.0, 1.0);
    return SizedBox(
      // Пропорции viewBox макета 70.9×100.
      width: widget.width,
      height: widget.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, level, __) {
          // Растение растёт в РАЗМЕРЕ вместе с уровнем (не просто раскрывается):
          // масштаб от маленького ростка к полному, якорь — у основания стебля,
          // поэтому стебель тянется вверх со дна. Растёт чуть быстрее воды
          // (pow<1), чтобы верхушка выглядывала над поверхностью.
          final plant = math.pow(level, 0.7).toDouble();
          return Stack(
            children: [
              // Растение — позади воды, плавно увеличивается со дна.
              Positioned.fill(
                child: Transform.scale(
                  scale: _lerp(0.34, 1.0, plant),
                  alignment: const Alignment(-0.05, 0.92),
                  child: SvgPicture.asset('assets/icons/glass_plant.svg',
                      fit: BoxFit.contain),
                ),
              ),
              // Вода поверх растения; репейнт волны — через repaint:_wave,
              // поддерево SVG при этом не пересобирается.
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaterPainter(level: level, wave: _wave),
                ),
              ),
              // Контур-стакан сверху.
              Positioned.fill(
                child: SvgPicture.asset('assets/icons/glass_cup.svg',
                    fit: BoxFit.contain),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Вода в стакане: клип по интерьеру-трапеции, заливка снизу до уровня,
/// волнистая анимированная поверхность, слой глубины у дна, пузыри.
/// Цвета — из макета (Group 1): тело #6BD2FB, глубина #55B7EC, кромка #B5E7FD,
/// пузыри #CDEFFE. Вся группа полупрозрачна (в макете opacity 0.5) — сквозь
/// воду виден стебель.
class _WaterPainter extends CustomPainter {
  final double level; // 0..1
  final Animation<double> wave;

  _WaterPainter({required this.level, required this.wave})
      : super(repaint: wave);

  static const _water = Color(0xFF6BD2FB);
  static const _depth = Color(0xFF55B7EC);
  static const _foam = Color(0xFFB5E7FD);
  static const _bubble = Color(0xFFCDEFFE);

  // Интерьер стакана (доли w/h), слегка внутри оливкового контура — вода
  // прячется под 3px обводкой. Профиль снят из Figma-геометрии воды.
  Path _interior(double w, double h) => Path()
    ..moveTo(w * 0.045, h * 0.085)
    ..lineTo(w * 0.955, h * 0.085)
    ..lineTo(w * 0.885, h * 0.895)
    ..quadraticBezierTo(w * 0.875, h * 0.985, w * 0.78, h * 0.985)
    ..lineTo(w * 0.235, h * 0.985)
    ..quadraticBezierTo(w * 0.125, h * 0.985, w * 0.115, h * 0.895)
    ..close();

  // Волнистая линия поверхности на высоте [y]: сумма двух синусоид со сдвигом.
  Path _surface(double w, double y, double amp, double ph) {
    final p = Path()..moveTo(0, y);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final f = x / w * 2 * math.pi;
      final dy = math.sin(ph + f * 1.6) * amp +
          math.sin(ph * 1.7 + f * 3.1) * amp * 0.35;
      p.lineTo(x, y + dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0.001) return;
    final w = size.width, h = size.height;

    canvas.save();
    canvas.clipPath(_interior(w, h));

    // Уровень: 0 → тонкая лужица у дна, 1 → y≈0.12h (почти полный стакан,
    // небольшой запас под ободком для гребня волны).
    final surfaceY = _lerp(0.93, 0.12, level) * h;
    final amp = h * 0.02;
    final ph = wave.value * 2 * math.pi;

    // Полупрозрачная группа воды — стебель просвечивает.
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Colors.white.withValues(alpha: 0.62),
    );

    // Тело воды: волна сверху, вниз до дна.
    final body = _surface(w, surfaceY, amp, ph)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(body, Paint()..color = _water);

    // Слой глубины у дна.
    final depthTop = surfaceY + (h - surfaceY) * 0.5;
    canvas.drawRect(
      Rect.fromLTRB(0, depthTop, w, h),
      Paint()..color = _depth.withValues(alpha: 0.85),
    );

    // Пузыри (лёгкое покачивание по фазе), когда воды достаточно.
    final depth = h - surfaceY;
    if (depth > h * 0.10) {
      void bubble(double bx, double by, double r, double a) {
        final yy = surfaceY + depth * by - math.sin(ph + bx * 6) * 1.2;
        canvas.drawCircle(Offset(w * bx, yy), r,
            Paint()..color = _bubble.withValues(alpha: a));
      }

      bubble(0.42, 0.30, w * 0.030, 1);
      bubble(0.62, 0.46, w * 0.022, 1);
      bubble(0.50, 0.66, w * 0.016, 0.8);
      bubble(0.68, 0.24, w * 0.016, 0.8);
    }

    // Светлая кромка поверхности.
    canvas.drawPath(
      _surface(w, surfaceY, amp, ph),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _foam,
    );

    canvas.restore(); // saveLayer
    canvas.restore(); // clip
  }

  @override
  bool shouldRepaint(_WaterPainter old) => old.level != level;
}
