import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Сон / аналитика — port of logscreens.jsx::Stats (SleepBars + SleepCircle).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const t = EcoTheme.meadow;
  int seg = 1;

  @override
  Widget build(BuildContext context) {
    return EcoScreen(
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: Row(children: [
          Expanded(
            child: EcoBtn(t: t, bg: t.band, fg: t.dark, onTap: () => Navigator.of(context).pop(), child: const Text('Отмена')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: EcoBtn(t: t, onTap: () => Navigator.of(context).pop(), child: const Text('Сохранить')),
          ),
        ]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(t: t, title: 'Сон', onBack: () => Navigator.of(context).pop()),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _SleepBars(),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: EcoSegmented(
                  t: t,
                  options: const ['7 дней', '31 день', '12 мес.'],
                  value: seg,
                  onChanged: (i) => setState(() => seg = i),
                ),
              ),
              EcoCard(
                t: t,
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Среднее время сна · 09.03 – 10.04',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: EcoColors.sub)),
                  const SizedBox(height: 4),
                  const Text('8 ч 12 мин в день', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(children: [
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Среднее засыпание', style: TextStyle(fontSize: 13, color: EcoColors.sub, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('23:15', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: EcoColors.sub)),
                        ]),
                      ),
                      Container(width: 2, decoration: BoxDecoration(color: t.olive, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Среднее пробуждение', style: TextStyle(fontSize: 13, color: EcoColors.sub, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('07:13', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: EcoColors.sub)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              EcoCard(
                t: t,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Продолжительность сна · Сб, 10 апреля',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Center(child: _SleepCircle()),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Weekly sleep bar chart with the dashed 8h target line.
class _SleepBars extends StatelessWidget {
  const _SleepBars();

  static const _data = [
    (d: 'пн', n: '5', h: 7.5, on: false),
    (d: 'вт', n: '6', h: 8.0, on: false),
    (d: 'ср', n: '7', h: 6.5, on: false),
    (d: 'чт', n: '8', h: 8.2, on: false),
    (d: 'пт', n: '9', h: 5.5, on: false),
    (d: 'сб', n: '10/4', h: 8.7, on: true),
    (d: 'вс', n: '11', h: 0.0, on: false),
  ];

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
    const maxH = 9.0;
    return SizedBox(
      height: 170,
      child: Stack(children: [
        Positioned(
          left: 0,
          right: 28,
          top: 26,
          child: CustomPaint(size: const Size(double.infinity, 2), painter: _DashPainter(EcoColors.carb)),
        ),
        const Positioned(
          right: 0,
          top: 20,
          child: Text('8 ч', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EcoColors.carb)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Row(children: [
            for (final b in _data)
              Expanded(
                child: Column(children: [
                  Text(b.d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EcoColors.sub)),
                  const Spacer(),
                  Stack(alignment: Alignment.bottomCenter, children: [
                    if (b.on)
                      Container(
                        width: 30,
                        height: 130,
                        decoration: BoxDecoration(color: t.bandSoft, borderRadius: BorderRadius.circular(999)),
                      ),
                    if (b.h > 0)
                      Container(
                        width: 12,
                        height: b.h / maxH * 110,
                        decoration: BoxDecoration(color: EcoColors.carb, borderRadius: BorderRadius.circular(999)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(b.n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

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
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// 270° conic sleep ring with bed/alarm markers — port of SleepCircle.
class _SleepCircle extends StatelessWidget {
  const _SleepCircle();

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(-math.pi / 2),
              colors: [EcoColors.carb, EcoColors.carb, EcoColors.carbSoft, EcoColors.carbSoft],
              stops: [0, 0.75, 0.75, 1],
            ),
          ),
        ),
        Positioned.fill(
          left: 30,
          right: 30,
          top: 30,
          bottom: 30,
          child: Container(
            decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('время сна', style: TextStyle(fontSize: 13, color: EcoColors.sub, fontWeight: FontWeight.w600)),
              Text('8 ч 43 м', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(child: _marker(Icons.bedtime_outlined)),
        ),
        Positioned(bottom: 22, right: 6, child: _marker(Icons.alarm)),
      ]),
    );
  }

  Widget _marker(IconData icon) {
    const t = EcoTheme.meadow;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: t.pill),
    );
  }
}
