import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../nutrition/energy.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

// Единые акценты состава тела: иконка и полоса прогресса одного цвета.
// Вес остаётся тёмным (t.dark) и здесь не задаётся.
const _kMuscleColor = EcoColors.prot; // скелетная мускулатура — зелёный
const _kFatColor = Color(0xFFE8B53A); // жировая ткань и % жира — жёлтый
const _kWaterColor = EcoColors.water; // вода — голубой

// ── Shared helpers ────────────────────────────────────────────

/// Centered date pill (header of entry screens).
class DatePill extends StatelessWidget {
  final DateTime? date;
  final VoidCallback? onTap;
  const DatePill({super.key, this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final topInset = MediaQuery.of(context).padding.top;
    final d = date ?? DateTime.now();
    return Padding(
      padding: EdgeInsets.only(top: topInset + 24, bottom: 18),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            decoration: BoxDecoration(
              color: t.band,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Только дата, без дня недели и времени.
                Text(
                  '${l.dayMonth(d)} ${d.year}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_calendar_outlined,
                    size: 18,
                    color: t.ink,
                  ),
                ],
              ],
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
                color: dim ? const Color(0x52364025) : t.ink,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(ecoIcon(icon!), size: 30, color: t.ink),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.sub,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '—',
              contentPadding: const EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 4,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.olive, width: 1.5),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.olive, width: 1.5),
              ),
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Text(
            suffix!,
            style: TextStyle(
              fontSize: 14,
              color: t.sub,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 20, color: t.sub),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: l.t('common.notes'),
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(fontSize: 16, color: t.ink),
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
  final t = context.select<AppStore, EcoTheme>((s) => s.theme);
  final l = context.l10nRead;
  return Positioned(
    left: 16,
    right: 16,
    bottom: 18 + MediaQuery.of(context).padding.bottom,
    child: Row(
      children: [
        Expanded(
          child: EcoBtn(
            t: t,
            bg: t.band,
            fg: t.ink,
            onTap: () => Navigator.of(context).pop(),
            child: Text(cancel ?? l.t('common.cancel')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EcoBtn(
            t: t,
            onTap: onSave,
            child: Text(save ?? l.t('common.save')),
          ),
        ),
      ],
    ),
  );
}

// ── Вода ──────────────────────────────────────────────────────

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  // Выбранный день — смещение в днях назад от сегодня (0 = сегодня).
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final t = s.theme;
    final l = context.l10n;

    final isToday = _offset == 0;
    final selDate = DateTime.now().subtract(Duration(days: _offset));
    final selWater = s.waterForOffset(_offset);
    final pct = s.waterGoal > 0 ? selWater / s.waterGoal : 0.0;

    return EcoScreen(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('home.water'),
            onBack: () => Navigator.of(context).pop(),
          ),
          // ── График воды за 30 дней: горизонтальная прокрутка, подложка за
          // выбранным днём (как на экране «Шаги») ──
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: EcoDayBarStrip(
              data: [
                for (final e in s.waterMonth()) (date: e.date, value: e.water),
              ],
              goal: s.waterGoal,
              minTop: (s.waterGoal * 1.3).round(),
              barColor: EcoColors.water,
              goalColor: EcoColors.waterDeep,
              offset: _offset,
              onSelect: (o) => setState(() => _offset = o),
            ),
          ),
          const SizedBox(height: 8),
          // Подпись выбранного дня: «Сегодня» или дата.
          Center(
            child: Text(
              isToday ? l.t('common.today') : l.dayMonth(selDate),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.sub,
              ),
            ),
          ),
          const SizedBox(height: 14),
          EcoCard(
            t: t,
            child: Column(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: _CupPainter(pct.clamp(0.0, 1.0))),
                ),
                const SizedBox(height: 18),
                Text(
                  '$selWater',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '/ ${s.waterGoal} ${l.unit('ml')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.sub,
                  ),
                ),
                // ± меняют воду ВЫБРАННОГО дня (в т.ч. прошлого).
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context
                          .read<AppStore>()
                          .stepWaterForOffset(_offset, -250),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: t.bandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.remove, size: 24, color: t.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    EcoBtn(
                      t: t,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      onTap: () => context
                          .read<AppStore>()
                          .stepWaterForOffset(_offset, 250),
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
    final t = s.theme;
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
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(
          t: t,
          onTap: () => Navigator.of(context).pushNamed('/bodyEntry'),
          child: Text(l.t('health.enterData')),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('health.bodyComposition'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            // Снизу плавающая кнопка «Ввести данные» (footer, высота 56 + нижний
            // отступ 18 + системная зона жестов) — даём контенту достаточный
            // отступ, чтобы корзинка не пряталась под кнопкой.
            padding: EdgeInsets.only(
              bottom: 18 + MediaQuery.of(context).padding.bottom + 56 + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    // Full-bleed до краёв телефона: через OverflowBox отменяем
                    // боковые отступы экрана (16px), чтобы график доходил до
                    // самого края, как день-полоса в «Еде». Видимая часть —
                    // всегда ровно 7 колонок; лишние записи уходят влево под
                    // горизонтальный скролл (reverse: true).
                    const visibleCount = 7;
                    final screenWidth = MediaQuery.sizeOf(context).width;
                    final colW = screenWidth / visibleCount;
                    final scrollable = entries.length > visibleCount;
                    final contentW =
                        scrollable ? entries.length * colW : screenWidth;
                    const stripHeight = 102.0 + 4 + 30;
                    return SizedBox(
                      height: stripHeight,
                      child: OverflowBox(
                        minWidth: screenWidth,
                        maxWidth: screenWidth,
                        minHeight: stripHeight,
                        maxHeight: stripHeight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: contentW,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) => _selectChartPoint(
                                details.localPosition,
                                contentW,
                                entries.length,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 102,
                                    // RepaintBoundary: линия+точки графика
                                    // кэшируются, и горизонтальный фл­инг 7-дневной
                                    // полоски лишь композитит слой, а не
                                    // перерисовывает график каждый кадр.
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size(contentW, 102),
                                        painter: _BodyChartPainter(
                                          chartPoints,
                                          selectedIndex: selectedIndex,
                                          t: t,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _BodyDateTicks(
                                    dates: [
                                      for (final entry in entries) entry.date,
                                    ],
                                    selectedIndex: selectedIndex,
                                    t: t,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                EcoCard(
                  t: t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('scale', fmt(bodyWeight), l.unit('kg'), t.dark, t),
                      _stat(
                        'gauge',
                        fmt(skeletalMuscle),
                        l.unit('kg'),
                        _kMuscleColor,
                        t,
                      ),
                      _stat('flame', fmt(bodyFat), '%', _kFatColor, t),
                    ],
                  ),
                ),
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('health.yourBodyComposition'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('profile.weight'),
                        value: fmt(bodyWeight),
                        unit: l.unit('kg'),
                        lo: fmt(53.5),
                        hi: fmt(72.3),
                        frac: ((bodyWeight - 48) / 30),
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.skeletalMuscle'),
                        value: fmt(skeletalMuscle),
                        unit: l.unit('kg'),
                        lo: fmt(25.8),
                        hi: fmt(28.9),
                        frac: ((skeletalMuscle - 22) / 10),
                        accent: _kMuscleColor,
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.fatMass'),
                        value: fmt(fatMass),
                        unit: l.unit('kg'),
                        lo: fmt(6.7),
                        hi: fmt(12.5),
                        frac: ((fatMass - 4) / 12),
                        accent: _kFatColor,
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.bodyWater'),
                        value: fmt(bodyWaterPercent(bodyFat)),
                        unit: '%',
                        lo: '50',
                        hi: '65',
                        frac: ((bodyWaterPercent(bodyFat) - 50) / 15)
                            .clamp(0.0, 1.0),
                        accent: _kWaterColor,
                        last: true,
                      ),
                    ],
                  ),
                ),
                // Удаление выбранной записи — иконка-корзинка внизу + диалог
                // подтверждения.
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _confirmDeleteEntry(selected.date),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.glassBorder),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 26,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String v, String u, Color c, EcoTheme t) => Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            child: Icon(ecoIcon(icon), size: 30, color: t.onDark),
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
                  style: TextStyle(fontSize: 12, color: t.sub),
                ),
              ],
            ),
          ),
        ],
      );

  void _selectChartPoint(Offset local, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final index = (local.dx * count / width).floor();
    setState(() => _selectedIndex = index.clamp(0, count - 1));
  }

  Future<void> _confirmDeleteEntry(DateTime date) async {
    final l = context.l10nRead;
    final store = context.read<AppStore>();
    final t = store.theme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x4714180C),
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          // Material-предок нужен заголовку, иначе текст рисуется с отладочным
          // жёлтым подчёркиванием (нет DefaultTextStyle).
          child: Material(
            type: MaterialType.transparency,
            child: EcoGlassSurface(
              t: t,
              blur: 60,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
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
                children: [
                  Text(
                    l.t('health.deleteEntryConfirm'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: EcoBtn(
                          t: t,
                          bg: t.band,
                          fg: t.ink,
                          height: 46,
                          onTap: () => Navigator.of(ctx).pop(false),
                          child: Text(l.t('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EcoBtn(
                          t: t,
                          height: 46,
                          onTap: () => Navigator.of(ctx).pop(true),
                          child: Text(l.t('common.yes')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      store.deleteBodyEntry(date);
      setState(() => _selectedIndex = null);
    }
  }

  List<BodyMetricEntry> _chartEntries(AppStore s, double currentWeight) {
    final saved = s.bodyHistory.where((entry) => entry.weightKg > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (saved.length >= 7) {
      // Все сохранённые записи — горизонтальный скролл покажет ранние.
      return saved;
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
  final EcoTheme t;

  const _BodyDateTicks({
    required this.dates,
    required this.selectedIndex,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox(height: 30);
    final currentYear = DateTime.now().year;
    // Год показываем только когда он отличается от текущего; место под него
    // резервируем для всех делений, чтобы числа стояли на одной линии.
    final anyOtherYear = dates.any((d) => d.year != currentYear);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < dates.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 75),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        i == selectedIndex ? FontWeight.w900 : FontWeight.w700,
                    color: i == selectedIndex ? t.ink : t.sub,
                  ),
                  // День/месяц через «/» (напр. 26/6).
                  child: Text('${dates[i].day}/${dates[i].month}'),
                ),
                if (anyOtherYear)
                  Text(
                    dates[i].year != currentYear ? '${dates[i].year}' : '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex ? t.ink : t.faint,
                    ),
                  ),
              ],
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
  final bool last;
  // Цвет полосы: null → сплошная тёмная (как у веса), иначе градиент dark→accent.
  final Color? accent;
  final EcoTheme t;
  const _RangeRow({
    required this.t,
    required this.label,
    required this.value,
    required this.unit,
    required this.lo,
    required this.hi,
    required this.frac,
    this.onTap,
    this.accent,
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
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
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
              Icon(Icons.chevron_right, size: 14, color: t.faint),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: t.sub,
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
                  Container(color: t.bandSoft),
                  FractionallySizedBox(
                    widthFactor: p,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        // Сплошной цвет без градиента: вес — тёмный, остальные —
                        // свой акцент.
                        color: accent ?? t.dark,
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
              Text(
                hi,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
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
  final EcoTheme t;

  _BodyChartPainter(this.points,
      {required this.selectedIndex, required this.t});

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
    // Каждая точка — по центру своей «колонки» даты (i+0.5)/N, чтобы маркер
    // стоял ровно над числом в _BodyDateTicks (Row из Expanded-ячеек).
    double x(int i) => (i + 0.5) * (size.width / points.length);
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
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = t.ink,
    );
    final selected = selectedIndex.clamp(0, points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final isSelected = i == selected;
      // Обычные точки — чёрные (как линия), выбранная — зелёная и крупнее.
      canvas.drawCircle(
        Offset(x(i), y(points[i])),
        isSelected ? 8 : 4.5,
        Paint()..color = isSelected ? EcoColors.prot : t.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BodyChartPainter old) {
    if (old.selectedIndex != selectedIndex) return true;
    if (old.t != t) return true;
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
  DateTime _date = DateTime.now();

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

  Future<void> _pickDate() {
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    final now = DateTime.now();
    var draft = _date;
    return showEcoSheet(
      context: context,
      t: t,
      title: l.t('health.entryDate'),
      doneLabel: l.t('common.save'),
      onDone: () => setState(() => _date = draft),
      body: SizedBox(
        height: 200,
        child: EcoDatePicker(
          t: t,
          initialDate: _date,
          minYear: now.year - 5,
          maxYear: now.year,
          monthNames: [
            for (var m = 1; m <= 12; m++) l.monthName(m),
          ],
          onChanged: (d) => draft = d,
        ),
      ),
    );
  }

  Future<void> _pickMetric({
    required String title,
    required String unit,
    required double value,
    required int min,
    required int max,
    required ValueChanged<double> onSave,
  }) {
    final t = context.read<AppStore>().theme;
    var whole = value.floor().clamp(min, max).toInt();
    var tenth = ((value - value.floor()) * 10).round().clamp(0, 9).toInt();
    return showEcoSheet(
      context: context,
      t: t,
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
                        selectionOverlay: EcoPickerSelectionOverlay(
                          t: t,
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
                        selectionOverlay: EcoPickerSelectionOverlay(
                          t: t,
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
                  style: TextStyle(
                    fontSize: 14,
                    color: t.sub,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    return EcoScreen(
      t: t,
      footer: actionFooter(
        context,
        onSave: () {
          final store = context.read<AppStore>();
          store.saveBodyMetrics(
            weightKg: _weightValue,
            skeletalMuscle: skeletal,
            bodyFat: fat,
            date: _date,
          );
          Navigator.of(context).pop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DatePill(date: _date, onTap: _pickDate),
          EcoCard(
            t: t,
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
              style: TextStyle(
                fontSize: 12,
                color: t.sub,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          EcoCard(
            t: t,
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
              style: TextStyle(
                fontSize: 12,
                color: t.sub,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 2, bottom: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.olive, width: 1.5)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
