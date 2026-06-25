import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

const _t = EcoTheme.meadow;

// ── Shared helpers ────────────────────────────────────────────

String localizedDate(AppStrings l, [DateTime? date]) {
  final d = date ?? DateTime.now();
  return l.weekdayDayMonth(d);
}

/// Centered date pill (header of entry screens).
class DatePill extends StatelessWidget {
  final String? time;
  const DatePill({super.key, this.time});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final topInset = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topInset + 24, bottom: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
          decoration: BoxDecoration(
            color: _t.band,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            time != null ? '${localizedDate(l)} $time' : localizedDate(l),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _t.dark,
            ),
          ),
        ),
      ),
    );
  }
}

/// 3-row number spinner: dim value±step rows (tappable) around the big center.
class NumberWheel extends StatelessWidget {
  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String Function(int)? fmt;
  final double width;

  const NumberWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = -1000000000,
    this.max = 1000000000,
    this.fmt,
    this.width = double.infinity,
  });

  String _f(int v) => fmt != null ? fmt!(v) : '$v';

  @override
  Widget build(BuildContext context) {
    Widget row(int v, bool dim) => GestureDetector(
          onTap: dim ? () => onChanged(v.clamp(min, max)) : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dim ? 4 : 2),
            child: Text(
              _f(v),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dim ? 26 : 40,
                fontWeight: FontWeight.w700,
                color: dim ? const Color(0x52364025) : _t.dark,
              ),
            ),
          ),
        );
    return SizedBox(
      width: width == double.infinity ? null : width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(value - step, true),
          row(value, false),
          row(value + step, true),
        ],
      ),
    );
  }
}

/// Field row with optional icon + right widget.
class FieldRow extends StatelessWidget {
  final String? icon;
  final String label;
  final Widget right;
  final bool last;
  const FieldRow({
    super.key,
    this.icon,
    required this.label,
    required this.right,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _t.bandSoft, width: 1.5)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(ecoIcon(icon!), size: 30, color: _t.dark),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EcoColors.sub,
              ),
            ),
          ),
          right,
        ],
      ),
    );
  }
}

/// Underlined numeric input (e.g. "— уд/м").
class UnderlineInput extends StatelessWidget {
  final String? suffix;
  final String? initial;
  final double width;
  final ValueChanged<String>? onChanged;
  const UnderlineInput({
    super.key,
    this.suffix,
    this.initial,
    this.width = 70,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: width,
          child: TextField(
            controller:
                initial != null ? TextEditingController(text: initial) : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EcoColors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '—',
              contentPadding: const EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 4,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _t.olive, width: 1.5),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _t.olive, width: 1.5),
              ),
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Text(
            suffix!,
            style: const TextStyle(
              fontSize: 14,
              color: EcoColors.sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// "Заметки" field.
class NotesField extends StatelessWidget {
  const NotesField({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _t.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 20, color: EcoColors.sub),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: l.t('common.notes'),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16, color: EcoColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Отмена / Сохранить footer.
Widget actionFooter(
  BuildContext context, {
  String? cancel,
  String? save,
  required VoidCallback onSave,
}) {
  final l = context.l10nRead;
  return Positioned(
    left: 16,
    right: 16,
    bottom: 18 + MediaQuery.of(context).padding.bottom,
    child: Row(
      children: [
        Expanded(
          child: EcoBtn(
            t: _t,
            bg: _t.band,
            fg: _t.dark,
            onTap: () => Navigator.of(context).pop(),
            child: Text(cancel ?? l.t('common.cancel')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EcoBtn(
            t: _t,
            onTap: onSave,
            child: Text(save ?? l.t('common.save')),
          ),
        ),
      ],
    ),
  );
}

// ── Вода ──────────────────────────────────────────────────────

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final pct = s.waterGoal > 0 ? s.water / s.waterGoal : 0.0;
    final now = DateTime.now();
    return EcoScreen(
      t: _t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: _t,
            title: l.t('home.water'),
            onBack: () => Navigator.of(context).pop(),
            right: Icon(ecoIcon('chart'), size: 33, color: _t.dark),
          ),
          // last 7 days row with goal dotted line
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 6; i >= 0; i--)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: i == 0 ? _t.bandSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${now.subtract(Duration(days: i)).day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? EcoColors.ink : EcoColors.sub,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          EcoCard(
            t: _t,
            child: Column(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: _CupPainter(pct.clamp(0.0, 1.0))),
                ),
                const SizedBox(height: 18),
                Text(
                  '${s.water}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '/ ${s.waterGoal} ${l.unit('ml')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EcoColors.sub,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.read<AppStore>().stepWater(-250),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _t.bandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.remove, size: 24, color: _t.dark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    EcoBtn(
                      t: _t,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      onTap: () => context.read<AppStore>().stepWater(250),
                      child: Text('+ 250 ${l.unit('ml')}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  final double pct;
  _CupPainter(this.pct);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cup = Path()
      ..moveTo(w * 0.14, 0)
      ..lineTo(w * 0.86, 0)
      ..lineTo(w * 0.76, h)
      ..lineTo(w * 0.24, h)
      ..close();
    canvas.save();
    canvas.clipPath(cup);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDCEAF6),
    );
    final fillH = h * pct;
    canvas.drawRect(
      Rect.fromLTWH(0, h - fillH, w, fillH),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EcoColors.water, EcoColors.waterDeep],
        ).createShader(Rect.fromLTWH(0, h - fillH, w, fillH)),
    );
    canvas.restore();
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = EcoColors.waterDeep.withValues(alpha: 0.33),
    );
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.pct != pct;
}

// ── Состав тела ───────────────────────────────────────────────

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final currentWeight = s.weight > 0 ? s.weight : (s.weightKg ?? 0);
    final entries = _chartEntries(s, currentWeight);
    final selectedIndex = entries.isEmpty
        ? 0
        : (_selectedIndex ?? entries.length - 1).clamp(0, entries.length - 1);
    final selected = entries.isEmpty
        ? BodyMetricEntry(
            date: DateTime.now(),
            weightKg: currentWeight,
            skeletalMuscle: s.skeletalMuscle,
            bodyFat: s.bodyFat,
          )
        : entries[selectedIndex];
    final bodyWeight = selected.weightKg;
    final skeletalMuscle = selected.skeletalMuscle;
    final bodyFat = selected.bodyFat;
    final fatMass = (bodyWeight * bodyFat / 100);
    final chartPoints = entries.map((entry) => entry.weightKg).toList();
    String fmt(num v) {
      final decimal =
          l.language == AppLanguage.ru || l.language == AppLanguage.uzCyrl
              ? ','
              : '.';
      return v.toStringAsFixed(1).replaceAll('.', decimal);
    }

    void openEntry() => Navigator.of(context).pushNamed('/bodyEntry');

    return EcoScreen(
      t: _t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(
          t: _t,
          onTap: () => Navigator.of(context).pushNamed('/bodyEntry'),
          child: Text(l.t('health.enterData')),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: _t,
            title: l.t('health.bodyComposition'),
            onBack: () => Navigator.of(context).pop(),
            right: Icon(ecoIcon('chart'), size: 33, color: _t.dark),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _selectChartPoint(
                        details.localPosition,
                        box.maxWidth,
                        entries.length,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 102,
                            child: CustomPaint(
                              size: Size(box.maxWidth, 102),
                              painter: _BodyChartPainter(
                                chartPoints,
                                selectedIndex: selectedIndex,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _BodyDateTicks(
                            dates: [for (final entry in entries) entry.date],
                            selectedIndex: selectedIndex,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    l.dayMonth(selected.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _t.dark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                EcoCard(
                  t: _t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('scale', fmt(bodyWeight), l.unit('kg'), _t.dark),
                      _stat(
                        'gauge',
                        fmt(skeletalMuscle),
                        l.unit('kg'),
                        EcoColors.carb,
                      ),
                      _stat('flame', fmt(bodyFat), '%', EcoColors.fat),
                    ],
                  ),
                ),
                EcoCard(
                  t: _t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.t('health.yourBodyComposition'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(ecoIcon('bulb'), size: 30, color: EcoColors.sub),
                        ],
                      ),
                      _RangeRow(
                        label: l.t('profile.weight'),
                        value: fmt(bodyWeight),
                        unit: l.unit('kg'),
                        lo: fmt(53.5),
                        hi: fmt(72.3),
                        frac: ((bodyWeight - 48) / 30),
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        label: l.t('health.skeletalMuscle'),
                        value: fmt(skeletalMuscle),
                        unit: l.unit('kg'),
                        lo: fmt(25.8),
                        hi: fmt(28.9),
                        frac: ((skeletalMuscle - 22) / 10),
                        over: true,
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        label: l.t('health.fatMass'),
                        value: fmt(fatMass),
                        unit: l.unit('kg'),
                        lo: fmt(6.7),
                        hi: fmt(12.5),
                        frac: ((fatMass - 4) / 12),
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        label: l.t('health.bodyWater'),
                        value: fmt(55.2),
                        unit: '%',
                        lo: '50',
                        hi: '65',
                        frac: 0.5,
                        last: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String v, String u, Color c) => Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            child: Icon(ecoIcon(icon), size: 30, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: v,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' $u',
                  style: const TextStyle(fontSize: 12, color: EcoColors.sub),
                ),
              ],
            ),
          ),
        ],
      );

  void _selectChartPoint(Offset local, double width, int count) {
    if (count <= 0) return;
    final index = count == 1
        ? 0
        : ((local.dx - 10) / ((width - 20) / (count - 1))).round();
    setState(() => _selectedIndex = index.clamp(0, count - 1));
  }

  List<BodyMetricEntry> _chartEntries(AppStore s, double currentWeight) {
    final saved = s.bodyHistory.where((entry) => entry.weightKg > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (saved.length >= 7) {
      return saved.sublist(saved.length - 7);
    }
    if (saved.isNotEmpty) {
      final first = saved.first;
      final missing = 7 - saved.length;
      final generated = [
        for (var i = missing; i >= 1; i--)
          BodyMetricEntry(
            date: first.date.subtract(Duration(days: i)),
            weightKg: double.parse(
              (first.weightKg - i * 0.28).clamp(30.0, 200.0).toStringAsFixed(1),
            ),
            skeletalMuscle: double.parse(
              (first.skeletalMuscle - i * 0.04)
                  .clamp(10.0, 80.0)
                  .toStringAsFixed(1),
            ),
            bodyFat: double.parse(
              (first.bodyFat + i * 0.08).clamp(3.0, 60.0).toStringAsFixed(1),
            ),
          ),
      ];
      return [...generated, ...saved];
    }
    final base = currentWeight > 0 ? currentWeight : 66.0;
    return [
      for (var i = 6; i >= 0; i--)
        BodyMetricEntry(
          date: DateTime.now().subtract(Duration(days: i)),
          weightKg: double.parse((base - i * 0.55).toStringAsFixed(1)),
          skeletalMuscle: s.skeletalMuscle,
          bodyFat: s.bodyFat,
        ),
    ];
  }
}

class _BodyDateTicks extends StatelessWidget {
  final List<DateTime> dates;
  final int selectedIndex;

  const _BodyDateTicks({required this.dates, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox(height: 18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < dates.length; i++)
          Expanded(
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      i == selectedIndex ? FontWeight.w900 : FontWeight.w700,
                  color: i == selectedIndex ? _t.dark : EcoColors.sub,
                ),
                child: Text('${dates[i].day}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label, value, unit, lo, hi;
  final double frac;
  final VoidCallback? onTap;
  final bool over, last;
  const _RangeRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.lo,
    required this.hi,
    required this.frac,
    this.onTap,
    this.over = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = frac.clamp(0.04, 1.0);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _t.bandSoft, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 14, color: EcoColors.faint),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EcoColors.sub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: _t.bandSoft),
                  FractionallySizedBox(
                    widthFactor: p,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: over
                            ? LinearGradient(colors: [_t.dark, EcoColors.fat])
                            : null,
                        color: over ? null : _t.dark,
                      ),
                    ),
                  ),
                  // Inset (recessed) shadow — adds depth, like the macro bars.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
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
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.sub,
                ),
              ),
              Text(
                hi,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.sub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _BodyChartPainter extends CustomPainter {
  final List<double> points;
  final int selectedIndex;

  _BodyChartPainter(this.points, {required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var min = points.first;
    var max = points.first;
    for (final value in points.skip(1)) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    final span = max - min;
    if (span.abs() < 0.1) {
      min -= 3;
      max += 3;
    } else {
      final pad = span * 0.4;
      min -= pad;
      max += pad;
    }
    double x(int i) => points.length == 1
        ? size.width / 2
        : 10 + i * ((size.width - 20) / (points.length - 1));
    double y(double v) => size.height - ((v - min) / (max - min)) * size.height;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(x(i), y(points[i]));
      } else {
        path.lineTo(x(i), y(points[i]));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _t.dark,
    );
    final selected = selectedIndex.clamp(0, points.length - 1);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(x(i), y(points[i])),
        i == selected ? 5 : 3.5,
        Paint()..color = i == selected ? _t.dark : _t.olive,
      );
    }
  }

  @override
  bool shouldRepaint(_BodyChartPainter old) {
    if (old.selectedIndex != selectedIndex) return true;
    if (old.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (old.points[i] != points[i]) return true;
    }
    return false;
  }
}

// ── Ввод веса ─────────────────────────────────────────────────

class BodyEntryScreen extends StatefulWidget {
  const BodyEntryScreen({super.key});
  @override
  State<BodyEntryScreen> createState() => _BodyEntryScreenState();
}

class _BodyEntryScreenState extends State<BodyEntryScreen> {
  static const _weightMin = 30;
  static const _weightMax = 200;

  late int intv;
  late int decv;
  late double skeletal = context.read<AppStore>().skeletalMuscle;
  late double fat = context.read<AppStore>().bodyFat;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final w = store.weight > 0 ? store.weight : (store.weightKg ?? 66.0);
    intv = w.floor().clamp(_weightMin, _weightMax).toInt();
    decv = (((w - w.floor()) * 10).round() % 10).toInt();
  }

  String _fmt(num v) {
    final language = context.l10nRead.language;
    final decimal = language == AppLanguage.ru || language == AppLanguage.uzCyrl
        ? ','
        : '.';
    return v.toStringAsFixed(1).replaceAll('.', decimal);
  }

  double get _weightValue =>
      double.parse((intv + decv / 10).toStringAsFixed(1));

  Future<void> _pickMetric({
    required String title,
    required String unit,
    required double value,
    required int min,
    required int max,
    required ValueChanged<double> onSave,
  }) {
    var whole = value.floor().clamp(min, max).toInt();
    var tenth = ((value - value.floor()) * 10).round().clamp(0, 9).toInt();
    return showEcoSheet(
      context: context,
      t: _t,
      title: title,
      doneLabel: context.l10nRead.t('common.save'),
      onDone: () => setState(
        () => onSave(double.parse((whole + tenth / 10).toStringAsFixed(1))),
      ),
      body: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: SizedBox(
                width: 252,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker.builder(
                        scrollController: FixedExtentScrollController(
                          initialItem: whole - min,
                        ),
                        itemExtent: 44,
                        selectionOverlay: const EcoPickerSelectionOverlay(
                          t: _t,
                        ),
                        onSelectedItemChanged: (index) => whole = min + index,
                        childCount: max - min + 1,
                        itemBuilder: (_, index) {
                          final current = min + index;
                          return Center(
                            child: Text(
                              '$current',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 34,
                      child: Center(
                        child: Text(
                          ',',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker.builder(
                        scrollController: FixedExtentScrollController(
                          initialItem: tenth,
                        ),
                        itemExtent: 44,
                        selectionOverlay: const EcoPickerSelectionOverlay(
                          t: _t,
                        ),
                        onSelectedItemChanged: (index) => tenth = index,
                        childCount: 10,
                        itemBuilder: (_, index) {
                          return Center(
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 28,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 14,
                    color: EcoColors.sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoScreen(
      t: _t,
      footer: actionFooter(
        context,
        onSave: () {
          final store = context.read<AppStore>();
          store.saveBodyMetrics(
            weightKg: _weightValue,
            skeletalMuscle: skeletal,
            bodyFat: fat,
          );
          Navigator.of(context).pop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DatePill(time: '20:25'),
          EcoCard(
            t: _t,
            pad: 16,
            margin: const EdgeInsets.only(bottom: 14),
            child: FieldRow(
              label: l.t('health.bodyMass'),
              last: true,
              right: _MetricValueButton(
                value: _fmt(_weightValue),
                unit: l.unit('kg'),
                onTap: () => _pickMetric(
                  title: l.t('health.bodyMass'),
                  unit: l.unit('kg'),
                  value: _weightValue,
                  min: _weightMin,
                  max: _weightMax,
                  onSave: (v) {
                    intv = v.floor().clamp(_weightMin, _weightMax).toInt();
                    decv = ((v - v.floor()) * 10).round().clamp(0, 9).toInt();
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.t('health.weightAlsoProfile'),
              style: const TextStyle(
                fontSize: 12,
                color: EcoColors.sub,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          EcoCard(
            t: _t,
            pad: 16,
            child: Column(
              children: [
                FieldRow(
                  label: '${l.t('health.skeletalMuscle')} (${l.unit('kg')})',
                  right: _MetricValueButton(
                    value: _fmt(skeletal),
                    unit: l.unit('kg'),
                    onTap: () => _pickMetric(
                      title: l.t('health.skeletalMuscle'),
                      unit: l.unit('kg'),
                      value: skeletal,
                      min: 10,
                      max: 80,
                      onSave: (v) => skeletal = v,
                    ),
                  ),
                ),
                FieldRow(
                  label: '${l.t('health.bodyFat')} (%)',
                  last: true,
                  right: _MetricValueButton(
                    value: _fmt(fat),
                    unit: '%',
                    onTap: () => _pickMetric(
                      title: l.t('health.bodyFat'),
                      unit: '%',
                      value: fat,
                      min: 3,
                      max: 60,
                      onSave: (v) => fat = v,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, left: 4, right: 4),
            child: Text(
              l.t('health.bodyCompositionNote'),
              style: const TextStyle(
                fontSize: 12,
                color: EcoColors.sub,
                height: 1.45,
              ),
            ),
          ),
          const NotesField(),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _MetricValueButton extends StatelessWidget {
  final String value;
  final String unit;
  final VoidCallback onTap;

  const _MetricValueButton({
    required this.value,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 2, bottom: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _t.olive, width: 1.5)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: EcoColors.ink,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
