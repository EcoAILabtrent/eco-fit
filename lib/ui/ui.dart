import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens.dart';

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
    case 'bed':
      return Icons.bedtime_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    case 'pulse':
      return Icons.monitor_heart_outlined;
    case 'sugar':
      return Icons.bloodtype_outlined;
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
    default:
      return Icons.circle_outlined;
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
      body: Stack(
        children: [
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
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
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
    final card = Container(
      margin: margin,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: bg ?? t.card,
        borderRadius: BorderRadius.circular(t.r),
      ),
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
  final String name;
  final double size;
  final double icon;

  const EcoIconBadge({
    super.key,
    required this.t,
    required this.name,
    this.size = 36,
    this.icon = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.pill, shape: BoxShape.circle),
      child: Icon(ecoIcon(name), size: icon, color: t.dark),
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
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
    this.fontSize = 17,
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
                letterSpacing: -0.2,
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
    this.fontSize = 13,
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
        borderRadius: BorderRadius.circular(14),
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
              fontSize: 9,
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
    final sw = size.width * 0.088;
    final gap = sw * 0.55;
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < data.length; i++) {
      final r = size.width / 2 - sw / 2 - i * (sw + gap);
      if (r <= 0) continue;
      final m = data[i];
      final rect = Rect.fromCircle(center: c, radius: r);
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color = m.soft.withValues(alpha: 0.45);
      canvas.drawArc(rect, 0, math.pi * 2, false, track);
      final pct = (m.goal > 0 ? m.value / m.goal : 0).clamp(0.0, 1.0);
      if (pct > 0) {
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..color = m.color;
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * pct, false, arc);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.data != data;
}

/// Legend row next to the rings.
class MacroLegend extends StatelessWidget {
  final EcoTheme t;
  final List<({String label, int value, int goal, Color color})> items;

  const MacroLegend({super.key, required this.t, required this.items});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 2),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                          TextSpan(text: ' /${m.goal} ${l.unit('g')}'),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 13,
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

/// Calorie tracker block: "1227 /2045 ккал" + bar + scale + zone legend.
class CalorieTrack extends StatelessWidget {
  final EcoTheme t;
  final int value;
  final int goal;
  final int max;
  final int zoneLo;
  final int zoneHi;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$value',
                style: const TextStyle(color: EcoColors.ink),
              ),
              TextSpan(text: ' /$goal ${l.unit('kcal')}'),
            ],
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EcoColors.sub,
          ),
        ),
        const SizedBox(height: 8),
        ValueBar(
          t: t,
          value: value.toDouble(),
          max: max.toDouble(),
          color: EcoColors.cal,
          soft: EcoColors.calSoft,
          zoneLo: zoneLo.toDouble(),
          zoneHi: zoneHi.toDouble(),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E2E30),
              ),
            ),
            Text(
              '$max',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E2E30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 14,
              height: 13,
              decoration: BoxDecoration(
                color: t.dark,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${l.t('common.targetRange')} · $zoneLo–$zoneHi ${l.unit('cal')}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: EcoColors.sub,
              ),
            ),
          ],
        ),
      ],
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
}) {
  final l = context.l10nRead;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      decoration: BoxDecoration(
        color: t.band,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x61121A08),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
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
                  fontSize: 15,
                  onTap: () => Navigator.of(sheetCtx).pop(),
                  child: Text(l.t('common.cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoBtn(
                  t: t,
                  height: 46,
                  fontSize: 15,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onDone();
                  },
                  child: Text(l.t('common.done')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == value ? t.dark : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == value ? t.pill : t.dark,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom navigation: notched band (Figma "Subtract" path) + circular FAB.
class EcoBottomNav extends StatelessWidget {
  final EcoTheme t;
  final String active; // 'home' | 'profile'
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback onPlus;
  final String fabIcon;

  const EcoBottomNav({
    super.key,
    required this.t,
    required this.active,
    required this.onHome,
    required this.onProfile,
    required this.onPlus,
    this.fabIcon = 'plus',
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
                      size: 28,
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
                      size: 26,
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
