import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

const _t = EcoTheme.meadow;

// ── Shared helpers ────────────────────────────────────────────

String ruDate([DateTime? date]) {
  final d = date ?? DateTime.now();
  const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  const mon = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${wd[d.weekday - 1]}, ${d.day} ${mon[d.month - 1]}';
}

/// Centered date pill (header of entry screens).
class DatePill extends StatelessWidget {
  final String? time;
  const DatePill({super.key, this.time});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topInset + 24, bottom: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
          decoration: BoxDecoration(color: _t.band, borderRadius: BorderRadius.circular(999)),
          child: Text(
            time != null ? '${ruDate()} $time' : ruDate(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _t.dark),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row(value - step, true),
        row(value, false),
        row(value + step, true),
      ]),
    );
  }
}

/// Field row with optional icon + right widget.
class FieldRow extends StatelessWidget {
  final String? icon;
  final String label;
  final Widget right;
  final bool last;
  const FieldRow({super.key, this.icon, required this.label, required this.right, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _t.bandSoft, width: 1.5))),
      child: Row(children: [
        if (icon != null) ...[Icon(ecoIcon(icon!), size: 20, color: _t.dark), const SizedBox(width: 12)],
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: EcoColors.sub))),
        right,
      ]),
    );
  }
}

/// Underlined numeric input (e.g. "— уд/м").
class UnderlineInput extends StatelessWidget {
  final String? suffix;
  final String? initial;
  final double width;
  final ValueChanged<String>? onChanged;
  const UnderlineInput({super.key, this.suffix, this.initial, this.width = 70, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      SizedBox(
        width: width,
        child: TextField(
          controller: initial != null ? TextEditingController(text: initial) : null,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: EcoColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: '—',
            contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _t.olive, width: 1.5)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _t.olive, width: 1.5)),
          ),
        ),
      ),
      if (suffix != null) ...[const SizedBox(width: 6), Text(suffix!, style: const TextStyle(fontSize: 14, color: EcoColors.sub, fontWeight: FontWeight.w600))],
    ]);
  }
}

/// "Заметки" field.
class NotesField extends StatelessWidget {
  const NotesField({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _t.card, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.edit_outlined, size: 20, color: EcoColors.sub),
        const SizedBox(width: 12),
        const Expanded(
          child: TextField(
            decoration: InputDecoration(hintText: 'Заметки', border: InputBorder.none, isDense: true),
            style: TextStyle(fontSize: 15, color: EcoColors.ink),
          ),
        ),
      ]),
    );
  }
}

/// Bottom Отмена / Сохранить footer.
Widget actionFooter(BuildContext context, {String cancel = 'Отмена', String save = 'Сохранить', required VoidCallback onSave}) {
  return Positioned(
    left: 16,
    right: 16,
    bottom: 18 + MediaQuery.of(context).padding.bottom,
    child: Row(children: [
      Expanded(child: EcoBtn(t: _t, bg: _t.band, fg: _t.dark, onTap: () => Navigator.of(context).pop(), child: Text(cancel))),
      const SizedBox(width: 12),
      Expanded(child: EcoBtn(t: _t, onTap: onSave, child: Text(save))),
    ]),
  );
}

// ── Давление ──────────────────────────────────────────────────

class PressureScreen extends StatefulWidget {
  const PressureScreen({super.key});
  @override
  State<PressureScreen> createState() => _PressureScreenState();
}

class _PressureScreenState extends State<PressureScreen> {
  late int sys;
  late int dia;

  @override
  void initState() {
    super.initState();
    final parts = (context.read<AppStore>().pressure ?? '120/80').split('/');
    sys = int.tryParse(parts[0]) ?? 120;
    dia = int.tryParse(parts.length > 1 ? parts[1] : '80') ?? 80;
  }

  @override
  Widget build(BuildContext context) {
    return EcoScreen(
      t: _t,
      footer: actionFooter(context, onSave: () {
        context.read<AppStore>().setPressureFull(sys, dia);
        Navigator.of(context).pop();
      }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DatePill(time: '20:28'),
        EcoCard(
          t: _t,
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              const Text.rich(TextSpan(children: [
                TextSpan(text: 'Систолич. ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                TextSpan(text: '(мм рт.ст.)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EcoColors.sub)),
              ])),
              Text('$sys', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Center(child: NumberWheel(value: sys, min: 70, max: 220, onChanged: (v) => setState(() => sys = v))),
            const SizedBox(height: 10),
            Divider(height: 1.5, thickness: 1.5, color: _t.bandSoft),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(child: Text('Диастолическое (мм рт.ст.)', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: EcoColors.sub))),
              _roundBtn(Icons.remove, () => setState(() => dia = (dia - 1).clamp(40, 160))),
              SizedBox(width: 36, child: Text('$dia', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              _roundBtn(Icons.add, () => setState(() => dia = (dia + 1).clamp(40, 160))),
            ]),
          ]),
        ),
        EcoCard(
          t: _t,
          pad: 16,
          child: Column(children: [
            FieldRow(icon: 'pulse', label: 'Пульс', right: const UnderlineInput(suffix: 'уд/м')),
            FieldRow(icon: 'drop', label: 'Лекарство', last: true, right: _none()),
          ]),
        ),
        const NotesField(),
      ]),
    );
  }
}

Widget _roundBtn(IconData icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: _t.bandSoft, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: _t.dark),
      ),
    );

Widget _none() => const Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Нет', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      Icon(Icons.keyboard_arrow_down, size: 16, color: EcoColors.sub),
    ]);

// ── Сахар крови ───────────────────────────────────────────────

class SugarScreen extends StatefulWidget {
  const SugarScreen({super.key});
  @override
  State<SugarScreen> createState() => _SugarScreenState();
}

class _SugarScreenState extends State<SugarScreen> {
  late int val = (context.read<AppStore>().sugar ?? 100).round();
  int status = 0;

  static const _opts = [
    (icon: 'cutlery', label: 'Голодание'),
    (icon: 'food', label: 'До еды'),
    (icon: 'bulb', label: 'После еды'),
    (icon: 'user', label: 'Общие'),
  ];

  @override
  Widget build(BuildContext context) {
    return EcoScreen(
      t: _t,
      footer: actionFooter(context, onSave: () {
        context.read<AppStore>().setSugar(val.toDouble());
        Navigator.of(context).pop();
      }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DatePill(time: '20:29'),
        EcoCard(
          t: _t,
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text.rich(TextSpan(children: [
              TextSpan(text: 'Сахар крови ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              TextSpan(text: '(мг/дл)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EcoColors.sub)),
            ])),
            const SizedBox(height: 6),
            Center(child: NumberWheel(value: val, min: 40, max: 400, onChanged: (v) => setState(() => val = v))),
          ]),
        ),
        EcoCard(
          t: _t,
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Выбор текущего статуса', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              for (final (i, o) in _opts.indexed)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => status = i),
                    child: Column(children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: i == status ? _t.dark : _t.bandSoft, shape: BoxShape.circle),
                        child: Icon(ecoIcon(o.icon), size: 22, color: i == status ? _t.pill : _t.olive),
                      ),
                      const SizedBox(height: 8),
                      Text(o.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: i == status ? EcoColors.ink : EcoColors.sub)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
        EcoCard(
          t: _t,
          pad: 16,
          child: Column(children: [
            FieldRow(icon: 'drop', label: 'Лекарство', right: _none()),
            FieldRow(icon: 'pulse', label: 'Инсулин', last: true, right: const UnderlineInput(suffix: 'ед.')),
          ]),
        ),
      ]),
    );
  }
}

// ── Вода ──────────────────────────────────────────────────────

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final pct = s.waterGoal > 0 ? s.water / s.waterGoal : 0.0;
    final now = DateTime.now();
    return EcoScreen(
      t: _t,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EcoTopBar(
          t: _t,
          title: 'Вода',
          onBack: () => Navigator.of(context).pop(),
          right: Icon(ecoIcon('chart'), size: 22, color: _t.dark),
        ),
        // last 7 days row with goal dotted line
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: i == 0 ? _t.bandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${now.subtract(Duration(days: i)).day}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == 0 ? EcoColors.ink : EcoColors.sub)),
                ),
            ],
          ),
        ),
        EcoCard(
          t: _t,
          child: Column(children: [
            SizedBox(width: 150, height: 150, child: CustomPaint(painter: _CupPainter(pct.clamp(0.0, 1.0)))),
            const SizedBox(height: 18),
            Text('${s.water}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700)),
            Text('/ ${s.waterGoal} мл', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: EcoColors.sub)),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => context.read<AppStore>().stepWater(-250),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: _t.bandSoft, shape: BoxShape.circle),
                  child: Icon(Icons.remove, size: 24, color: _t.dark),
                ),
              ),
              const SizedBox(width: 12),
              EcoBtn(
                t: _t,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                onTap: () => context.read<AppStore>().stepWater(250),
                child: const Text('+ 250 мл'),
              ),
            ]),
          ]),
        ),
      ]),
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
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFDCEAF6));
    final fillH = h * pct;
    canvas.drawRect(
      Rect.fromLTWH(0, h - fillH, w, fillH),
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [EcoColors.water, EcoColors.waterDeep])
            .createShader(Rect.fromLTWH(0, h - fillH, w, fillH)),
    );
    canvas.restore();
    canvas.drawPath(cup, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = EcoColors.waterDeep.withValues(alpha: 0.33));
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.pct != pct;
}

// ── Состав тела ───────────────────────────────────────────────

class BodyScreen extends StatelessWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final fatMass = (s.weight * s.bodyFat / 100);
    String fmt(num v) => v.toStringAsFixed(1).replaceAll('.', ',');

    return EcoScreen(
      t: _t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(t: _t, onTap: () => Navigator.of(context).pushNamed('/bodyEntry'), child: const Text('Ввести данные')),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EcoTopBar(t: _t, title: 'Состав тела', onBack: () => Navigator.of(context).pop(), right: Icon(ecoIcon('chart'), size: 22, color: _t.dark)),
        Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 110, child: CustomPaint(size: const Size(double.infinity, 110), painter: _BodyChartPainter())),
            const SizedBox(height: 14),
            EcoCard(
              t: _t,
              margin: const EdgeInsets.only(bottom: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('scale', fmt(s.weight), 'кг', _t.dark),
                _stat('gauge', fmt(s.skeletalMuscle), 'кг', EcoColors.carb),
                _stat('flame', fmt(s.bodyFat), '%', EcoColors.fat),
              ]),
            ),
            EcoCard(
              t: _t,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Ваш состав тела', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Icon(ecoIcon('bulb'), size: 20, color: EcoColors.sub),
                ]),
                _RangeRow(label: 'Вес', value: fmt(s.weight), unit: 'кг', lo: '53,5', hi: '72,3', frac: ((s.weight - 48) / 30)),
                _RangeRow(label: 'Скелетн. мускулат.', value: fmt(s.skeletalMuscle), unit: 'кг', lo: '25,8', hi: '28,9', frac: ((s.skeletalMuscle - 22) / 10), over: true),
                _RangeRow(label: 'Масса жировой ткани', value: fmt(fatMass), unit: 'кг', lo: '6,7', hi: '12,5', frac: ((fatMass - 4) / 12)),
                _RangeRow(label: 'Вода в организме', value: '55,2', unit: '%', lo: '50', hi: '65', frac: 0.5, last: true),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String icon, String v, String u, Color c) => Column(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Icon(ecoIcon(icon), size: 20, color: Colors.white)),
        const SizedBox(height: 10),
        Text.rich(TextSpan(children: [
          TextSpan(text: v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          TextSpan(text: ' $u', style: const TextStyle(fontSize: 13, color: EcoColors.sub)),
        ])),
      ]);
}

class _RangeRow extends StatelessWidget {
  final String label, value, unit, lo, hi;
  final double frac;
  final bool over, last;
  const _RangeRow({required this.label, required this.value, required this.unit, required this.lo, required this.hi, required this.frac, this.over = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    final p = frac.clamp(0.04, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _t.bandSoft, width: 1.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 14, color: EcoColors.faint),
        ]),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          TextSpan(text: ' $unit', style: const TextStyle(fontSize: 13, color: EcoColors.sub, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(children: [
              Container(color: _t.bandSoft),
              FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: over ? LinearGradient(colors: [_t.dark, EcoColors.fat]) : null,
                    color: over ? null : _t.dark,
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(lo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: EcoColors.sub)),
          Text(hi, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: EcoColors.sub)),
        ]),
      ]),
    );
  }
}

class _BodyChartPainter extends CustomPainter {
  static const _pts = [62.5, 63.0, 63.4, 64.0, 64.3, 64.9, 65.4];
  static const _sel = 4;

  @override
  void paint(Canvas canvas, Size size) {
    const min = 61.5, max = 68.5;
    double x(int i) => 10 + i * ((size.width - 20) / (_pts.length - 1));
    double y(double v) => size.height - ((v - min) / (max - min)) * size.height;
    final path = Path();
    for (var i = 0; i < _pts.length; i++) {
      if (i == 0) {
        path.moveTo(x(i), y(_pts[i]));
      } else {
        path.lineTo(x(i), y(_pts[i]));
      }
    }
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = _t.dark);
    for (var i = 0; i < _pts.length; i++) {
      canvas.drawCircle(Offset(x(i), y(_pts[i])), i == _sel ? 5 : 3.5, Paint()..color = i == _sel ? _t.dark : _t.olive);
    }
  }

  @override
  bool shouldRepaint(_BodyChartPainter old) => false;
}

// ── Ввод веса ─────────────────────────────────────────────────

class BodyEntryScreen extends StatefulWidget {
  const BodyEntryScreen({super.key});
  @override
  State<BodyEntryScreen> createState() => _BodyEntryScreenState();
}

class _BodyEntryScreenState extends State<BodyEntryScreen> {
  late int intv;
  late int decv;
  late double skeletal = context.read<AppStore>().skeletalMuscle;
  late double fat = context.read<AppStore>().bodyFat;

  @override
  void initState() {
    super.initState();
    final w = context.read<AppStore>().weight;
    intv = w.floor().clamp(30, 200);
    decv = ((w - w.floor()) * 10).round() % 10;
  }

  @override
  Widget build(BuildContext context) {
    return EcoScreen(
      t: _t,
      footer: actionFooter(context, cancel: 'Отменить', onSave: () {
        final store = context.read<AppStore>();
        store.setWeight(double.parse((intv + decv / 10).toStringAsFixed(1)));
        store.setBodyComposition(bodyFat: fat, skeletalMuscle: skeletal);
        Navigator.of(context).pop();
      }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DatePill(time: '20:25'),
        EcoCard(
          t: _t,
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Вес (кг)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
              NumberWheel(value: intv, min: 30, max: 200, width: 90, onChanged: (v) => setState(() => intv = v)),
              Text(',', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: _t.dark)),
              NumberWheel(value: decv, min: 0, max: 9, width: 90, fmt: (v) => '${(v + 10) % 10}', onChanged: (v) => setState(() => decv = (v + 10) % 10)),
            ]),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Указанный вес также будет выводиться в профиле пользователя.', style: TextStyle(fontSize: 13, color: EcoColors.sub, height: 1.45)),
        ),
        const SizedBox(height: 14),
        EcoCard(
          t: _t,
          pad: 16,
          child: Column(children: [
            FieldRow(label: 'Скелетн. мускулат. (кг)', right: UnderlineInput(width: 56, initial: skeletal.toString(), onChanged: (v) => skeletal = double.tryParse(v) ?? skeletal)),
            FieldRow(label: 'Телесный жир (%)', last: true, right: UnderlineInput(width: 56, initial: fat.toString(), onChanged: (v) => fat = double.tryParse(v) ?? fat)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 14, left: 4, right: 4),
          child: Text('Уровень воды в организме и базальный метаболизм (BMR) рассчитываются на основе массы скелетной мускулатуры и процента жира.', style: TextStyle(fontSize: 13, color: EcoColors.sub, height: 1.45)),
        ),
        const NotesField(),
        const SizedBox(height: 90),
      ]),
    );
  }
}
