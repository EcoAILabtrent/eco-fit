import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';

const _enableAmbientMotion = bool.fromEnvironment('ECO_ENABLE_AMBIENT_MOTION');

/// Единый переход открытия/закрытия экрана: горизонтальный iOS-слайд (нижний
/// экран уезжает с параллаксом, новый приезжает справа), одинаковая длительность
/// в обе стороны ([kEcoMotionDuration]). Используется ВЕЗДЕ вместо
/// MaterialPageRoute, чтобы все переходы были идентичными и быстрыми.
class EcoPageRoute<T> extends PageRouteBuilder<T> {
  EcoPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: kEcoMotionDuration,
          reverseTransitionDuration: kEcoMotionDuration,
          transitionsBuilder: _ecoSlideTransition,
        );
}

Widget _ecoSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return CupertinoPageTransition(
    primaryRouteAnimation: animation,
    secondaryRouteAnimation: secondaryAnimation,
    linearTransition: false,
    child: child,
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
              child: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad ? 16 : 0),
                  child: child,
                ),
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
      padding: EdgeInsets.only(top: topInset + 18, bottom: 18),
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
            ),
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
                BoxShadow(
                  color: Color(0x34FFFFFF),
                  blurRadius: 18,
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
    this.margin,
    this.solid = false,
    this.blur,
  });

  @override
  Widget build(BuildContext context) {
    final card = EcoGlassSurface(
      t: t,
      margin: margin,
      padding: EdgeInsets.all(pad),
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

  const EcoCardHead({
    super.key,
    required this.t,
    required this.icon,
    required this.title,
    this.right,
    this.mb = 16,
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
              style: const TextStyle(
                fontSize: 18,
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
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 125),
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg ?? t.dark,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: disabled ? null : onTap,
          child: Container(
            height: height,
            padding: padding,
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: TextStyle(
                // Кнопка по умолчанию тёмная (bg t.dark) -> текст светлый в обеих
                // темах (t.onDark). Раньше t.pill в тёмной теме был тёмным и текст
                // сливался с кнопкой.
                color: fg ?? t.onDark,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
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
    final displayUnit = unit ?? context.l10n.unit('cal');
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
    return CustomPaint(
        size: Size.square(size), painter: _RingsPainter(data, t));
  }
}

class _RingsPainter extends CustomPainter {
  final List<MacroRingData> data;
  final EcoTheme t;
  _RingsPainter(this.data, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final sw = w * 0.10; // grey groove thickness
    final aw =
        sw * 0.66; // colour arc thickness (narrower → grey shows around it)
    final gap = w * 0.048;
    final c = Offset(w / 2, w / 2);
    // Канавка колец = трек темы (как у полос прогресса): в светлой теме тот же
    // серый, в тёмной — светлая полупрозрачная канавка.
    final trackBase = t.track;
    for (var i = 0; i < data.length; i++) {
      final r = w / 2 - sw / 2 - 4 - i * (sw + gap);
      if (r <= 0) continue;
      final m = data[i];
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
      final innerR = math.max(0.0, r - sw / 2);
      // Намёк на утопленность канавки — тонкая чёткая кромка у внутреннего края,
      // без MaskFilter.blur и clipPath. Раньше тут было 3 offscreen-прохода на
      // 3 кольца главной (а в дейвью — на 30 ячейках полоски дней: главная
      // стоимость растра колец и фриза открытия Dayview). Чёткая кромка почти
      // неотличима на 168px и невидима на 48px, но рисуется практически даром.
      if (innerR > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: innerR + 0.75),
          0,
          math.pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x22000000),
        );
      }
      // Colour progress arc — narrower, rounded caps, riding in the groove.
      final pct = (m.goal > 0 ? m.value / m.goal : 0).clamp(0.0, 1.0);
      if (pct > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * pct,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = aw
            ..strokeCap = StrokeCap.round
            ..color = m.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) {
    if (old.t != t || old.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      if (old.data[i] != data[i]) return true; // MacroRingData == по значению
    }
    return false;
  }
}

/// Legend next to the rings (dot on the left, text left-aligned).
class MacroLegend extends StatelessWidget {
  final EcoTheme t;
  final List<({String label, int value, int goal, Color color})> items;

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
            padding: const EdgeInsets.only(bottom: 14),
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
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${m.value}',
                            style: TextStyle(
                              color: t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' /${m.goal} ${l.unit('cal')}'),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: t.sub,
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
}

/// Progress scale with target/overflow logic.
/// • Solid colour fills up to min(value, target); a sharp black marker sits at
///   the target; the remainder is a light tint of the colour, or — on overflow
///   — a darker tint extending past the target.
/// • Target label is always green; real label is dark ink.
/// • Normal (value ≤ target): target on top-right, real below at the fill end.
/// • Overflow (value > target): they swap — real on top-right, green target
///   moves down to its (left-shifted) marker.
class ProgressScale extends StatelessWidget {
  final EcoTheme t;
  final double value;
  final double target;
  final Color color;
  final double barHeight;
  final String unit;
  final String label;
  final bool animateFromZero;

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
                SizedBox(
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
                      over ? realLbl() : lbl(targetTxt, EcoColors.statusGood),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
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
                      // Solid fill up to min(value, target).
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: solidW.clamp(0.0, w),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(999),
                              right: Radius.circular(over ? 0 : 999),
                            ),
                          ),
                        ),
                      ),
                      // Inset (recessed) shadow on the track — adds depth.
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

  static const _brown = EcoColors.cal;

  const CalorieTrack({
    super.key,
    required this.t,
    required this.value,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ProgressScale(
      t: t,
      value: value.toDouble(),
      target: goal.toDouble(),
      color: _brown,
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

  const EcoPickerSelectionOverlay({
    super.key,
    required this.t,
    this.radius = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    color: Colors.white.withValues(alpha: 0.10),
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

  Widget _wheel({
    required FixedExtentScrollController controller,
    int? childCount,
    required ValueChanged<int> onSelected,
    required String Function(int) label,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 40,
      selectionOverlay: EcoPickerSelectionOverlay(t: widget.t),
      onSelectedItemChanged: onSelected,
      childCount: childCount,
      itemBuilder: (_, index) => Center(
        child: Text(
          label(index),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: widget.t.ink,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _wheel(
            controller: _dayCtrl,
            childCount: null, // бесконечный барабан: до 1 — последнее число
            onSelected: (i) => setState(() {
              _day = i % _daysInMonth + 1;
              _emit();
            }),
            label: (i) => '${i % _daysInMonth + 1}',
          ),
        ),
        Expanded(
          flex: 5,
          child: _wheel(
            controller: _monthCtrl,
            childCount: null, // бесконечный барабан: до января — декабрь
            onSelected: (i) => setState(() {
              _month = i % 12 + 1;
              _syncDayAndEmit();
            }),
            label: (i) => widget.monthNames[i % 12],
          ),
        ),
        Expanded(
          flex: 4,
          child: _wheel(
            controller: _yearCtrl,
            childCount: widget.maxYear - widget.minYear + 1,
            onSelected: (i) => setState(() {
              _year = widget.minYear + i;
              _syncDayAndEmit();
            }),
            label: (i) => '${widget.minYear + i}',
          ),
        ),
      ],
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
class EcoSegmented extends StatelessWidget {
  final EcoTheme t;
  final List<String> options;
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 115),
              curve: Curves.easeOutCubic,
              alignment: _alignmentFor(value),
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.dark,
                    borderRadius: BorderRadius.circular(999),
                    // Liquid-glass: яркий кант + мягкая тень (как у выделения пикера).
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  // Верхний блик-сияние.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      heightFactor: 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.30),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 85),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: i == value ? t.onDark : t.ink,
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
    );
  }

  Alignment _alignmentFor(int index) {
    if (options.length <= 1) return Alignment.center;
    final x = -1 + 2 * (index / (options.length - 1));
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
                            left: 32.6,
                            top: 54.6,
                            width: 30.8,
                            height: 30.8,
                            child: _LiquidNavIcon(
                              icon:
                                  widget.active == 'home' ? 'homeFill' : 'home',
                              active: widget.active == 'home',
                              size: 30.8,
                              darkGlass: widget.darkGlass,
                              dark: widget.t.isDark,
                            ),
                          ),
                          Positioned(
                            left: 246.65,
                            top: 55.65,
                            width: 29.7,
                            height: 29.7,
                            child: _LiquidNavIcon(
                              icon: widget.active == 'profile'
                                  ? 'userFill'
                                  : 'user',
                              active: widget.active == 'profile',
                              size: 29.7,
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
    final op =
        context.select<AppStore, double>((s) => s.cardOpacity).clamp(0.45, 0.97);
    return Stack(
      children: [
        ClipPath(
          clipper: _LiquidNavClipper(),
          // Навигация закреплена, контент скроллит под ней -> BackdropFilter
          // пересчитывался каждый кадр. Статичный плотный тон убирает покадровый
          // блюр; форму и блик дают clipper + chrome-painter поверх.
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
    final op =
        context.select<AppStore, double>((s) => s.cardOpacity).clamp(0.45, 0.97);
    return ClipOval(
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
            // инвалидировал бы кешированный растр стеклянного диска и каймы
            // (_paintGlassBevel с 4× MaskFilter.blur) на каждом кадре.
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
    // «Домик» рисуем своим painter'ом — у Material даже у _rounded углы крыши и
    // выреза недостаточно мягкие. Кастомная форма со скруглёнными вершинами.
    if (icon == 'home' || icon == 'homeFill') {
      return CustomPaint(
        size: Size.square(size),
        painter: _HomeIconPainter(color: color, filled: icon == 'homeFill'),
      );
    }
    return Icon(ecoIcon(icon), size: size, color: color);
  }
}

/// Строит замкнутый путь по вершинам [pts] со скруглением каждого угла. Радиус
/// общий [r] либо индивидуальный на вершину через [radii]; ужимается до
/// половины короткой смежной стороны.
Path _roundedPolygonPath(List<Offset> pts, double r, {List<double>? radii}) {
  final path = Path();
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final v1 = p0 - p1;
    final v2 = p2 - p1;
    final l1 = v1.distance;
    final l2 = v2.distance;
    final rr = math.min(radii != null ? radii[i] : r, math.min(l1, l2) / 2);
    final a = p1 + v1 / l1 * rr;
    final b = p1 + v2 / l2 * rr;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(p1.dx, p1.dy, b.dx, b.dy);
  }
  path.close();
  return path;
}

/// «Домик» 1:1 по референсу: острая крыша-треугольник со скруглённым коньком и
/// маленькими «лапками»-карнизами, под ней корпус (уже крыши) с аркой-дверью.
/// Пропорции исходной картинки 450×396 сохранены (вписан по ширине, центр по Y).
/// [filled] — сплошная заливка (активная вкладка) или контур (неактивная).
class _HomeIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  const _HomeIconPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    const aspect = 450 / 396; // w/h исходной иконки
    final dw = size.width;
    final dh = size.width / aspect;
    final oy = (size.height - dh) / 2; // вертикальное центрирование
    Offset p(double x, double y) => Offset(x * dw, oy + y * dh);
    double ry(double y) => oy + y * dh;

    // Крыша — скруглённый треугольник: мягкий конёк сверху, маленькие
    // скруглённые «лапки» на карнизах.
    final roof = _roundedPolygonPath(
      [
        p(0.50, 0.04), // конёк
        p(0.95, 0.52), // правый карниз («лапка»)
        p(0.05, 0.52), // левый карниз («лапка»)
      ],
      0,
      radii: [0.10 * dw, 0.05 * dw, 0.05 * dw],
    );
    // Корпус — скруглённый прямоугольник, уже крыши: карнизы выступают «лапками».
    final body = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0.16 * dw,
          ry(0.44),
          0.84 * dw,
          ry(0.965),
          topLeft: Radius.circular(0.04 * dw),
          topRight: Radius.circular(0.04 * dw),
          bottomLeft: Radius.circular(0.05 * dw),
          bottomRight: Radius.circular(0.05 * dw),
        ),
      );
    // Дверь-арка по центру снизу: выходит за нижний край (вырез открыт снизу).
    final door = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0.39 * dw,
          ry(0.62),
          0.61 * dw,
          ry(1.05),
          topLeft: Radius.circular(0.065 * dw),
          topRight: Radius.circular(0.065 * dw),
        ),
      );

    var shape = Path.combine(PathOperation.union, roof, body);
    shape = Path.combine(PathOperation.difference, shape, door);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (filled) {
      canvas.drawPath(shape, paint);
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07 * dw
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(shape, paint);
    }
  }

  @override
  bool shouldRepaint(_HomeIconPainter old) =>
      old.color != color || old.filled != filled;
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
  // выравнивается по его левому краю.
  static const _rightGutter = 46.0;
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
                      left: 16,
                      right: _rightGutter,
                      top: _contentTop + _weekdayH + goalY,
                      child: CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: _DayBarDashPainter(widget.goalColor),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: _contentTop + _weekdayH + goalY - 8,
                      child: Text(
                        // По локали: «10 000» для ru/uz, «10,000» для en (раньше
                        // ecoFmtThousands всегда ставил пробел, даже в en).
                        l.thousands(widget.goal),
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
