import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';

const _enableAmbientMotion = bool.fromEnvironment('ECO_ENABLE_AMBIENT_MOTION');

/// Единый переход открытия/закрытия экрана: БЕЗ анимации (мгновенно, как
/// переключение вкладок). Переходы МЕЖДУ экранами приложения не анимируются;
/// анимации появления панелей/меню/листов (showEcoSheet, popup-меню, панель
/// приёма пищи) — отдельные и СОХРАНЕНЫ. Используется ВЕЗДЕ вместо
/// MaterialPageRoute, чтобы все переходы были идентичными.
class EcoPageRoute<T> extends PageRouteBuilder<T> {
  EcoPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}

/// Маршрут БЕЗ анимации перехода (мгновенно). Только для пары главная ↔ профиль:
/// она ведёт себя как переключение вкладок, а не как открытие нового экрана.
class EcoInstantRoute<T> extends PageRouteBuilder<T> {
  EcoInstantRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}

/// Icon name → Material icon mapping (Phase 1; the bespoke Eco icon set from
/// icons.jsx can replace this later without touching call sites).
IconData ecoIcon(String name) {
  switch (name) {
    case 'ai':
      return Icons.auto_awesome;
    case 'bulb':
      return Icons.lightbulb_outline;
    case 'food':
      return Icons.restaurant;
    case 'gauge':
      return Icons.speed;
    case 'steps':
      return Icons.directions_walk;
    case 'walk':
      return Icons.directions_walk;
    case 'bed':
      return Icons.bedtime_outlined;
    case 'seat':
      return Icons.event_seat_outlined;
    case 'fitness':
      return Icons.fitness_center;
    case 'trendDown':
      return Icons.trending_down;
    case 'trendUp':
      return Icons.trending_up;
    case 'balance':
      return Icons.balance_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    case 'pulse':
      return Icons.monitor_heart_outlined;
    case 'plus':
      return Icons.add_rounded;
    case 'close':
      return Icons.close_rounded;
    case 'home':
      return Icons.home_outlined;
    case 'homeFill':
      return Icons.home_rounded;
    case 'user':
      return Icons.person_outline_rounded;
    case 'userFill':
      return Icons.person_rounded;
    case 'chevL':
      return Icons.chevron_left;
    case 'chevR':
      return Icons.chevron_right;
    case 'thumbUp':
      return Icons.thumb_up_outlined;
    case 'thumbDn':
      return Icons.thumb_down_outlined;
    case 'search':
      return Icons.search;
    case 'scan':
      return Icons.qr_code_scanner;
    case 'stats':
      return Icons.bar_chart;
    case 'scale':
      return Icons.monitor_weight_outlined;
    case 'flame':
      return Icons.local_fire_department_outlined;
    case 'chart':
      return Icons.show_chart;
    case 'edit':
      return Icons.edit_outlined;
    case 'minus':
      return Icons.remove;
    case 'drop':
      return Icons.water_drop_outlined;
    case 'cutlery':
      return Icons.restaurant_menu;
    case 'settings':
      return Icons.settings_outlined;
    case 'body':
      return Icons.accessibility_new;
    case 'male':
      return Icons.male;
    case 'female':
      return Icons.female;
    default:
      return Icons.circle_outlined;
  }
}

class EcoGlassBackground extends StatefulWidget {
  final EcoTheme t;

  const EcoGlassBackground({super.key, required this.t});

  @override
  State<EcoGlassBackground> createState() => _EcoGlassBackgroundState();
}

class _EcoGlassBackgroundState extends State<EcoGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    );
    if (_enableAmbientMotion) _motion.repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.t.bgTop, widget.t.bgBottom],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = math.max(box.maxWidth / 402, box.maxHeight / 874);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final p = _motion.value * math.pi * 2;
                    return Stack(
                      children: [
                        _BgBlob(
                          color: const Color(0x664B99FF),
                          width: 360 * scale,
                          height: 360 * scale,
                          top: (-70 + math.sin(p) * 18) * scale,
                          left: (-90 + math.cos(p * .8) * 18) * scale,
                        ),
                        _BgBlob(
                          color: const Color(0x52D97332),
                          width: 320 * scale,
                          height: 320 * scale,
                          top: (180 + math.sin(p * .7 + 1.2) * 22) * scale,
                          left: (200 + math.cos(p * .9) * 20) * scale,
                        ),
                        _BgBlob(
                          color: const Color(0x4D32D94B),
                          width: 300 * scale,
                          height: 300 * scale,
                          top: (470 + math.sin(p * .82 + 2.1) * 20) * scale,
                          left: (-60 + math.cos(p * .7 + .6) * 22) * scale,
                        ),
                        _BgBlob(
                          color: const Color(0x523D806A),
                          width: 340 * scale,
                          height: 340 * scale,
                          top: (620 + math.sin(p * .63 + 2.6) * 26) * scale,
                          left: (180 + math.cos(p * .66 + 1.8) * 24) * scale,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BgBlob extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final double top;
  final double left;

  const _BgBlob({
    required this.color,
    required this.width,
    required this.height,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      // Блобы статичны (амбиентная анимация выключена). Раньше — сплошной круг
      // + ImageFilter.blur(σ64): Impeller перекодирует этот offscreen-блюр КАЖДЫЙ
      // кадр (главная остаточная стоимость растера). Радиальный градиент даёт тот
      // же мягкий ореол практически бесплатно, без offscreen-прохода.
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Screen scaffold: bg, scrollable padded content, pinned footer.
class EcoScreen extends StatelessWidget {
  final EcoTheme t;
  final Widget child;

  /// Закреплённая шапка (обычно [EcoTopBar]): рисуется НАД областью прокрутки и
  /// сама не скроллится. Контент [child] уезжает под неё и обрезается по верхней
  /// кромке области прокрутки — форма карточек при этом не меняется (обычный
  /// клип вьюпорта, без «схлопывания»/затухания). Если null — старое поведение,
  /// когда скроллится весь [child].
  final Widget? header;
  final Widget? footer;
  final bool pad;

  /// Опциональный контроллер прокрутки. Нужен экранам, которым требуется
  /// программно управлять скроллом (например, авто-прокрутка к низу при
  /// «потоковой» генерации ИИ-совета).
  final ScrollController? controller;

  const EcoScreen({
    super.key,
    required this.t,
    required this.child,
    this.header,
    this.footer,
    this.pad = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Scaffold gives Texts a Material ancestor (otherwise Flutter renders the
    // yellow-underline debug style) and SafeArea keeps content off the status
    // bar. The footer stays outside SafeArea so the nav band hugs the bottom.
    return Scaffold(
      // Прозрачный фон: EcoGlassBackground ниже заливает весь экран непрозрачным
      // градиентом, поэтому заливка Scaffold была лишним полноэкранным overdraw
      // на каждый кадр на КАЖДОМ экране.
      backgroundColor: Colors.transparent,
      // BackdropGroup убран: он влияет только на BackdropFilter.grouped, а таких
      // в приложении нет — обёртка была no-op. Единственный живой BackdropFilter
      // (окна ввода в EcoGlassSurface) живёт в отдельных модальных маршрутах, вне
      // этого поддерева, поэтому группировать нечего. Такие же no-op обёртки пока
      // остаются в addfood/onboarding/profile — их файлы не в этой задаче.
      body: Stack(
        children: [
          Positioned.fill(child: EcoGlassBackground(t: t)),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Закреплённая шапка — вне прокрутки, всегда сверху.
                  if (header != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad ? 16 : 0),
                      child: header!,
                    ),
                  // Прокручиваемый контент уезжает под закреплённую шапку.
                  // Вьюпорт ПОЛНОШИРИННЫЙ (паддинг 16 внутри), поэтому full-bleed
                  // контент (ленты дней, графики) доходит до краёв экрана. Клип
                  // [_CardTopRoundClipper] скругляет верхнюю кромку ТОЛЬКО на
                  // ширине карточек (inset 16), а боковые «вылеты» обрезает ПРЯМО.
                  Expanded(
                    child: header == null
                        ? SingleChildScrollView(
                            controller: controller,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: pad ? 16 : 0),
                              child: child,
                            ),
                          )
                        // Клип по ширине контента со скруглёнными верхними углами
                        // (макет Subtract 298:2306): карточки под шапкой обрезаются
                        // с плавным скруглением, по бокам — ровный срез.
                        : Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: pad ? 16 : 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(t.r),
                              ),
                              child: SingleChildScrollView(
                                controller: controller,
                                child: child,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Large title bar with optional back chevron.
class EcoTopBar extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final VoidCallback? onBack;
  final Widget? right;

  const EcoTopBar({
    super.key,
    required this.t,
    required this.title,
    this.onBack,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Padding(
      // bottom: 0 — визуальный отступ до контента (~16) даёт само центрирование
      // заголовка (24) в ряду высотой 48 (тач-таргет шеврона). Иначе суммарный
      // зазор был бы слишком большим.
      padding: EdgeInsets.only(top: topInset + 18, bottom: 0),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              // Тач-таргет 48×48 (доступный минимум): иконка остаётся 30, вокруг
              // неё 9px паддинга. opaque — чтобы тап по прозрачному паддингу тоже
              // срабатывал, а не проваливался к тому, что под ним.
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(Icons.chevron_left, size: 30, color: t.ink),
              ),
            )
          else
            // Корневой экран (без «назад») — резерв: ширина 20 (заголовок на 36 px
            // от края, вровень с текстом карточек) + ВЫСОТА 48, как у шеврона,
            // чтобы Row был той же высоты и заголовок центрировался по вертикали
            // так же, как на экранах со стрелкой (одинаковый отступ сверху).
            const SizedBox(width: 20, height: 48),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}

/// Card surface.
class EcoGlassSurface extends StatelessWidget {
  final EcoTheme t;
  final Widget child;
  final Color? bg;
  final EdgeInsetsGeometry padding;
  final EdgeInsets? margin;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? shadows;
  final double? blur;
  final double? width;
  final double? height;

  /// Окна ввода/модальные пикеры: фон берётся из [bg] как есть (непрозрачный)
  /// и НЕ зависит от ползунка прозрачности карточек — чтобы оставались читаемыми.
  final bool solid;

  const EcoGlassSurface({
    super.key,
    required this.t,
    required this.child,
    this.bg,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
    this.shadows,
    this.blur,
    this.width,
    this.height,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(t.r);
    // Прозрачность ОБЫЧНЫХ карточек регулируется ползунком (AppStore.cardOpacity).
    // solid=true (модальные окна ввода) используют свой bg как есть, без слайдера,
    // чтобы пикеры оставались непрозрачными и читаемыми.
    final Color fill;
    if (solid) {
      // Окна ввода (модальные пикеры): матовое стекло, зависящее от темы —
      // светлое в светлой теме, ТЁМНОЕ в тёмной. Явный bg уважается.
      fill =
          bg ?? (t.isDark ? const Color(0xE61E2126) : const Color(0x8CFFFFFF));
    } else {
      final opacity = context.select<AppStore, double>((s) => s.cardOpacity);
      fill = (bg ?? t.card).withValues(alpha: opacity);
    }
    final r = radius;
    final rimRadius = r is BorderRadius ? r.topLeft.x : t.r;
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: t.glassBorder),
      ),
      child: child,
    );
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows ??
              const [
                // Белый liquid-glass хайлайт по верхне-левой кромке — ЕДИНСТВЕННЫЙ
                // эффект карточки по макету (EcoCard 44:14: drop-shadow -2 -2 blur9
                // white α0.2). Глубина «утопленности» — не у карточек, а у ВНУТРЕННИХ
                // элементов (кольца/полосы) через inner-shadow.
                BoxShadow(
                  color: Color(0x33FFFFFF),
                  blurRadius: 9,
                  offset: Offset(-2, -2),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          // Окна ввода/модалки: размытие фона (frosted) — позади мягкая дымка,
          // чтобы фон не мешал содержимому. Включается для solid ИЛИ когда явно
          // задан [blur] (полупрозрачные пикер-окна). solid дополнительно рисует
          // liquid-glass блики по краям. ВНИМАНИЕ: внутри этих окон крутятся
          // барабаны пикеров, поэтому σ держим низким (showEcoSheet передаёт σ15)
          // — живой BackdropFilter пересчитывается на каждый кадр их прокрутки.
          child: (solid || blur != null)
              ? BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blur ?? 40,
                    sigmaY: blur ?? 40,
                  ),
                  child: solid
                      ? Stack(
                          children: [
                            inner,
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _RoundedGlassChromePainter(
                                    radius: rimRadius,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : inner,
                )
              : inner,
        ),
      ),
    );
  }
}

class EcoCard extends StatelessWidget {
  final EcoTheme t;
  final Widget child;
  final VoidCallback? onTap;
  final Color? bg;
  final double pad;

  /// Явный паддинг карточки; если не задан — симметричный [pad] со всех сторон.
  /// Нужен, когда макет требует разные отступы по осям (напр. водная карточка
  /// из Figma: px-16 / py-20).
  final EdgeInsetsGeometry? padding;
  final EdgeInsets? margin;

  /// true для карточек ввода: непрозрачный фон, не зависит от ползунка.
  final bool solid;

  /// Размытие фона (frosted) под карточкой — для полупрозрачных окон ввода,
  /// чтобы фон не мешал. null = без размытия.
  final double? blur;

  const EcoCard({
    super.key,
    required this.t,
    required this.child,
    this.onTap,
    this.bg,
    this.pad = 20,
    this.padding,
    this.margin,
    this.solid = false,
    this.blur,
  });

  @override
  Widget build(BuildContext context) {
    final card = EcoGlassSurface(
      t: t,
      margin: margin,
      padding: padding ?? EdgeInsets.all(pad),
      bg: bg,
      solid: solid,
      blur: blur,
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// Round icon badge used in card headers.
class EcoIconBadge extends StatelessWidget {
  final EcoTheme t;
  final String? name;
  final IconData? iconData;
  final double size;
  final double icon;

  const EcoIconBadge({
    super.key,
    required this.t,
    this.name,
    this.iconData,
    this.size = 40,
    this.icon = 22,
  });

  @override
  Widget build(BuildContext context) {
    // Максимально простая подложка иконки: плоский круг цвета темы. Без тени,
    // градиента, каймы и ClipOval — никаких лишних эффектов (и дешевле в отрисовке).
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.pill,
      ),
      child: Icon(
        iconData ?? ecoIcon(name ?? ''),
        size: icon,
        color: t.ink,
      ),
    );
  }
}

/// Card header: badge + title + optional right widget.
class EcoCardHead extends StatelessWidget {
  final EcoTheme t;
  final String icon;
  final String title;
  final Widget? right;
  final double mb;
  final FontWeight titleWeight;

  const EcoCardHead({
    super.key,
    required this.t,
    required this.icon,
    required this.title,
    this.right,
    this.mb = 16,
    this.titleWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: mb),
      child: Row(
        children: [
          EcoIconBadge(t: t, name: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: titleWeight,
                letterSpacing: 0,
              ),
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}

/// Dark-green pill button (the single button style of the design).
class EcoBtn extends StatelessWidget {
  final EcoTheme t;
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final EdgeInsets padding;
  final bool disabled;
  final Color? bg;
  final Color? fg;
  final bool outlined;

  /// Восстанавливает искажение фона (backdrop-blur) под кнопкой — для нижних
  /// кнопок-действий листов, стоящих поверх прокручиваемого контента.
  final bool frosted;

  const EcoBtn({
    super.key,
    required this.t,
    required this.child,
    this.onTap,
    this.height = 56,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.disabled = false,
    this.bg,
    this.fg,
    this.outlined = false,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    // ЕДИНЫЙ СТИЛЬ (макет Button 217:85): все кнопки приложения — светлое стекло
    // с press-эффектом и искажением фона (делегируем в [EcoGlassButton]). Прежние
    // bg/fg/outlined больше НЕ влияют на вид (оставлены для совместимости вызовов).
    // Активная — текст ink (тёмный); disabled → ПАССИВНАЯ кнопка (макет 213:2147):
    // то же стекло, текст faint (серый), без press-реакции.
    return EcoGlassButton(
      height: height,
      radius: 999,
      padding: padding,
      passive: disabled,
      frosted: frosted,
      onTap: disabled ? null : onTap,
      child: DefaultTextStyle(
        style: TextStyle(
          color: disabled ? t.faint : t.ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        child: child,
      ),
    );
  }
}

/// Единый тумблер настроек — 1-в-1 по компоненту Toggle 178:59 (02 Atoms).
/// Трек 56×32, белая обводка 1, внешняя drop-тень `2/2/2 α25` + УТОПЛЁННЫЙ жёлоб
/// (inset-тень `2/2/2 α25`, [_ToggleGroovePainter]); бегунок — [EcoGlassChip]
/// (inset-белый хайлайт + своя тень). ON → светлый трек + петрол thumb 28 СПРАВА;
/// OFF → петрол трек + белый thumb 24 СЛЕВА (thumb МЕНЯЕТ размер). Иконка на
/// бегунке (20px) тинтится в контраст: [iconOff]=солнце, [iconOn]=луна. Без
/// иконок — обычный тумблер вкл/выкл (профиль, экран согласия).
class EcoSettingToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  final String? iconOn;
  final String? iconOff;

  const EcoSettingToggle({
    super.key,
    required this.on,
    required this.onChanged,
    this.iconOn,
    this.iconOff,
  });

  @override
  Widget build(BuildContext context) {
    const petrol = Color(0xFF045157);
    // Обычные тумблеры (без иконок: уведомления, экран согласия) следуют макету
    // Toggle 178:59: ON → светлый трек + петрол thumb 28 СПРАВА; OFF → петрол трек
    // + белый thumb 24 СЛЕВА. Тумблер ТЕМЫ (с иконками солнце/луна) исторически
    // имеет ЗЕРКАЛЬНУЮ раскладку — оставляем как было (visual = !on).
    final hasIcon = iconOn != null || iconOff != null;
    final visual = hasIcon ? !on : on;
    final trackColor = visual ? Colors.white.withValues(alpha: 0.34) : petrol;
    final thumbColor = visual ? petrol : Colors.white;
    final iconColor = visual ? Colors.white : petrol;
    final iconAsset = on ? iconOn : iconOff;
    final thumbSize = visual ? 28.0 : 24.0;
    // Равный отступ бегунка с 3 сторон: gap = (32 − size) / 2.
    final gap = (32 - thumbSize) / 2;
    final thumbLeft = visual ? 56 - gap - thumbSize : gap;
    const dur = Duration(milliseconds: 120);
    return GestureDetector(
      onTap: () => onChanged(!on),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Трек: заливка + белая обводка + внешняя drop-тень (2/2/2 α25).
            Positioned.fill(
              child: AnimatedContainer(
                duration: dur,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 2,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Утоплённый жёлоб трека (inset 2/2/2 α25) — глубина как в макете.
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ToggleGroovePainter()),
              ),
            ),
            // Бегунок: равный отступ с 3 сторон, плавный слайд + ресайз.
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOut,
              top: gap,
              left: thumbLeft,
              width: thumbSize,
              height: thumbSize,
              child: EcoGlassChip(
                width: thumbSize,
                height: thumbSize,
                radius: thumbSize / 2,
                color: thumbColor,
                child: iconAsset == null
                    ? const SizedBox.shrink()
                    : SvgPicture.asset(
                        iconAsset,
                        width: 20,
                        height: 20,
                        colorFilter:
                            ColorFilter.mode(iconColor, BlendMode.srcIn),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Утоплённый жёлоб трека тумблера: inner-shadow `inset 2 2 blur2 black α25`
/// (макет toggle track). Заливаем цветом тени и вырезаем (dstOut) смещённую
/// вниз-вправо размытую копию → мягкая тёмная полоса у верхне-левой кромки.
class _ToggleGroovePainter extends CustomPainter {
  const _ToggleGroovePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(rr, Paint()..color = const Color(0x40000000));
    canvas.drawRRect(
      rr.shift(const Offset(2, 2)),
      Paint()
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.15),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToggleGroovePainter old) => false;
}

/// Small accent pill (badge / chip).
class EcoPill extends StatelessWidget {
  final EcoTheme t;
  final String text;
  final Color? bg;
  final Color? color;
  final double fontSize;
  final EdgeInsets padding;

  const EcoPill({
    super.key,
    required this.t,
    required this.text,
    this.bg,
    this.color,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg ?? t.pill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          // По умолчанию текст адаптивный: тёмный в светлой теме, светлый в
          // тёмной (на тёмной пилюле надпись остаётся читаемой).
          color: color ?? t.ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// Square calorie badge "527 / кал".
class CalBadge extends StatelessWidget {
  final EcoTheme t;
  final int value;
  final String? unit;
  final double size;

  const CalBadge({
    super.key,
    required this.t,
    required this.value,
    this.unit,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    final displayUnit = unit ?? context.l10n.unit('kcal');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.pill,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.ink,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayUnit,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: t.ink.withValues(alpha: 0.75),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class MacroRingData {
  final double value;
  final double goal;
  final Color color;
  final Color soft;
  const MacroRingData({
    required this.value,
    required this.goal,
    required this.color,
    required this.soft,
  });

  // Равенство по значению, чтобы _RingsPainter.shouldRepaint мог сравнивать
  // данные содержательно. Иначе главный экран на каждый тик шагомера отдаёт
  // НОВЫЙ список (новая ссылка) и кольца перерисовываются (3 MaskFilter.blur),
  // хотя БЖУ не менялись.
  @override
  bool operator ==(Object other) =>
      other is MacroRingData &&
      other.value == value &&
      other.goal == goal &&
      other.color == color &&
      other.soft == soft;

  @override
  int get hashCode => Object.hash(value, goal, color, soft);
}

/// Concentric macro progress rings (carbs outer, fats middle, protein inner).
class MacroRings extends StatelessWidget {
  final EcoTheme t;
  final double size;
  final List<MacroRingData> data;

  const MacroRings({
    super.key,
    required this.t,
    required this.size,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CustomPaint(
        size: Size.square(size), painter: _RingsPainter(data, t, dpr));
  }
}

class _RingsPainter extends CustomPainter {
  final List<MacroRingData> data;
  final EcoTheme t;
  final double dpr;
  _RingsPainter(this.data, this.t, this.dpr);

  // Кэш статичного слоя «канавки + эмбосс»: он НЕ зависит от значений макросов —
  // только от размера, темы (цвет трека) и плотности пикселей. Раньше эмбосс
  // (saveLayer + MaskFilter.blur) считался на КАЖДОЕ кольцо при каждой отрисовке
  // (в полосе дней — десятки проходов размытия на кадр). Теперь печётся один раз
  // в ui.Image и просто блитится (drawImageRect). Вид ИДЕНТИЧЕН — это та же
  // отрисовка, растеризованная единожды в device-разрешении (блит 1:1).
  static final Map<String, ui.Image> _grooveCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final sw = w * 0.10; // grey groove thickness
    final aw =
        sw; // colour arc thickness = full groove width (synced from Figma MacroRings 47:3)
    final gap = w * 0.048;
    final c = Offset(w / 2, w / 2);
    // Канавка колец = трек темы (как у полос прогресса): в светлой теме тот же
    // серый, в тёмной — светлая полупрозрачная канавка.
    // 1) Статичный слой «канавки + эмбосс» — из кэша (печётся один раз на
    //    уникальный размер/тему/dpr). Блит 1:1 в device-разрешении → вид
    //    идентичен прежней инлайн-отрисовке, но без saveLayer/blur на кадр.
    final key = '${w.toStringAsFixed(2)}|${data.length}|'
        '${t.isDark}|${dpr.toStringAsFixed(2)}';
    final groove = _grooveCache[key] ??= _bakeGrooves(size, sw, gap, c);
    canvas.drawImageRect(
      groove,
      Rect.fromLTWH(0, 0, groove.width.toDouble(), groove.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // 2) Динамические цветные дуги — поверх канавок, каждый кадр (дёшево:
    //    SweepGradient-штрих, без saveLayer/blur).
    for (var i = 0; i < data.length; i++) {
      final r = w / 2 - sw / 2 - 4 - i * (sw + gap);
      if (r <= 0) continue;
      final m = data[i];
      final rect = Rect.fromCircle(center: c, radius: r);
      // Цветная дуга прогресса — ГРАДИЕНТНАЯ (круглые торцы, идёт по канавке).
      // У старта (0%, сверху) — яркий цвет, к 100% ТЕМНЕЕ (SweepGradient по ходу
      // заполнения). За счёт затемнения второй круг (>100%) виден: его виток
      // рисуется ещё темнее ПОВЕРХ первого, поэтому переход через 100% заметен.
      final pct = m.goal > 0 ? m.value / m.goal : 0.0;
      if (pct > 0) {
        const start = -math.pi / 2;
        final bright = m.color;
        final mid = Color.lerp(m.color, Colors.black, 0.35)!; // цвет у 100%
        final deep = Color.lerp(m.color, Colors.black, 0.60)!; // у 200%
        Paint arcPaint(Color from, Color to, StrokeCap cap) => Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = aw
          ..strokeCap = cap
          // Разворот на -90°: старт градиента совпадает с верхом дуги.
          ..shader = SweepGradient(
            colors: [from, to],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect);
        if (pct <= 1.0) {
          // Один круг: дугу рисуем ПЛОСКИМИ торцами, а скругления — явными
          // кружками нужного цвета. round-cap на самой дуге брать НЕЛЬЗЯ: из-за
          // замыкания градиента торец старта захватывает ТЁМНЫЙ конец (цвет у
          // 100%), и скругление старта выглядит тёмным.
          canvas.drawArc(rect, start, math.pi * 2 * pct, false,
              arcPaint(bright, mid, StrokeCap.butt));
          // Скруглённый СТАРТ — ярким (начало градиента).
          canvas.drawCircle(
            c + Offset(math.cos(start), math.sin(start)) * r,
            aw / 2,
            Paint()..color = bright,
          );
          // Скруглённый «растущий» кончик — цветом градиента в точке заполнения.
          final tipAngle = start + math.pi * 2 * pct;
          canvas.drawCircle(
            c + Offset(math.cos(tipAngle), math.sin(tipAngle)) * r,
            aw / 2,
            Paint()..color = Color.lerp(bright, mid, pct)!,
          );
        } else {
          // Перелив (>100%): первый круг — сплошной full-circle с ПЛОСКИМИ
          // торцами (чистое замыкание, без «блоба» на 12 часов); второй виток
          // mid→deep темнее ПОВЕРХ — виден; а его текущий край скругляем
          // отдельным круглым торцом.
          canvas.drawArc(rect, start, math.pi * 2, false,
              arcPaint(bright, mid, StrokeCap.butt));
          final lap2 = math.min(pct - 1.0, 1.0);
          canvas.drawArc(rect, start, math.pi * 2 * lap2, false,
              arcPaint(mid, deep, StrokeCap.butt));
          final tipAngle = start + math.pi * 2 * lap2;
          canvas.drawCircle(
            c + Offset(math.cos(tipAngle), math.sin(tipAngle)) * r,
            aw / 2,
            Paint()..color = Color.lerp(mid, deep, lap2)!,
          );
        }
      }
    }
  }

  // Печёт серые канавки + inner-shadow-эмбосс в растр — ТА ЖЕ отрисовка, что была
  // инлайн в paint(), но выполняется ОДНОКРАТНО на каждый уникальный размер/тему/
  // dpr (результат кэшируется в [_grooveCache]).
  ui.Image _bakeGrooves(Size size, double sw, double gap, Offset c) {
    final w = size.width;
    final trackBase = t.track;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Печём в физических пикселях, чтобы блит был 1:1 и без потери резкости.
    canvas.scale(dpr);
    for (var i = 0; i < data.length; i++) {
      final r = w / 2 - sw / 2 - 4 - i * (sw + gap);
      if (r <= 0) continue;
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = trackBase,
      );
      // Эмбосс канавки — inner-shadow (макет MacroRings 142:1062: inset offset(2,2)
      // blur~2 α0.25): мягкий тёмный полумесяц на верхне-левой кромке (вдавленность).
      // Смещение/размытие масштабируются по размеру (k = w/168). Приём: в offscreen-
      // слое заливаем канавку цветом тени и ВЫРЕЗАЕМ (dstOut) смещённую вниз-вправо
      // размытую копию.
      final k = w / 168.0;
      final band = rect.inflate(sw);
      canvas.saveLayer(band, Paint());
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = const Color(0x40000000), // тень чёрная α0.25
      );
      canvas.drawArc(
        Rect.fromCircle(center: c + Offset(2 * k, 2 * k), radius: r),
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = const Color(0xFF000000)
          ..blendMode = BlendMode.dstOut
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * k),
      );
      canvas.restore();
    }
    return recorder.endRecording().toImageSync(
          (size.width * dpr).ceil(),
          (size.height * dpr).ceil(),
        );
  }

  @override
  bool shouldRepaint(_RingsPainter old) {
    if (old.t != t || old.dpr != dpr || old.data.length != data.length) {
      return true;
    }
    for (var i = 0; i < data.length; i++) {
      if (old.data[i] != data[i]) return true; // MacroRingData == по значению
    }
    return false;
  }
}

/// Legend next to the rings (dot on the left, text left-aligned).
class MacroLegend extends StatelessWidget {
  final EcoTheme t;
  final List<
      ({
        String label,
        int value,
        int goal,
        int grams,
        int gramsGoal,
        Color color
      })> items;

  const MacroLegend({super.key, required this.t, required this.items});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: m.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Строка 1 — граммы (первичная величина макроса): съедено/цель.
                    _MacroLegendValue(
                      t: t,
                      value: '${m.grams}',
                      rest: ' /${m.gramsGoal} ${l.unit('g')}',
                    ),
                    const SizedBox(height: 2),
                    // Строка 2 — энергия в kcal (значения — kcal, а не cal).
                    _MacroLegendValue(
                      t: t,
                      value: '${m.value}',
                      rest: ' /${m.goal} ${l.unit('kcal')}',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Одна строка значения в [MacroLegend]: съеденное число — жирным (t.ink),
/// « /цель ед.» — приглушённым (t.sub). Общий вид для строки граммов и kcal.
class _MacroLegendValue extends StatelessWidget {
  final EcoTheme t;
  final String value;
  final String rest;

  const _MacroLegendValue({
    required this.t,
    required this.value,
    required this.rest,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: rest),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, height: 1.1, color: t.sub),
    );
  }
}

/// Progress scale with target/overflow logic.
/// • Solid colour fills up to min(value, target); a sharp black marker sits at
///   the target; the remainder is a light tint of the colour, or — on overflow
///   — a darker tint extending past the target.
/// • Target label is always green; real label is dark ink.
/// • Normal (value ≤ target): target on top-right, real below at the fill end.
/// • Overflow (value > target): they swap — real on top-right, green target
///   moves down to its (left-shifted) marker.
/// Inset-тень (утопленный жёлоб) для скруглённого трека прогресса — глубина по
/// макету (`inset 0 4 4 rgba(0,0,0,.25)`). Кладётся в стопке ПОД заливку, чтобы
/// жёлоб выглядел вдавленным, а заливка — приподнятой. Тот же настоящий
/// inner-shadow (offscreen-слой + dstOut смещённой размытой копии), что у грувов
/// колец MacroRings, — вместо прежней плоской градиент-имитации.
class EcoInsetShadow extends StatelessWidget {
  const EcoInsetShadow({super.key});

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: CustomPaint(painter: _InsetShadowPainter()));
}

class _InsetShadowPainter extends CustomPainter {
  const _InsetShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    // Приём inner-shadow: в offscreen-слое заливаем жёлоб цветом тени и ВЫРЕЗАЕМ
    // (dstOut) смещённую ВНИЗ размытую копию — остаётся мягкая тёмная полоса у
    // ВЕРХНЕЙ кромки (тень от верхнего края внутрь = вдавленность).
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(rr, Paint()..color = const Color(0x40000000)); // α0.25
    canvas.drawRRect(
      rr.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetShadowPainter old) => false;
}

/// Единый «объём» из макета: frosted-подложка (по умолч. white α20) + drop-тень
/// снизу-справа (`2 2 blur2 black α25`) + inset-хайлайт сверху-слева
/// (`inset 2 2 blur2 white α25`). Один эффект для пилюль/бейджей/кнопок/аватара
/// любой формы (radius; 999 = пилюля/круг). Скопировано из профиля (167:1242 и др.).
class EcoGlassChip extends StatefulWidget {
  final Widget child;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// Если задан — чип становится нажимаемой СТАНДАРТНОЙ кнопкой: показывает
  /// тот же press-эффект, что [EcoGlassButton] (в покое inset-белый хайлайт,
  /// нажата — inset-чёрная тень + белая кайма). null — статичный чип-объём.
  final VoidCallback? onTap;

  const EcoGlassChip({
    super.key,
    required this.child,
    this.radius = 999,
    this.color,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  State<EcoGlassChip> createState() => _EcoGlassChipState();
}

class _EcoGlassChipState extends State<EcoGlassChip> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    // Прозрачность подложки ПРИВЯЗАНА к ползунку «Прозрачность карточек»
    // (AppStore.cardOpacity) — чипы и карточки одинаково прозрачны и меняются
    // вместе. Базовый тон берём из темы (glassBase): белый в светлой, тёмный в
    // тёмной — иначе при низкой прозрачности чип становился белым. Явный [color]
    // (thumb/аватар/teal) слайдер и тему не трогает.
    final fill = widget.color ??
        context
            .select<AppStore, Color>((s) => s.theme.glassBase)
            .withValues(
              alpha: context.select<AppStore, double>((s) => s.cardOpacity),
            );
    // Чистое стекло, как у стандартной кнопки: drop-тень рисуется ТОЛЬКО снаружи
    // контура (_GlassButtonBgPainter), поэтому полупрозрачная заливка не садится
    // на собственную тень и не сереет (раньше frosted backdrop-blur + тень
    // позади давали мутно-серый вид).
    final content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _GlassSurface(radius: widget.radius, fill: fill),
            ),
          ),
          widget.padding != null
              ? Padding(padding: widget.padding!, child: widget.child)
              : widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: (widget.onTap != null && _pressed)
                    ? _GlassHighlightPainter(
                        widget.radius,
                        color: const Color(0x40000000),
                        border: true,
                      )
                    : _GlassHighlightPainter(widget.radius),
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.onTap == null) return content;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Кнопка-стекло строго по макету Figma (reset-button 163:601): плоское стекло
/// БЕЗ backdrop-blur. Заливка white × cardOpacity (прозрачность привязана к
/// ползунку «Прозрачность карточек», как у карточек) + drop-тень 2/2/2 α25 +
/// inset-белый хайлайт 2/2/2 α25. Ключевое отличие от наивного BoxShadow:
/// drop-тень рисуется ТОЛЬКО СНАРУЖИ контура (см. [_GlassButtonBgPainter]),
/// поэтому полупрозрачная заливка НЕ темнеет от собственной тени — как внешняя
/// тень в CSS/Figma, которая не просвечивает сквозь элемент. Из-за этого при
/// высокой прозрачности кнопка остаётся чистым светлым стеклом, а не серой.
class EcoGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;

  /// Фикс. ширина (для квадратных/круглых кнопок, напр. edit 48×48). null —
  /// ширина по содержимому + [padding] (пилюля «+ 250 мл», «Начать»).
  final double? width;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Пассивное (неактивное) состояние — макет Button 213:2147 (Type6): то же
  /// светлое стекло, но БЕЗ press-реакции; текст задаётся вызовом как faint
  /// (серый). Обычно вместе с `onTap: null`.
  final bool passive;

  /// Восстанавливает искажение фона (backdrop-blur) под кнопкой. По умолчанию
  /// ВЫКЛ; включается для нижних кнопок-действий листов, стоящих поверх
  /// прокручиваемого контента (Отмена/Сохранить/Добавить/Готово).
  final bool frosted;

  const EcoGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.height = 56,
    this.width,
    this.radius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.passive = false,
    this.frosted = false,
  });

  @override
  State<EcoGlassButton> createState() => _EcoGlassButtonState();
}

class _EcoGlassButtonState extends State<EcoGlassButton> {
  // Нажата → 2-е состояние кнопки (макет Component 1 227:6287, Variant2).
  bool _pressed = false;

  void _set(bool v) {
    // Пассивная кнопка не «утапливается» при нажатии.
    if (widget.passive) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    // Базовый тон из темы (glassBase): белое стекло в светлой теме, тёмное — в
    // тёмной. Иначе при низкой прозрачности (высокой альфе) кнопка становилась
    // почти сплошь белой на тёмном фоне.
    final fill = context
        .select<AppStore, Color>((s) => s.theme.glassBase)
        .withValues(
          alpha: context.select<AppStore, double>((s) => s.cardOpacity),
        );
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Тень снаружи + заливка (+ backdrop-blur, если frosted).
            Positioned.fill(
              child: IgnorePointer(
                child: _GlassSurface(
                  radius: widget.radius,
                  fill: fill,
                  blur: widget.frosted,
                ),
              ),
            ),
            Padding(padding: widget.padding, child: widget.child),
            // Default → inset БЕЛЫЙ хайлайт («приподнята»); нажата (Variant2) →
            // inset ЧЁРНАЯ тень + белая кайма («утоплена»). Макет 227:6287.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _pressed
                      ? _GlassHighlightPainter(
                          widget.radius,
                          color: const Color(0x40000000),
                          border: true,
                        )
                      : _GlassHighlightPainter(widget.radius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Статичная «нажатая»/утоплённая стеклянная подложка — тот же вид, что у
/// [EcoGlassButton] в pressed-состоянии (Variant2 227:6288), но без интеракции:
/// тень СНАРУЖИ контура + backdrop-blur искажение фона + полупрозрачная заливка
/// + inset-ЧЁРНАЯ тень + белая кайма. Для контейнеров, которые должны выглядеть
/// вдавленными (подложка сегментера). Контент рисуется поверх (Positioned.fill).
class EcoGlassSunken extends StatelessWidget {
  final double radius;

  /// Заливка. null → white × cardOpacity (как у стекла кнопок/карточек), поэтому
  /// подложка искажает фон одинаково с остальными стеклянными элементами.
  final Color? fill;

  const EcoGlassSunken({super.key, this.radius = 999, this.fill});

  @override
  Widget build(BuildContext context) {
    // Базовый тон из темы (glassBase): белый в светлой, тёмный в тёмной — иначе
    // при низкой прозрачности подложка становилась белой. Явный [fill] не трогаем.
    final f = fill ??
        context
            .select<AppStore, Color>((s) => s.theme.glassBase)
            .withValues(
              alpha: context.select<AppStore, double>((s) => s.cardOpacity),
            );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Тень снаружи + искажение фона (backdrop-blur) + заливка.
        Positioned.fill(
          child: IgnorePointer(child: _GlassSurface(radius: radius, fill: f)),
        ),
        // inset-ЧЁРНАЯ тень + белая кайма — «утоплена» (макет Variant2 227:6288).
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GlassHighlightPainter(
                radius,
                color: const Color(0x40000000),
                border: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Стеклянная подложка стандартной кнопки/чипа: тень СНАРУЖИ контура +
/// backdrop-blur ФОНА (искажение-рефракция — фон под кнопкой размывается и
/// «плывёт» сквозь стекло, как liquid-glass) + полупрозрачная белая заливка
/// поверх размытия. Тень рисуется отдельным слоем и вырезается по контуру
/// (dstOut), поэтому полупрозрачная заливка не садится на собственную тень и не
/// сереет. Заливка непрозрачным [fill] (петроль/аватар) искажение скрывает —
/// такие элементы остаются сплошными.
class _GlassSurface extends StatelessWidget {
  final double radius;
  final Color fill;

  /// Искажение фона (backdrop-blur σ8) сквозь стекло. По умолчанию ВЫКЛ. Включается
  /// только для нижних кнопок-действий листов (Отмена/Сохранить/Добавить/Готово),
  /// где под кнопкой скроллит контент и его нужно «заморозить» под пилюлей.
  final bool blur;

  const _GlassSurface({
    required this.radius,
    required this.fill,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Drop-тень снаружи контура.
        Positioned.fill(
          child: CustomPaint(painter: _GlassShadowPainter(radius)),
        ),
        // Клип по форме: полупрозрачная заливка; при blur=true — ещё и искажение
        // фона (backdrop-blur σ8) под пилюлей.
        Positioned.fill(
          child: ClipRRect(
            borderRadius: br,
            child: blur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: ColoredBox(color: fill),
                  )
                : ColoredBox(color: fill),
          ),
        ),
      ],
    );
  }
}

class _GlassShadowPainter extends CustomPainter {
  final double radius;
  const _GlassShadowPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = math.min(radius, size.shortestSide / 2);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    // Drop-тень 2 2 blur α25 в отдельном слое: рисуем тень, затем ВЫРЕЗАЕМ
    // (dstOut) контур → остаётся только внешний ореол (внутрь не просвечивает).
    canvas.saveLayer(
      Rect.fromLTRB(-6, -6, size.width + 6, size.height + 6),
      Paint(),
    );
    canvas.drawRRect(
      rr.shift(const Offset(2, 2)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.15),
    );
    canvas.drawRRect(rr, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) => old.radius != radius;
}

class _GlassHighlightPainter extends CustomPainter {
  final double radius;

  /// Цвет inset-полумесяца: белый α25 — «приподнятость» (Default); чёрный α25 —
  /// «утоплённость» нажатого стеклянного состояния (макет Variant2 227:6288).
  final Color color;

  /// Белая кайма 1px по контуру — только у нажатого состояния (Variant2).
  final bool border;

  const _GlassHighlightPainter(
    this.radius, {
    this.color = const Color(0x40FFFFFF),
    this.border = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = math.min(radius, size.shortestSide / 2);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    // Inset у верхне-левой кромки: заливаем [color], вырезаем (dstOut) смещённую
    // вниз-вправо размытую копию → мягкий полумесяц у верхне-левой кромки.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(rr, Paint()..color = color);
    canvas.drawRRect(
      rr.shift(const Offset(2, 2)),
      Paint()
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.restore();
    if (border) {
      canvas.drawRRect(
        rr.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassHighlightPainter old) =>
      old.radius != radius || old.color != color || old.border != border;
}

/// Публичная обёртка над [_GlassHighlightPainter]: inset-эффект сверху-слева для
/// переиспользования glass-объёма сегментера вне библиотеки (напр.
/// `_PortionStandardTabs` в dish.dart). [color] white α25 = «приподнятость»
/// (пилюля), black α25 = «утоплённость» подложки (нажатая кнопка).
class EcoGlassHighlight extends StatelessWidget {
  final double radius;
  final Color color;
  const EcoGlassHighlight({
    super.key,
    this.radius = 999,
    this.color = const Color(0x40FFFFFF),
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child:
            CustomPaint(painter: _GlassHighlightPainter(radius, color: color)),
      );
}

class ProgressScale extends StatelessWidget {
  final EcoTheme t;
  final double value;
  final double target;
  final Color color;
  final double barHeight;
  final String unit;
  final String label;
  final bool animateFromZero;

  /// Показывать верхнюю строку (подпись слева + значение нормы справа).
  final bool showTopRow;

  /// Необязательный виджет в левую часть верхней строки вместо текстового
  /// [label] (например, «имя + чип» критичного нутриента). Значение нормы
  /// остаётся справа, текущее значение — под баром (стандартная логика шкалы).
  final Widget? leading;
  // Необязательный градиент заливки (например, «огненный» для «Итога»).
  // Если задан — рисуется вместо сплошного [color]; [color] при этом всё равно
  // используется для тинтов остатка/перелива.
  final Gradient? fillGradient;

  const ProgressScale({
    super.key,
    required this.t,
    required this.value,
    required this.target,
    required this.color,
    this.barHeight = 16,
    this.unit = '',
    this.label = '',
    this.animateFromZero = false,
    this.showTopRow = true,
    this.leading,
    this.fillGradient,
  });

  // Разделитель дробной части — по локали (num1): «,» для ru/uz, «.» для en.
  // Раньше здесь был жёсткий replaceAll('.', ','), из-за чего английская локаль
  // тоже получала запятую.
  String _fmt(AppStrings l, double n) {
    final s = l.num1(n);
    return unit.isEmpty ? s : '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animateFromZero ? 0 : value, end: value),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final over = animatedValue > target;
        final total = math.max(animatedValue, math.max(target, 1.0));
        final light = Color.lerp(color, Colors.white, 0.62)!;
        final darker = Color.lerp(color, Colors.black, 0.28)!;
        final realTxt = _fmt(l, value);
        final targetTxt = _fmt(l, target);
        final realOpacity =
            (1 - ((animatedValue - value).abs() / 0.08)).clamp(0.0, 1.0);

        Widget lbl(String s, Color c) => Text(
              s,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c,
                height: 1,
              ),
            );
        // Прозрачность вшита в цвет одиночного Text — пиксельно идентично
        // Opacity, но без offscreen saveLayer на каждый кадр анимации полосы.
        Widget realLbl() => lbl(realTxt, t.ink.withValues(alpha: realOpacity));

        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final solidW = (math.min(animatedValue, target) / total) * w;
            final targetX = (target / total) * w;
            final valueX = (animatedValue / total) * w;
            Alignment atTop(double px) =>
                Alignment(((px / w) * 2 - 1).clamp(-0.96, 0.96), -1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: optional label (left) + target green (right), or — on
                // overflow — the real value (ink) on the right.
                if (showTopRow) ...[
                  leading != null
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: leading!),
                            over
                                ? realLbl()
                                : lbl(targetTxt, EcoColors.statusGood),
                          ],
                        )
                      : SizedBox(
                          height: 15,
                          width: w,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: label.isEmpty
                                    ? const SizedBox.shrink()
                                    : Text(
                                        label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: t.ink,
                                          height: 1,
                                        ),
                                      ),
                              ),
                              over
                                  ? realLbl()
                                  : lbl(targetTxt, EcoColors.statusGood),
                            ],
                          ),
                        ),
                  const SizedBox(height: 6),
                ],
                // The bar.
                SizedBox(
                  height: barHeight,
                  width: w,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Remainder: light tint (under) / darker overflow (over).
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: over ? darker : light,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      // Inset-тень жёлоба (утопленность) — ПОД заливкой, поэтому
                      // видна только на незалитом остатке; заливка «приподнята».
                      // Тот же настоящий inner-shadow, что у грувов колец
                      // (макет inset 0 4 4 rgba(0,0,0,.25)).
                      const Positioned.fill(child: EcoInsetShadow()),
                      // Solid fill up to min(value, target).
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: solidW.clamp(0.0, w),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fillGradient == null ? color : null,
                            gradient: fillGradient,
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(999),
                              right: Radius.circular(over ? 0 : 999),
                            ),
                          ),
                        ),
                      ),
                      // Sharp black target marker — only on overflow.
                      if (over)
                        Positioned(
                          left: (targetX - 1.5).clamp(0.0, w - 3),
                          top: -1,
                          bottom: -1,
                          width: 3,
                          child: const DecoratedBox(
                            decoration:
                                BoxDecoration(color: EcoColors.statusGood),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Bottom: real (ink) at fill end under; green target at marker over.
                SizedBox(
                  height: 12,
                  width: w,
                  child: Stack(
                    children: [
                      if (!over)
                        Align(alignment: atTop(valueX), child: realLbl()),
                      if (over)
                        Align(
                          alignment: atTop(targetX),
                          child: lbl(targetTxt, EcoColors.statusGood),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Calorie tracker block — uses [ProgressScale] (brown calorie scale).
class CalorieTrack extends StatelessWidget {
  final EcoTheme t;
  final int value;
  final int goal;

  /// Сплошная оранжевая заливка (макет) вместо огненного градиента calFire.
  final bool solidFill;

  const CalorieTrack({
    super.key,
    required this.t,
    required this.value,
    required this.goal,
    this.solidFill = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ProgressScale(
      t: t,
      value: value.toDouble(),
      target: goal.toDouble(),
      color: EcoColors.cal,
      fillGradient: solidFill ? null : EcoColors.calFire,
      unit: l.unit('kcal'),
      label: l.t('common.totalAmount'),
    );
  }
}

/// Design-styled bottom sheet shell (the band-coloured rounded modal used by
/// portion / time / kcal pickers) with Отменить / Готово buttons.
Future<void> showEcoSheet({
  required BuildContext context,
  required EcoTheme t,
  required String title,
  required Widget body,
  required VoidCallback onDone,
  String? doneLabel,
}) {
  final l = context.l10nRead;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4714180C),
    builder: (sheetCtx) => EcoGlassSurface(
      t: t,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      // Окно ввода: полупрозрачная стеклянная подложка как у пикеров онбординга
      // («Ваш рост»). solid:false → фон просвечивает. Блюр σ15, а не σ60: внутри
      // крутятся барабаны CupertinoPicker, и живой BackdropFilter пересчитывается
      // на КАЖДЫЙ кадр прокрутки — на матовой подложке σ15 визуально неотличим от
      // σ60, но кратно дешевле (тот же класс лагов чинили в 6fe473a).
      solid: false,
      blur: 15,
      borderRadius: BorderRadius.circular(26),
      shadows: const [
        BoxShadow(
          color: Color(0x28FFFFFF),
          blurRadius: 24,
          offset: Offset(-2, -2),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 8),
          body,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: EcoBtn(
                  t: t,
                  height: 46,
                  fontSize: 16,
                  onTap: () => Navigator.of(sheetCtx).pop(),
                  child: Text(l.t('common.cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoBtn(
                  t: t,
                  height: 46,
                  fontSize: 16,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onDone();
                  },
                  child: Text(doneLabel ?? l.t('common.done')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class EcoPickerSelectionOverlay extends StatelessWidget {
  final EcoTheme t;
  final double radius;
  final EdgeInsets margin;

  /// Заливка пилюли. По умолчанию едва заметная (white α10) — для солидных
  /// модальных пикеров; онбординг-колёса по макету используют white α34
  /// (= cardAlt, как активная пилюля языка на Welcome).
  final Color? fill;

  const EcoPickerSelectionOverlay({
    super.key,
    required this.t,
    this.radius = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill ?? Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.58),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 2,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day / month / year wheel picker that matches the app's number pickers —
/// centred Onest text with a separate liquid-glass pill per column.
class EcoDatePicker extends StatefulWidget {
  final EcoTheme t;
  final DateTime initialDate;
  final int minYear;
  final int maxYear;
  final List<String> monthNames;
  final ValueChanged<DateTime> onChanged;

  const EcoDatePicker({
    super.key,
    required this.t,
    required this.initialDate,
    required this.minYear,
    required this.maxYear,
    required this.monthNames,
    required this.onChanged,
  });

  @override
  State<EcoDatePicker> createState() => _EcoDatePickerState();
}

class _EcoDatePickerState extends State<EcoDatePicker> {
  late int _day;
  late int _month;
  late int _year;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year.clamp(widget.minYear, widget.maxYear);
    _month = widget.initialDate.month;
    _day = widget.initialDate.day;
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl =
        FixedExtentScrollController(initialItem: _year - widget.minYear);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _emit() => widget.onChanged(DateTime(_year, _month, _day));

  /// Ближайший к [current] индекс бесконечного барабана, дающий по модулю
  /// [base] значение [target]. Нужен, чтобы перевыровнять день без прыжка через
  /// весь барабан, когда у месяца меняется число дней.
  int _nearestCyclicItem(int current, int base, int target) {
    final k = ((current - target) / base).round();
    return k * base + target;
  }

  /// Барабан дня бесконечный, а число дней зависит от месяца/года. После смены
  /// месяца или года подрезаем день под новый максимум и перевыравниваем позицию
  /// барабана, иначе показанный день «уплывёт» (модуль-то поменялся).
  void _syncDayAndEmit() {
    final maxD = _daysInMonth;
    if (_day > maxD) _day = maxD;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayCtrl.hasClients) return;
      final target = _nearestCyclicItem(_dayCtrl.selectedItem, maxD, _day - 1);
      if (_dayCtrl.selectedItem != target) _dayCtrl.jumpToItem(target);
    });
    _emit();
  }

  // Пилюля выбранного значения ПОД колесом (макет BirthDatePicker 233:580):
  // тот же [EcoPickerSelectionOverlay], что у пикеров роста/веса — единый glass-
  // эффект (кайма + тень + верхний градиентный блик). Высота фикс 58 и
  // центрирование по колонке (Align) делают её независимой от высоты колонки
  // (h216 в онбординге / h200 в модалках). Важно: слой ПОД текстом (не поверх),
  // иначе полупрозрачная заливка осветляет чёрное число. [hPad] — ширина пилюли
  // в колонке (день/год уже, месяц шире); форма/размер не меняются.
  Widget _pill(double hPad) => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: 58,
          width: double.infinity,
          child: EcoPickerSelectionOverlay(
            t: widget.t,
            radius: 999,
            fill: Colors.white.withValues(alpha: 0.34),
            margin: EdgeInsets.symmetric(horizontal: hPad),
          ),
        ),
      );

  // Колесо: ряд h58, выбранное значение Onest Bold 24 t.ink. selectionOverlay
  // пустой — пилюля рисуется отдельным слоем ПОД текстом (см. [_pill]).
  Widget _wheel({
    required FixedExtentScrollController controller,
    int? childCount,
    required ValueChanged<int> onSelected,
    required String Function(int) label,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 58,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelected,
      childCount: childCount,
      itemBuilder: (_, index) => Center(
        child: Text(
          label(index),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: widget.t.ink,
          ),
        ),
      ),
    );
  }

  // Колонка = пилюля-подложка (по центру) + колесо поверх. Высота колонки любая
  // (пилюля центрируется), поэтому пикер одинаков и в онбординге (h216), и в
  // модальных листах (h200).
  Widget _column({
    required int flex,
    required FixedExtentScrollController controller,
    int? childCount,
    required ValueChanged<int> onSelected,
    required String Function(int) label,
    required double hPad,
  }) {
    return Expanded(
      flex: flex,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _pill(hPad),
          _wheel(
            controller: controller,
            childCount: childCount,
            onSelected: onSelected,
            label: label,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _column(
          flex: 3,
          controller: _dayCtrl,
          childCount: null, // бесконечный барабан: до 1 — последнее число
          onSelected: (i) => setState(() {
            _day = i % _daysInMonth + 1;
            _emit();
          }),
          label: (i) => '${i % _daysInMonth + 1}',
          hPad: 15, // пилюля дня узкая
        ),
        _column(
          flex: 5,
          controller: _monthCtrl,
          childCount: null, // бесконечный барабан: до января — декабрь
          onSelected: (i) => setState(() {
            _month = i % 12 + 1;
            _syncDayAndEmit();
          }),
          label: (i) => widget.monthNames[i % 12],
          hPad: 8, // пилюля месяца широкая
        ),
        _column(
          flex: 4,
          controller: _yearCtrl,
          childCount: widget.maxYear - widget.minYear + 1,
          onSelected: (i) => setState(() {
            _year = widget.minYear + i;
            _syncDayAndEmit();
          }),
          label: (i) => '${widget.minYear + i}',
          hPad: 16, // пилюля года
        ),
      ],
    );
  }
}

/// Календарь выбора диапазона дат (шторка «Период» на экране ИИ-ассистента):
/// листаемый месяц + сетка дней в стиле приложения. Первый тап ставит начало,
/// второй (не раньше первого) — конец; тап раньше начала начинает выбор заново.
/// Один выбранный день — валидный интервал (начало == конец).
class EcoRangeCalendar extends StatefulWidget {
  final EcoTheme t;
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime minDate;
  final DateTime maxDate;

  /// Текущий выбор после каждого тапа; пока конец не выбран, end == start.
  final void Function(DateTime start, DateTime end) onChanged;

  const EcoRangeCalendar({
    super.key,
    required this.t,
    required this.initialStart,
    required this.initialEnd,
    required this.minDate,
    required this.maxDate,
    required this.onChanged,
  });

  @override
  State<EcoRangeCalendar> createState() => _EcoRangeCalendarState();
}

class _EcoRangeCalendarState extends State<EcoRangeCalendar> {
  // Петроль ползунка EcoSegmented — те же акценты у выбранных дат.
  static const _petrol = Color(0xFF045157);

  late DateTime _month; // первое число показываемого месяца
  late DateTime _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = _day(widget.initialStart);
    final end = _day(widget.initialEnd);
    _end = end;
    _month = DateTime(end.year, end.month);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _min => _day(widget.minDate);
  DateTime get _max => _day(widget.maxDate);

  bool get _canPrev => _month.isAfter(DateTime(_min.year, _min.month));

  bool get _canNext => !DateTime(_month.year, _month.month + 1)
      .isAfter(DateTime(_max.year, _max.month));

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _tap(DateTime d) {
    setState(() {
      if (_end == null && !d.isBefore(_start)) {
        _end = d;
      } else {
        _start = d;
        _end = null;
      }
    });
    widget.onChanged(_start, _end ?? _start);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _arrow(Icons.chevron_left, _canPrev ? () => _shiftMonth(-1) : null),
            Expanded(
              child: Center(
                child: Text(
                  '${l.monthName(_month.month)} ${_month.year}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
            ),
            _arrow(Icons.chevron_right, _canNext ? () => _shiftMonth(1) : null),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var wd = 1; wd <= 7; wd++)
              Expanded(
                child: Center(
                  child: Text(
                    l.weekdayShort(wd),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ..._weeks(t),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 36,
        child: Icon(
          icon,
          size: 24,
          color: onTap == null ? widget.t.faint : widget.t.ink,
        ),
      ),
    );
  }

  List<Widget> _weeks(EcoTheme t) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = (_month.weekday - 1) % 7; // неделя начинается с понедельника
    final today = _day(DateTime.now());
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      for (var row = 0; row < cells.length ~/ 7; row++)
        SizedBox(
          height: 40,
          child: Row(
            children: [
              for (var col = 0; col < 7; col++)
                _cell(t, cells[row * 7 + col], today),
            ],
          ),
        ),
    ];
  }

  Widget _cell(EcoTheme t, DateTime? d, DateTime today) {
    if (d == null) return const Expanded(child: SizedBox());
    final end = _end ?? _start;
    final enabled = !d.isBefore(_min) && !d.isAfter(_max);
    final isStart = d == _start;
    final isEnd = d == end;
    final hasSpan = end != _start;
    final inRange = d.isAfter(_start) && d.isBefore(end);
    // Полоса диапазона рисуется половинками ячейки, чтобы у крайних дат она
    // доходила ровно до центра круга (как в системных range-пикерах).
    final paintLeft = hasSpan && (inRange || isEnd) && !isStart;
    final paintRight = hasSpan && (inRange || isStart) && !isEnd;
    final band = _petrol.withValues(alpha: 0.14);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _tap(d) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (paintLeft || paintRight)
              Center(
                child: SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(color: paintLeft ? band : null),
                      ),
                      Expanded(
                        child: Container(color: paintRight ? band : null),
                      ),
                    ],
                  ),
                ),
              ),
            if (isStart || isEnd)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _petrol,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (d == today)
              Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _petrol.withValues(alpha: 0.45),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            Center(
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isStart || isEnd ? FontWeight.w700 : FontWeight.w600,
                  color: isStart || isEnd
                      ? t.onDark
                      : enabled
                          ? t.ink
                          : t.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcoChoiceOption<T> {
  final T value;
  final String label;
  final String? prefix;

  const EcoChoiceOption({
    required this.value,
    required this.label,
    this.prefix,
  });
}

/// Ширина всплывающего меню подгоняется под самую длинную надпись: без лишних
/// зазоров по краям и без обрезки текста.
///
/// Важно для смены языка — длина строк меняется, поэтому ширину нельзя
/// фиксировать. Измеряем самым жирным (выбранным) начертанием и обязательно тем
/// же шрифтом, что и в UI (Onest), с учётом системного масштаба текста — иначе
/// расчётная ширина окажется меньше реальной и надпись «съест» многоточие.
///
/// [chrome] — всё, что добавляется к ширине текста (паддинги подложки и строки,
/// блок префикса и т. п.). [minWidth]/[maxWidth] ограничивают результат.
double ecoPopupContentWidth({
  required BuildContext context,
  required List<String> labels,
  double fontSize = 16,
  double chrome = 0,
  double minWidth = 0,
  double? maxWidth,
}) {
  final media = MediaQuery.of(context);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  var labelMax = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: direction,
      textScaler: media.textScaler,
      maxLines: 1,
    )..layout();
    if (painter.width > labelMax) labelMax = painter.width;
  }
  final hardMax = maxWidth ?? (media.size.width - 24);
  return (labelMax + chrome).clamp(minWidth, hardMax).toDouble();
}

Future<T?> showEcoChoicePopup<T>({
  required BuildContext context,
  required EcoTheme t,
  required GlobalKey anchorKey,
  required List<EcoChoiceOption<T>> options,
  required T selected,
}) {
  final l = context.l10nRead;
  final media = MediaQuery.of(context);
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final anchorOffset =
      anchorBox?.localToGlobal(Offset.zero) ?? Offset(media.size.width - 24, 0);
  final anchorSize = anchorBox?.size ?? const Size(44, 44);
  // Ширина подгоняется под самую длинную надпись (не фиксируется), чтобы меню
  // не было шире текста и не обрезало его. Хром: паддинг подложки (12*2) +
  // паддинг строки (14*2) + блок префикса (34) + запас (6).
  final hasPrefix = options.any((option) => option.prefix != null);
  final popupWidth = ecoPopupContentWidth(
    context: context,
    labels: [for (final option in options) option.label],
    chrome: 12 * 2 + 14 * 2 + (hasPrefix ? 34.0 : 0.0) + 6,
    minWidth: 84,
    maxWidth: media.size.width - 24,
  );
  final popupHeight = 18.0 + options.length * 46.0;
  final left = (anchorOffset.dx + anchorSize.width - popupWidth)
      .clamp(12.0, media.size.width - popupWidth - 12.0);
  final belowTop = anchorOffset.dy + anchorSize.height + 6;
  final aboveTop = anchorOffset.dy - popupHeight - 6;
  final popupTop =
      belowTop + popupHeight <= media.size.height - media.padding.bottom - 8
          ? belowTop
          : aboveTop.clamp(media.padding.top + 8, media.size.height);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.t('common.cancel'),
    // Без затемнения фона — как у меню категорий (единое поведение).
    barrierColor: Colors.transparent,
    transitionDuration: kEcoMotionDuration,
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (dialogCtx, animation, _, __) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: kEcoMotionCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          Positioned(
            left: left.toDouble(),
            top: popupTop.toDouble(),
            width: popupWidth.toDouble(),
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: Material(
                  color: Colors.transparent,
                  child: EcoGlassSurface(
                    t: t,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    // Меню выбора: полупрозрачная стеклянная подложка как у окон
                    // ввода («Размер порции») — solid:false + сильное размытие.
                    solid: false,
                    blur: 60,
                    borderRadius: BorderRadius.circular(22),
                    // Единые тени для всех меню: мягкая тёмная + верхний блик.
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in options)
                          _EcoChoicePopupRow<T>(
                            t: t,
                            option: option,
                            selected: option.value == selected,
                            onTap: () =>
                                Navigator.of(dialogCtx).pop(option.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _EcoChoicePopupRow<T> extends StatelessWidget {
  final EcoTheme t;
  final EcoChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _EcoChoicePopupRow({
    required this.t,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Единое выделение выбранного — стеклянная пилюля как у пикеров
              // («173 см», фото 5).
              if (selected)
                Positioned.fill(
                  child: EcoPickerSelectionOverlay(
                    t: t,
                    radius: 999,
                    margin: EdgeInsets.zero,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (option.prefix != null) ...[
                      SizedBox(
                        width: 34,
                        child: Text(
                          option.prefix!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: t.ink,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented pill control.
class EcoSegmented extends StatefulWidget {
  final EcoTheme t;
  final List<String> options;

  /// Индекс активного сегмента; -1 = ничего не выбрано (ползунок скрыт) — так
  /// экран ИИ показывает произвольный интервал из календаря вместо пресета.
  final int value;
  final ValueChanged<int> onChanged;

  const EcoSegmented({
    super.key,
    required this.t,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  State<EcoSegmented> createState() => _EcoSegmentedState();
}

class _EcoSegmentedState extends State<EcoSegmented> {
  // Последний активный сегмент. При снятии выделения (value == -1) ползунок
  // остаётся ПОД ним и просто исчезает по прозрачности, а не уезжает влево к
  // нулевому сегменту.
  late int _lastSelected = widget.value >= 0 ? widget.value : 0;

  @override
  void didUpdateWidget(EcoSegmented old) {
    super.didUpdateWidget(old);
    if (widget.value >= 0) _lastSelected = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final options = widget.options;
    final selected = widget.value >= 0 && widget.value < options.length;
    // Подложка = «вдавленная» стеклянная кнопка (как селектор порции в dish.dart,
    // макет EcoSegmented 66:7): тень СНАРУЖИ контура (dstOut, не сереет сквозь
    // полупрозрачную заливку) + заливка white×cardOpacity + inset-тёмная тень +
    // белая кайма. Прежний плоский вариант держал drop-тень ПОД заливкой — та
    // садилась на свою тень и подложка серела.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: EcoGlassSunken(radius: 999)),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 115),
                  opacity: selected ? 1 : 0,
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 115),
                    curve: Curves.easeOutCubic,
                    // При снятии выделения держим позицию последнего сегмента —
                    // ползунок тает на месте, а не съезжает к нулевому.
                    alignment:
                        _alignmentFor(selected ? widget.value : _lastSelected),
                    child: FractionallySizedBox(
                      widthFactor: 1 / options.length,
                      heightFactor: 1,
                      // Ползунок — петроль #045157 + drop-тень 2/2/2 α25 +
                      // inset-белый хайлайт (glass-объём).
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF045157),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    offset: Offset(2, 2),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: EcoGlassHighlight(radius: 999),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onChanged(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 85),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: i == widget.value ? t.onDark : t.ink,
                              ),
                              child: Text(
                                options[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Alignment _alignmentFor(int index) {
    if (widget.options.length <= 1) return Alignment.center;
    final x = -1 + 2 * (index / (widget.options.length - 1));
    return Alignment(x, 0);
  }
}

class EcoBottomNav extends StatefulWidget {
  static String? _lastActive;

  final EcoTheme t;
  final String active;
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback onPlus;
  final String fabIcon;
  final double fabTurns;
  final bool trackActive;
  final bool darkGlass;
  final bool hidden;

  const EcoBottomNav({
    super.key,
    required this.t,
    required this.active,
    required this.onHome,
    required this.onProfile,
    required this.onPlus,
    this.fabIcon = 'plus',
    this.fabTurns = 0,
    this.trackActive = true,
    this.darkGlass = false,
    this.hidden = false,
  });

  @override
  State<EcoBottomNav> createState() => _EcoBottomNavState();
}

class _EcoBottomNavState extends State<EcoBottomNav> {
  late double _pillLeft;
  bool _pillStretch = false;
  bool _movingRight = true;

  static double _pillLeftFor(String active) => active == 'profile' ? 222 : 8;

  @override
  void initState() {
    super.initState();
    if (!widget.trackActive) {
      _pillLeft = _pillLeftFor(widget.active);
      return;
    }

    final previous = EcoBottomNav._lastActive;
    final startActive = previous == null || previous == widget.active
        ? widget.active
        : previous;
    _pillLeft = _pillLeftFor(startActive);
    _movingRight = _pillLeftFor(widget.active) >= _pillLeft;
    EcoBottomNav._lastActive = widget.active;

    if (startActive != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pillStretch = true;
          _pillLeft = _pillLeftFor(widget.active);
        });
        _settlePill();
      });
    }
  }

  @override
  void didUpdateWidget(covariant EcoBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.trackActive) {
      final targetLeft = _pillLeftFor(widget.active);
      if (_pillLeft != targetLeft || _pillStretch) {
        setState(() {
          _pillStretch = false;
          _pillLeft = targetLeft;
        });
      }
      return;
    }

    if (oldWidget.active == widget.active) return;

    final targetLeft = _pillLeftFor(widget.active);
    _movingRight = targetLeft >= _pillLeft;
    EcoBottomNav._lastActive = widget.active;
    setState(() {
      _pillStretch = true;
      _pillLeft = targetLeft;
    });
    _settlePill();
  }

  void _settlePill() {
    Future<void>.delayed(const Duration(milliseconds: 115), () {
      if (!mounted) return;
      setState(() => _pillStretch = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomGap = math.max(30.0, bottomInset + 6.0);
    final scale = math.min(
      0.964,
      (MediaQuery.of(context).size.width - 32) / 310,
    );
    final navHeight = 106 * scale;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: navHeight + bottomGap + 8,
      child: IgnorePointer(
        ignoring: widget.hidden,
        child: AnimatedSlide(
          offset: widget.hidden ? const Offset(0, 1.05) : Offset.zero,
          duration: kEcoMotionDuration,
          curve: kEcoMotionCurve,
          child: AnimatedOpacity(
            opacity: widget.hidden ? 0 : 1,
            duration: kEcoMotionDuration,
            curve: kEcoMotionCurve,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: bottomGap,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 310,
                      height: 106,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _LiquidNavStaticLayer(
                            fabIcon: widget.fabIcon,
                            fabTurns: widget.fabTurns,
                            darkGlass: widget.darkGlass,
                            dark: widget.t.isDark,
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            left: _pillLeft,
                            top: 43,
                            width: 80,
                            height: 55,
                            // RepaintBoundary кэширует растр пилюли (4× blur
                            // bevel) — за весь 260мс слайд переключения вкладок
                            // она лишь композитится со сдвигом, а не
                            // перерисовывает blur-проходы каждый кадр.
                            child: RepaintBoundary(
                              child: _LiquidNavPill(
                                stretch: _pillStretch,
                                movingRight: _movingRight,
                                darkGlass: widget.darkGlass,
                                dark: widget.t.isDark,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 28,
                            top: 51,
                            width: 40,
                            height: 40,
                            child: _LiquidNavIcon(
                              icon:
                                  widget.active == 'home' ? 'homeFill' : 'home',
                              active: widget.active == 'home',
                              size: 40,
                              darkGlass: widget.darkGlass,
                              dark: widget.t.isDark,
                            ),
                          ),
                          Positioned(
                            left: 242,
                            top: 50,
                            width: 40,
                            height: 40,
                            child: _LiquidNavIcon(
                              icon: widget.active == 'profile'
                                  ? 'userFill'
                                  : 'user',
                              active: widget.active == 'profile',
                              size: 40,
                              darkGlass: widget.darkGlass,
                              dark: widget.t.isDark,
                            ),
                          ),
                          Positioned(
                            left: 120,
                            top: -6,
                            width: 70,
                            height: 70,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onPlus,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 35,
                            width: 104,
                            height: 71,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onHome,
                            ),
                          ),
                          Positioned(
                            left: 206,
                            top: 35,
                            width: 104,
                            height: 71,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onProfile,
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
        ),
      ),
    );
  }
}

class _LiquidNavStaticLayer extends StatelessWidget {
  final String fabIcon;
  final double fabTurns;
  final bool darkGlass;
  final bool dark;

  const _LiquidNavStaticLayer({
    required this.fabIcon,
    required this.fabTurns,
    required this.darkGlass,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 119,
            top: -9,
            width: 72,
            height: 72,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // Тёмная тема: тёмное свечение вместо белого ореола.
                      // Светлая тема: мягкая тёмная тень — белый ореол на светлом
                      // фоне был не виден, кнопка «висела» без опоры.
                      color: dark
                          ? Colors.black.withValues(alpha: 0.38)
                          : Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: dark ? 5 : 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 35,
            width: 310,
            height: 71,
            child: CustomPaint(painter: _LiquidNavShadowPainter(dark: dark)),
          ),
          Positioned(
            left: 0,
            top: 35,
            width: 310,
            height: 71,
            child: _LiquidNavBand(darkGlass: darkGlass, dark: dark),
          ),
          Positioned(
            left: 120,
            top: -6,
            width: 70,
            height: 70,
            child: _LiquidFabVisual(
              icon: fabIcon,
              turns: fabTurns,
              darkGlass: darkGlass,
              dark: dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidNavBand extends StatelessWidget {
  final bool darkGlass;
  final bool dark;

  const _LiquidNavBand({required this.darkGlass, required this.dark});

  @override
  Widget build(BuildContext context) {
    // Прозрачность бара теперь следует за ползунком «прозрачность карточек»
    // (cardOpacity) — как у обычных карточек. Базовый тон тот же, alpha из
    // слайдера. clamp снизу держит бар читаемым даже на минимуме ползунка.
    final op = context
        .select<AppStore, double>((s) => s.cardOpacity)
        .clamp(0.45, 0.97);
    return Stack(
      children: [
        ClipPath(
          clipper: _LiquidNavClipper(),
          // Блюр/искажение фона убраны — бар просто полупрозрачный тон (alpha из
          // слайдера прозрачности карточек), без backdrop-blur.
          child: Container(
            color: (dark
                    ? const Color(0xFF1F2227)
                    : (darkGlass
                        ? const Color(0xFFF7FAF9)
                        : const Color(0xFFF4F7F5)))
                .withValues(alpha: op),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _LiquidNavChromePainter())),
      ],
    );
  }
}

class _LiquidNavPill extends StatelessWidget {
  final bool stretch;
  final bool movingRight;
  final bool darkGlass;
  final bool dark;

  const _LiquidNavPill({
    required this.stretch,
    required this.movingRight,
    required this.darkGlass,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 95),
      curve: Curves.easeOutCubic,
      transformAlignment:
          movingRight ? Alignment.centerLeft : Alignment.centerRight,
      transform: Matrix4.diagonal3Values(
        stretch ? 1.14 : 1.0,
        stretch ? 0.94 : 1.0,
        1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Тёмная тема: светлое полупрозрачное выделение на тёмном баре.
            color: dark
                ? const Color(0x33FFFFFF)
                : (darkGlass
                    ? const Color(0x9EFFFFFF)
                    : const Color(0x82AFB6B6)),
            borderRadius: BorderRadius.circular(27.5),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10.4,
                right: 10.4,
                top: 2.5,
                height: 24.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.46),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(
                  painter: _RoundedGlassChromePainter(radius: 27.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidFabVisual extends StatelessWidget {
  final String icon;
  final double turns;
  final bool darkGlass;
  final bool dark;

  const _LiquidFabVisual({
    required this.icon,
    required this.turns,
    required this.darkGlass,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    // Диск «+» тоже следует за ползунком прозрачности карточек (с тем же
    // читаемым нижним порогом, что и бар).
    final op = context
        .select<AppStore, double>((s) => s.cardOpacity)
        .clamp(0.45, 0.97);
    return ClipOval(
      // Блюр/искажение фона убраны — диск «+» просто полупрозрачный тон
      // (alpha из слайдера прозрачности карточек), без backdrop-blur.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (dark
                  ? const Color(0xFF3A3E46)
                  : (darkGlass
                      ? const Color(0xFFF2F6F2)
                      : const Color(0xFFF4F7F5)))
              .withValues(alpha: op),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 11,
              top: 5,
              width: 48,
              height: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.50),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(
                painter: _RoundedGlassChromePainter(circle: true),
              ),
            ),
            // Вращение «+»→«×» меняется каждый кадр при открытии/закрытии
            // пикера. Изолируем ТОЛЬКО иконку в свой слой, иначе её поворот
            // инвалидировал бы кешированный растр стеклянного диска и каймы.
            RepaintBoundary(
              child: Transform.rotate(
                angle: turns * math.pi * 2,
                child: Icon(
                  ecoIcon(icon),
                  size: 42,
                  // Светлая тема: тёмный «+/×» — белый на светлом диске не виден.
                  color: dark
                      ? const Color(0xFFF1F1F4)
                      : (darkGlass
                          ? const Color(0xEEF4F8EB)
                          : const Color(0xFF2A2A2C)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidNavIcon extends StatelessWidget {
  final String icon;
  final bool active;
  final double size;
  final bool darkGlass;
  final bool dark;

  const _LiquidNavIcon({
    required this.icon,
    required this.active,
    required this.size,
    required this.darkGlass,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (dark) {
      // Тёмная тема: светлые иконки, активная — ярче.
      color = active ? const Color(0xFFF1F1F4) : const Color(0xA6F1F1F4);
    } else if (darkGlass) {
      color = const Color(0xFFF8F8F8);
    } else {
      // Светлая тема: тёмные иконки — на светлом стекле белые были не видны.
      color = active ? const Color(0xFF2A2A2C) : const Color(0x8C2A2A2C);
    }
    // Брендовые эко-иконки навигации (дом+лист, человек+ростки) — точные SVG из
    // Figma (олива #555F3B), варианты по состоянию: активная вкладка = ЗАЛИТАЯ
    // (home-f 117:401 / user-f 124:3341), пассивная = КОНТУРНАЯ (home-o 117:545
    // / user-o 124:3347). Плюс подсветка-«пилюля» под активной.
    // На тёмном фоне (тёмная тема / тёмное стекло) тонируем их в светлый [color]
    // с градацией active/inactive — иначе олив сливается. В обычной светлой теме
    // оставляем нативный олив ассета (colorFilter = null).
    final iconTint = (dark || darkGlass)
        ? ColorFilter.mode(color, BlendMode.srcIn)
        : null;
    if (icon == 'home' || icon == 'homeFill') {
      return SvgPicture.asset(
          active
              ? 'assets/icons/nav_home_fill.svg'
              : 'assets/icons/nav_home_line.svg',
          width: size,
          height: size,
          colorFilter: iconTint,
          fit: BoxFit.contain);
    }
    if (icon == 'user' || icon == 'userFill') {
      return SvgPicture.asset(
          active
              ? 'assets/icons/nav_user_fill.svg'
              : 'assets/icons/nav_user_line.svg',
          width: size,
          height: size,
          colorFilter: iconTint,
          fit: BoxFit.contain);
    }
    return Icon(ecoIcon(icon), size: size, color: color);
  }
}

class _LiquidNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _liquidNavPath(size);

  @override
  bool shouldReclip(_LiquidNavClipper oldClipper) => false;
}

class _LiquidNavShadowPainter extends CustomPainter {
  final bool dark;

  const _LiquidNavShadowPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _liquidNavPath(size);
    if (dark) {
      // Тёмная тема: мягкий светлый блик-контур (бар тёмный на тёмном фоне).
      canvas.drawPath(
        path.shift(const Offset(-1, -2)),
        Paint()
          ..color = const Color(0x2BFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    } else {
      // Светлая тема: тёмная мягкая тень очерчивает бар на светлом фоне, иначе
      // белое стекло сливается с фоном и панель не видно.
      canvas.drawPath(
        path.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidNavShadowPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _LiquidNavChromePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _liquidNavPath(size);
    _paintGlassBevel(canvas, path, size);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.08),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(_LiquidNavChromePainter oldDelegate) => false;
}

class _RoundedGlassChromePainter extends CustomPainter {
  final double radius;
  final bool circle;

  const _RoundedGlassChromePainter({this.radius = 0, this.circle = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );
    }
    _paintGlassBevel(canvas, path, size);
  }

  @override
  bool shouldRepaint(_RoundedGlassChromePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.circle != circle;
}

void _paintGlassBevel(Canvas canvas, Path path, Size size) {
  canvas.save();
  canvas.clipPath(path);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = const Color(0x40FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..color = const Color(0xA8FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
  );
  canvas.drawPath(
    path.shift(const Offset(-0.8, -0.9)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x14FFFFFF),
  );
  canvas.drawPath(
    path.shift(const Offset(0.8, 0.8)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xD6FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
  );
  canvas.drawPath(
    path.shift(const Offset(-0.8, -0.8)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xB8FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
  );
  canvas.restore();
}

Path _liquidNavPath(Size size) {
  final sx = size.width / 310.0;
  final sy = size.height / 71.0;
  return Path()
    ..moveTo(274.5 * sx, 0)
    ..cubicTo(294.106 * sx, 0, 310 * sx, 15.894 * sy, 310 * sx, 35.5 * sy)
    ..cubicTo(310 * sx, 55.106 * sy, 294.106 * sx, 71 * sy, 274.5 * sx, 71 * sy)
    ..lineTo(35.5 * sx, 71 * sy)
    ..cubicTo(15.894 * sx, 71 * sy, 0, 55.106 * sy, 0, 35.5 * sy)
    ..cubicTo(0, 15.894 * sy, 15.894 * sx, 0, 35.5 * sx, 0)
    // Вырез под FAB сдвинут на +3, чтобы его центр был на 155 (= центр бара и
    // центр кнопки «+»). В исходном Figma-пути вырез был на 152 — кнопка сидела
    // на ~3 ед. правее своей «колыбели».
    ..lineTo(78.2 * sx, 0)
    ..cubicTo(84.197 * sx, 0, 87.196 * sx, 0, 88.93 * sx, 0.308 * sy)
    ..cubicTo(
      95.892 * sx,
      1.544 * sy,
      95.943 * sx,
      1.573 * sy,
      100.566 * sx,
      6.923 * sy,
    )
    ..cubicTo(
      101.718 * sx,
      8.256 * sy,
      105.147 * sx,
      14.017 * sy,
      112.005 * sx,
      25.538 * sy,
    )
    ..cubicTo(
      120.724 * sx,
      40.186 * sy,
      136.716 * sx,
      50 * sy,
      155 * sx,
      50 * sy,
    )
    ..cubicTo(
      173.284 * sx,
      50 * sy,
      189.276 * sx,
      40.186 * sy,
      197.995 * sx,
      25.538 * sy,
    )
    ..cubicTo(
      204.853 * sx,
      14.017 * sy,
      208.282 * sx,
      8.256 * sy,
      209.434 * sx,
      6.923 * sy,
    )
    ..cubicTo(
      214.057 * sx,
      1.573 * sy,
      214.108 * sx,
      1.544 * sy,
      221.07 * sx,
      0.308 * sy,
    )
    ..cubicTo(222.805 * sx, 0, 225.803 * sx, 0, 231.8 * sx, 0)
    ..lineTo(274.5 * sx, 0)
    ..close();
}

/// Горизонтальная полоса дневных столбиков (шаги / вода и т.п.) — сегодня
/// справа. Подложка-капсула ([EcoTheme.band]) едет к выбранному дню; полоса
/// прокручивается и выравнивает выбранный день по правому краю видимой области
/// (ровно [_visibleCount] столбиков влезают целиком). Пунктирная линия цели и
/// её подпись — фиксированный оверлей в правом жёлобе. Высота подстраивается под
/// ВИДИМОЕ окно (потолок не ниже [minTop]) и плавно анимируется ПОСЛЕ окончания
/// горизонтальной прокрутки.
class EcoDayBarStrip extends StatefulWidget {
  /// Значения по дням (старые слева, сегодня справа).
  final List<({DateTime date, int value})> data;
  final int goal;

  /// Единица измерения подписи цели (напр. «мл»); null — без единицы (шаги).
  final String? unit;

  /// Нижний потолок шкалы: пока в видимом окне нет значений выше — верх графика
  /// зафиксирован (столбики не растягиваются на всю высоту).
  final int minTop;
  final Color barColor;
  final Color goalColor;
  final int offset;
  final ValueChanged<int> onSelect;

  const EcoDayBarStrip({
    super.key,
    required this.data,
    required this.goal,
    required this.minTop,
    required this.barColor,
    required this.goalColor,
    required this.offset,
    required this.onSelect,
    this.unit,
  });

  @override
  State<EcoDayBarStrip> createState() => _EcoDayBarStripState();
}

class _EcoDayBarStripState extends State<EcoDayBarStrip> {
  static const _barAreaH = 120.0;
  static const _weekdayGap = 4.0; // зазор между подписью дня и столбиком
  static const _weekdayH =
      16.0 + _weekdayGap; // секция подписи дня (текст+зазор)
  static const _belowH = 6.0 + 18.0 + 10.0; // отступ + число + точка «сегодня»
  // Подложка-капсула не доходит до краёв полосы: отступ сверху/снизу + зазор.
  static const _pillPadV = 8.0;
  static const _innerGap = 4.0;
  static const _contentTop = _pillPadV + _innerGap;
  static const _stripH =
      _contentTop + _weekdayH + _barAreaH + _belowH + _contentTop;
  // Правый жёлоб под подпись цели: столбики до него не доходят, выбранный день
  // выравнивается по его левому краю. Шире, когда у подписи есть единица
  // измерения («2 400 мл»): full-bleed-ленту вьюпорт EcoScreen обрезает на 16px
  // по краям, поэтому подписи нужен запас, чтобы влезть целиком в видимую зону и
  // не налезть на столбики.
  double get _rightGutter => widget.unit != null ? 78.0 : 66.0;
  static const _visibleCount = 7;
  // Запас над самым высоким столбиком (он не упирается в подпись дня).
  static const _scaleFactor = 1.10;

  final ScrollController _controller = ScrollController();
  double _viewportWidth = 0;
  double _itemExtent = 56;
  int _targetTop = 0;
  bool _topInitialized = false;

  int get _dayCount => widget.data.length;

  int get _selectedIndex =>
      _dayCount - 1 - widget.offset.clamp(0, _dayCount - 1);

  int _visibleStart() {
    final maxStart = math.max(0, _dayCount - _visibleCount);
    if (_controller.hasClients && _itemExtent > 0) {
      return (_controller.offset / _itemExtent).round().clamp(0, maxStart);
    }
    return (_selectedIndex - (_visibleCount - 1)).clamp(0, maxStart);
  }

  /// Потолок шкалы по ВИДИМЫМ значениям: максимум видимого окна, но не ниже
  /// [minTop] и не ниже цели.
  int _scaleTop() {
    final start = _visibleStart();
    var windowMax = 0;
    for (var i = start; i < start + _visibleCount && i < _dayCount; i++) {
      windowMax = math.max(windowMax, widget.data[i].value);
    }
    return math.max(widget.minTop, math.max(widget.goal, windowMax));
  }

  // После окончания горизонтальной прокрутки пересчитываем потолок по видимому
  // окну и (если изменился) запускаем плавную анимацию высоты.
  void _onScrollEnd() {
    final t = _scaleTop();
    if (t != _targetTop) setState(() => _targetTop = t);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSelected());
  }

  @override
  void didUpdateWidget(covariant EcoDayBarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offset != widget.offset) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final todayKey = AppStore.ymd();

    return LayoutBuilder(
      builder: (context, box) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        _viewportWidth = screenWidth - _rightGutter;
        _itemExtent = _viewportWidth / _visibleCount;

        if (!_topInitialized) {
          _targetTop = _scaleTop();
          _topInitialized = true;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: _targetTop * _scaleFactor,
            end: _targetTop * _scaleFactor,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, scale, _) {
            final goalY =
                _barAreaH * (1 - (widget.goal / scale).clamp(0.0, 1.0));
            return SizedBox(
              height: _stripH,
              child: OverflowBox(
                minWidth: screenWidth,
                maxWidth: screenWidth,
                minHeight: _stripH,
                maxHeight: _stripH,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: _rightGutter,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollEndNotification) _onScrollEnd();
                          return true;
                        },
                        child: SingleChildScrollView(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          child: SizedBox(
                            width: _dayCount * _itemExtent,
                            height: _stripH,
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: kEcoMotionDuration,
                                  curve: kEcoMotionCurve,
                                  left: _selectedIndex * _itemExtent + 3,
                                  top: _pillPadV,
                                  bottom: _pillPadV,
                                  width: _itemExtent - 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: t.band,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  // RepaintBoundary: ячейки-кольца растеризуются
                                  // в один кэш-слой, и плашка выбора
                                  // (AnimatedPositioned) лишь композитится поверх,
                                  // а не перерисовывает все ячейки каждый кадр.
                                  child: RepaintBoundary(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (var i = 0; i < _dayCount; i++)
                                          SizedBox(
                                            width: _itemExtent,
                                            child: _cell(
                                              i,
                                              scale: scale,
                                              todayKey: todayKey,
                                              l: l,
                                              t: t,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      // Линия цели идёт до ЛЕВОГО края телефона (как ленты дней),
                      // а справа останавливается перед подписью (жёлоб) — чтобы у
                      // числа не было лишних штрихов.
                      left: 0,
                      right: _rightGutter,
                      top: _contentTop + _weekdayH + goalY,
                      child: CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: _DayBarDashPainter(widget.goalColor),
                      ),
                    ),
                    Positioned(
                      // Подпись держим ВНУТРИ видимой зоны: full-bleed-ленту
                      // вьюпорт EcoScreen обрезает на 16px справа, поэтому при
                      // наличии единицы («мл») отступаем на 18 — иначе последняя
                      // цифра и «мл» уходили под срез.
                      right: 18,
                      top: _contentTop + _weekdayH + goalY - 8,
                      child: Text(
                        // По локали: «10 000» для ru/uz, «10,000» для en (раньше
                        // ecoFmtThousands всегда ставил пробел, даже в en). С
                        // единицей — «2 400 мл».
                        widget.unit == null
                            ? l.thousands(widget.goal)
                            : '${l.thousands(widget.goal)} ${widget.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.goalColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cell(
    int index, {
    required double scale,
    required String todayKey,
    required AppStrings l,
    required EcoTheme t,
  }) {
    final e = widget.data[index];
    final cellOffset = _dayCount - 1 - index; // дней назад
    final selected = index == _selectedIndex;
    final isToday = AppStore.ymd(e.date) == todayKey;
    final barH = e.value <= 0
        ? 0.0
        : (e.value / scale * _barAreaH).clamp(4.0, _barAreaH);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(cellOffset),
      child: Padding(
        padding: const EdgeInsets.only(top: _contentTop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.weekdayShort(e.date.weekday),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? t.ink : t.sub,
              ),
            ),
            const SizedBox(height: _weekdayGap),
            SizedBox(
              height: _barAreaH,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (barH > 0)
                    Container(
                      width: 12,
                      height: barH,
                      decoration: BoxDecoration(
                        color: widget.barColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${e.date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? t.ink : t.sub,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isToday
                    ? (selected ? t.dark : widget.barColor)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToSelected() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_targetScrollFor(widget.offset));
  }

  void _animateToSelected() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _targetScrollFor(widget.offset),
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
    );
  }

  double _targetScrollFor(int offset) {
    final safeOffset = offset.clamp(0, _dayCount - 1);
    final index = _dayCount - 1 - safeOffset;
    final aligned = (index + 1) * _itemExtent - _viewportWidth;
    final max =
        _controller.hasClients ? _controller.position.maxScrollExtent : 0.0;
    return aligned.clamp(0.0, max);
  }
}

class _DayBarDashPainter extends CustomPainter {
  final Color color;
  const _DayBarDashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DayBarDashPainter old) => old.color != color;
}

/// Lightweight six-dot wave loader — solid fills, no borders. Drives one
/// [CustomPaint] from a single controller (no extra packages, cheap on the
/// battery). Dots travel right then back on a 3s loop, staggered like the
/// original CSS keyframes.
class EcoDotsLoader extends StatefulWidget {
  final double width;
  final double dotSize;

  const EcoDotsLoader({super.key, this.width = 220, this.dotSize = 18});

  @override
  State<EcoDotsLoader> createState() => _EcoDotsLoaderState();
}

class _EcoDotsLoaderState extends State<EcoDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  // (fill colour, start delay in seconds) — last entry is drawn on top.
  static const List<(Color, double)> _dots = [
    (Color(0xFF8CC759), 0.5),
    (Color(0xFF8C6DAF), 0.4),
    (Color(0xFFEF5D74), 0.3),
    (Color(0xFFF9A74B), 0.2),
    (Color(0xFF60BEEB), 0.1),
    (Color(0xFFFBEF5A), 0.0),
  ];

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.dotSize,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => CustomPaint(
            size: Size(widget.width, widget.dotSize),
            painter: _DotsLoaderPainter(_motion.value, _dots),
          ),
        ),
      ),
    );
  }
}

class _DotsLoaderPainter extends CustomPainter {
  final double progress;
  final List<(Color, double)> dots;

  _DotsLoaderPainter(this.progress, this.dots);

  static double _easeInOut(double x) => 0.5 * (1 - math.cos(math.pi * x));

  // Hold → out → hold → back, matching the original @keyframes profile.
  static double _offset(double t, double travel) {
    if (t < 0.15) return 0;
    if (t < 0.45) return travel * _easeInOut((t - 0.15) / 0.30);
    if (t < 0.65) return travel;
    if (t < 0.95) return travel * (1 - _easeInOut((t - 0.65) / 0.30));
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final travel = size.width - size.height;
    final cy = size.height / 2;
    final paint = Paint()..isAntiAlias = true;
    for (final (color, delay) in dots) {
      var t = (progress - delay / 3) % 1.0;
      if (t < 0) t += 1;
      final cx = radius + _offset(t, travel);
      canvas.drawCircle(Offset(cx, cy), radius, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_DotsLoaderPainter old) => old.progress != progress;
}
