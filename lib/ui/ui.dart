import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens.dart';

const _enableAmbientMotion = bool.fromEnvironment('ECO_ENABLE_AMBIENT_MOTION');

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
      return Icons.add;
    case 'close':
      return Icons.close;
    case 'home':
      return Icons.home_outlined;
    case 'homeFill':
      return Icons.home;
    case 'user':
      return Icons.person_outline;
    case 'userFill':
      return Icons.person;
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
      duration: const Duration(seconds: 26),
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

  const EcoScreen({
    super.key,
    required this.t,
    required this.child,
    this.footer,
    this.pad = true,
  });

  @override
  Widget build(BuildContext context) {
    // Scaffold gives Texts a Material ancestor (otherwise Flutter renders the
    // yellow-underline debug style) and SafeArea keeps content off the status
    // bar. The footer stays outside SafeArea so the nav band hugs the bottom.
    return Scaffold(
      backgroundColor: t.bg,
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(child: EcoGlassBackground(t: t)),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
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
              child: Icon(Icons.chevron_left, size: 30, color: EcoColors.ink),
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

/// Без живого backdrop-блюра тонкая (≈20%) заливка читалась бы прозрачной.
/// Поднимаем непрозрачность до матового уровня — карточка остаётся «стеклом»,
/// но без покадрового размытия фона при скролле.
Color _frostFill(Color c) => c.a >= 0.5 ? c : c.withValues(alpha: 0.5);

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
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(t.r);
    // Раньше «матовость» давал BackdropFilter (живое размытие фона) — он
    // пересчитывался каждый кадр при скролле и был главным источником лагов.
    // Заменяем на статичную плотную заливку + RepaintBoundary, чтобы карточка
    // кэшировалась как готовый слой и не перерисовывалась при прокрутке.
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
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: _frostFill(bg ?? t.card),
              borderRadius: radius,
              border: Border.all(color: t.glassBorder),
            ),
            child: child,
          ),
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

  const EcoCard({
    super.key,
    required this.t,
    required this.child,
    this.onTap,
    this.bg,
    this.pad = 20,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final card = EcoGlassSurface(
      t: t,
      margin: margin,
      padding: EdgeInsets.all(pad),
      bg: bg,
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
    // Liquid-glass (frosted) badge — same treatment as the dish "favorite"
    // button: blurred backdrop + translucent white tint, rim highlight, shadow.
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Бейдж и так на 60–92% непрозрачно-белый, сквозь него почти ничего не
      // видно — убираем дорогой BackdropFilter и чуть поднимаем заливку, вид
      // практически не меняется.
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.78),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Icon(
            iconData ?? ecoIcon(name ?? ''),
            size: icon,
            color: t.dark,
          ),
        ),
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
      duration: const Duration(milliseconds: 250),
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
                color: fg ?? t.pill,
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
          color: color ?? t.dark,
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
              color: t.dark,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayUnit,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: t.dark.withValues(alpha: 0.75),
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
}

/// Concentric macro progress rings (carbs outer, fats middle, protein inner).
class MacroRings extends StatelessWidget {
  final double size;
  final List<MacroRingData> data;

  const MacroRings({super.key, required this.size, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _RingsPainter(data));
  }
}

class _RingsPainter extends CustomPainter {
  final List<MacroRingData> data;
  _RingsPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final sw = w * 0.10; // grey groove thickness
    final aw =
        sw * 0.66; // colour arc thickness (narrower → grey shows around it)
    final gap = w * 0.048;
    final c = Offset(w / 2, w / 2);
    const trackBase = Color(0x4A686868);
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
      final outerR = r + sw / 2;
      final innerR = math.max(0.0, r - sw / 2);
      final ringPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: outerR))
        ..addOval(Rect.fromCircle(center: c, radius: innerR));
      canvas.save();
      canvas.clipPath(ringPath);
      canvas.drawArc(
        rect.shift(const Offset(0, -3)),
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = const Color(0x26000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.restore();
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
  bool shouldRepaint(_RingsPainter old) => old.data != data;
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
                            style: const TextStyle(
                              color: EcoColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' /${m.goal} ${l.unit('cal')}'),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: EcoColors.sub,
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

/// Horizontal value bar with optional target zone marker.
class ValueBar extends StatelessWidget {
  final EcoTheme t;
  final double value;
  final double max;
  final Color color;
  final Color? soft;
  final double? zoneLo;
  final double? zoneHi;
  final double height;

  const ValueBar({
    super.key,
    required this.t,
    required this.value,
    required this.max,
    required this.color,
    this.soft,
    this.zoneLo,
    this.zoneHi,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (max > 0 ? value / max : 0).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              children: [
                Container(color: soft ?? Colors.black.withValues(alpha: 0.06)),
                Container(
                  width: box.maxWidth * pct,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (zoneLo != null && zoneHi != null)
                  Positioned(
                    left: box.maxWidth * (zoneLo! / max),
                    width: box.maxWidth * ((zoneHi! - zoneLo!) / max),
                    top: 0,
                    bottom: 0,
                    child: Container(color: t.dark.withValues(alpha: 0.85)),
                  ),
              ],
            );
          },
        ),
      ),
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
  final double value;
  final double target;
  final Color color;
  final double barHeight;
  final String unit;
  final String label;
  final bool animateFromZero;

  const ProgressScale({
    super.key,
    required this.value,
    required this.target,
    required this.color,
    this.barHeight = 16,
    this.unit = '',
    this.label = '',
    this.animateFromZero = false,
  });

  String _fmt(double n) {
    final r = (n * 10).round() / 10;
    final s = r == r.roundToDouble()
        ? r.toInt().toString()
        : r.toString().replaceAll('.', ',');
    return unit.isEmpty ? s : '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animateFromZero ? 0 : value, end: value),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final over = animatedValue > target;
        final total = math.max(animatedValue, math.max(target, 1.0));
        final light = Color.lerp(color, Colors.white, 0.62)!;
        final darker = Color.lerp(color, Colors.black, 0.28)!;
        final realTxt = _fmt(value);
        final targetTxt = _fmt(target);
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
        Widget realLbl() => Opacity(
              opacity: realOpacity,
              child: lbl(realTxt, EcoColors.ink),
            );

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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: EcoColors.ink,
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
  final int max;
  final int zoneLo;
  final int zoneHi;

  static const _brown = EcoColors.cal;

  const CalorieTrack({
    super.key,
    required this.t,
    required this.value,
    required this.goal,
    this.max = 2800,
    this.zoneLo = 1970,
    this.zoneHi = 2200,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ProgressScale(
      value: value.toDouble(),
      target: goal.toDouble(),
      color: _brown,
      unit: l.unit('kcal'),
      label: 'Общее количество',
    );
  }
}

/// Folder-style tabs ("Избранное / Мои продукты / Мои блюда").
class FolderTabs extends StatelessWidget {
  final EcoTheme t;
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onChanged;

  const FolderTabs({
    super.key,
    required this.t,
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.fromLTRB(
                  8,
                  i == active ? 14 : 10,
                  8,
                  i == active ? 18 : 14,
                ),
                decoration: BoxDecoration(
                  color: i == active ? t.card : Colors.transparent,
                  borderRadius: i == active
                      ? BorderRadius.only(
                          topLeft: Radius.circular(t.r),
                          topRight: Radius.circular(t.r),
                        )
                      : BorderRadius.zero,
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: i == active ? FontWeight.w700 : FontWeight.w600,
                    color: i == active ? EcoColors.ink : EcoColors.sub,
                  ),
                ),
              ),
            ),
          ),
      ],
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
      bg: t.band,
      blur: 18,
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
              color: t.dark,
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

  void _clampDayAndEmit() {
    final maxD = _daysInMonth;
    if (_day > maxD) {
      _day = maxD;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dayCtrl.hasClients) _dayCtrl.jumpToItem(_day - 1);
      });
    }
    _emit();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int childCount,
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: EcoColors.ink,
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
            childCount: _daysInMonth,
            onSelected: (i) => setState(() {
              _day = i + 1;
              _emit();
            }),
            label: (i) => '${i + 1}',
          ),
        ),
        Expanded(
          flex: 5,
          child: _wheel(
            controller: _monthCtrl,
            childCount: 12,
            onSelected: (i) => setState(() {
              _month = i + 1;
              _clampDayAndEmit();
            }),
            label: (i) => widget.monthNames[i],
          ),
        ),
        Expanded(
          flex: 4,
          child: _wheel(
            controller: _yearCtrl,
            childCount: widget.maxYear - widget.minYear + 1,
            onSelected: (i) => setState(() {
              _year = widget.minYear + i;
              _clampDayAndEmit();
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

Future<T?> showEcoChoicePopup<T>({
  required BuildContext context,
  required EcoTheme t,
  required GlobalKey anchorKey,
  required List<EcoChoiceOption<T>> options,
  required T selected,
  double width = 218,
}) {
  final l = context.l10nRead;
  final media = MediaQuery.of(context);
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final anchorOffset =
      anchorBox?.localToGlobal(Offset.zero) ?? Offset(media.size.width - 24, 0);
  final anchorSize = anchorBox?.size ?? const Size(44, 44);
  final popupWidth = width.clamp(170.0, media.size.width - 24);
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
    barrierColor: const Color(0x2F14180C),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (dialogCtx, animation, _, __) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    bg: t.band.withValues(alpha: 0.88),
                    blur: 20,
                    borderRadius: BorderRadius.circular(20),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.28),
                        blurRadius: 18,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.62))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
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
                      color: t.dark,
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: t.dark,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: t.dark.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 16, color: t.pill),
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
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              alignment: _alignmentFor(value),
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.dark,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
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
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: i == value ? t.pill : t.dark,
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
    Future<void>.delayed(const Duration(milliseconds: 230), () {
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
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            opacity: widget.hidden ? 0 : 1,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
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
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutCubic,
                            left: _pillLeft,
                            top: 43,
                            width: 80,
                            height: 55,
                            child: _LiquidNavPill(
                              stretch: _pillStretch,
                              movingRight: _movingRight,
                              darkGlass: widget.darkGlass,
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

  const _LiquidNavStaticLayer({
    required this.fabIcon,
    required this.fabTurns,
    required this.darkGlass,
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
                      color: Colors.white.withValues(alpha: 0.42),
                      blurRadius: 28,
                      spreadRadius: 5,
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
            child: CustomPaint(painter: _LiquidNavShadowPainter()),
          ),
          Positioned(
            left: 0,
            top: 35,
            width: 310,
            height: 71,
            child: _LiquidNavBand(darkGlass: darkGlass),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidNavBand extends StatelessWidget {
  final bool darkGlass;

  const _LiquidNavBand({required this.darkGlass});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: _LiquidNavClipper(),
          // Навигация закреплена, контент скроллит под ней -> BackdropFilter
          // пересчитывался каждый кадр. Статичный плотный тон убирает покадровый
          // блюр; форму и блик дают clipper + chrome-painter поверх.
          child: Container(
            color:
                darkGlass ? const Color(0xC2F7FAF9) : const Color(0x88F7FAF9),
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

  const _LiquidNavPill({
    required this.stretch,
    required this.movingRight,
    required this.darkGlass,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
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
            color:
                darkGlass ? const Color(0x9EFFFFFF) : const Color(0x82AFB6B6),
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

  const _LiquidFabVisual({
    required this.icon,
    required this.turns,
    required this.darkGlass,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              darkGlass ? const Color(0xC8F2F6F2) : const Color(0x8AAEB6B6),
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
              Transform.rotate(
                angle: turns * math.pi * 2,
                child: Icon(
                  ecoIcon(icon),
                  size: 42,
                  color: darkGlass
                      ? const Color(0xEEF4F8EB)
                      : const Color(0xFFFBFBFC),
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

  const _LiquidNavIcon({
    required this.icon,
    required this.active,
    required this.size,
    required this.darkGlass,
  });

  @override
  Widget build(BuildContext context) {
    final color = darkGlass
        ? const Color(0xFFF8F8F8)
        : (active ? const Color(0xFFFBFBFC) : const Color(0xD1FBFBFC));
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
  @override
  void paint(Canvas canvas, Size size) {
    final path = _liquidNavPath(size);
    canvas.drawPath(
      path.shift(const Offset(-1, -2)),
      Paint()
        ..color = const Color(0x2BFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(_LiquidNavShadowPainter oldDelegate) => false;
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
      ..strokeWidth = 30
      ..color = const Color(0x5CFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
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
    ..lineTo(75.2 * sx, 0)
    ..cubicTo(81.197 * sx, 0, 84.196 * sx, 0, 85.93 * sx, 0.308 * sy)
    ..cubicTo(
      92.892 * sx,
      1.544 * sy,
      92.943 * sx,
      1.573 * sy,
      97.566 * sx,
      6.923 * sy,
    )
    ..cubicTo(
      98.718 * sx,
      8.256 * sy,
      102.147 * sx,
      14.017 * sy,
      109.005 * sx,
      25.538 * sy,
    )
    ..cubicTo(
      117.724 * sx,
      40.186 * sy,
      133.716 * sx,
      50 * sy,
      152 * sx,
      50 * sy,
    )
    ..cubicTo(
      170.284 * sx,
      50 * sy,
      186.276 * sx,
      40.186 * sy,
      194.995 * sx,
      25.538 * sy,
    )
    ..cubicTo(
      201.853 * sx,
      14.017 * sy,
      205.282 * sx,
      8.256 * sy,
      206.434 * sx,
      6.923 * sy,
    )
    ..cubicTo(
      211.057 * sx,
      1.573 * sy,
      211.108 * sx,
      1.544 * sy,
      218.07 * sx,
      0.308 * sy,
    )
    ..cubicTo(219.805 * sx, 0, 222.803 * sx, 0, 228.8 * sx, 0)
    ..lineTo(274.5 * sx, 0)
    ..close();
}

/// Bottom navigation: notched band (Figma "Subtract" path) + circular FAB.
// ignore: unused_element
class _OldEcoBottomNav extends StatelessWidget {
  final EcoTheme t;
  final String active; // 'home' | 'profile'
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback onPlus;
  final String fabIcon;

  const _OldEcoBottomNav({
    required this.t,
    required this.active,
    required this.onHome,
    required this.onProfile,
    required this.onPlus,
    required this.fabIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Full-bleed band: the colour runs edge-to-edge and down to the very
    // bottom of the screen; icons and the FAB sit ABOVE the system-button
    // inset, so nothing overlaps the Android navigation buttons.
    final bandH = 61.0 + bottomInset;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: bandH + 30 + 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft fade so scrolling content dissolves into the band area.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      t.bg.withValues(alpha: 0),
                      t.bg.withValues(alpha: 0.92),
                      t.bg,
                    ],
                    stops: const [0.0, 0.35, 0.55],
                  ),
                ),
              ),
            ),
          ),
          // The notched band, flush to screen edges and bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bandH,
            child: CustomPaint(painter: _BandPainter(t.band)),
          ),
          // Icons row — above the system-button inset.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: 61,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onHome,
                    child: Icon(
                      ecoIcon(active == 'home' ? 'homeFill' : 'home'),
                      size: 42,
                      color: t.dark,
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onProfile,
                    child: Icon(
                      ecoIcon(active == 'profile' ? 'userFill' : 'user'),
                      size: 39,
                      color: t.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FAB dips 34px into the band's notch.
          Positioned(
            left: 0,
            right: 0,
            bottom: bandH - 34,
            child: Center(
              child: GestureDetector(
                onTap: onPlus,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: t.dark,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.bg, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D28321E),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(ecoIcon(fabIcon), size: 30, color: t.pill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Figma "Subtract" band path (370×61 design), full-bleed variant: the
/// notched top section is drawn in the top 61px, then the colour is flooded
/// down to the bottom of the canvas (over the system-inset strip), squaring
/// off the bottom corners.
class _BandPainter extends CustomPainter {
  final Color color;
  _BandPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 370.0;
    final sy = 1.0; // notch section is always 61 logical px tall
    final p = Path()
      ..moveTo(370 * sx, 41 * sy)
      ..cubicTo(370 * sx, 52 * sy, 361 * sx, 61 * sy, 350 * sx, 61 * sy)
      ..lineTo(20 * sx, 61 * sy)
      ..cubicTo(9 * sx, 61 * sy, 0, 52 * sy, 0, 41 * sy)
      ..lineTo(0, 20 * sy)
      ..cubicTo(0, 9 * sy, 9 * sx, 0, 20 * sx, 0)
      ..lineTo(125 * sx, 0)
      ..cubicTo(136 * sx, 0, 144.6 * sx, 9.5 * sy, 149.9 * sx, 19.2 * sy)
      ..cubicTo(156.7 * sx, 31.6 * sy, 169.9 * sx, 40 * sy, 185 * sx, 40 * sy)
      ..cubicTo(
        200.1 * sx,
        40 * sy,
        213.3 * sx,
        31.6 * sy,
        220.1 * sx,
        19.2 * sy,
      )
      ..cubicTo(225.4 * sx, 9.5 * sy, 234 * sx, 0, 245 * sx, 0)
      ..lineTo(350 * sx, 0)
      ..cubicTo(361 * sx, 0, 370 * sx, 9 * sy, 370 * sx, 20 * sy)
      ..close();
    final paint = Paint()..color = color;
    canvas.drawPath(p, paint);
    // Flood below the notch to the screen edge (covers the path's rounded
    // bottom corners and the system navigation inset).
    if (size.height > 41 * sy) {
      canvas.drawRect(
        Rect.fromLTRB(0, 41 * sy, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BandPainter old) => old.color != color;
}
