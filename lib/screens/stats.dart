import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
    final l = context.l10n;
    return EcoScreen(
      t: t,
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: Row(
          children: [
            Expanded(
              child: EcoBtn(
                t: t,
                bg: t.band,
                fg: t.dark,
                onTap: () => Navigator.of(context).pop(),
                child: Text(l.t('common.cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EcoBtn(
                t: t,
                onTap: () => Navigator.of(context).pop(),
                child: Text(l.t('common.save')),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('home.sleep'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _SleepBars(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: EcoSegmented(
                    t: t,
                    options: [
                      l.t('stats.period7'),
                      l.t('stats.period31'),
                      l.t('stats.period12'),
                    ],
                    value: seg,
                    onChanged: (i) => setState(() => seg = i),
                  ),
                ),
                EcoCard(
                  t: t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('stats.averageSleepRange'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: EcoColors.sub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.t('stats.averageSleepDaily'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.t('stats.averageBedtime'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: EcoColors.sub,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '23:15',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: EcoColors.sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: t.olive,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.t('stats.averageWakeup'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: EcoColors.sub,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '07:13',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: EcoColors.sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('stats.sleepDurationSample'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(child: _SleepCircle()),
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
}

/// Weekly sleep bar chart with the dashed 8h target line.
class _SleepBars extends StatelessWidget {
  const _SleepBars();

  static const _data = [
    (n: '5', h: 7.5, on: false),
    (n: '6', h: 8.0, on: false),
    (n: '7', h: 6.5, on: false),
    (n: '8', h: 8.2, on: false),
    (n: '9', h: 5.5, on: false),
    (n: '10/4', h: 8.7, on: true),
    (n: '11', h: 0.0, on: false),
  ];

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
    final l = context.l10n;
    const maxH = 9.0;
    return SizedBox(
      height: 170,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 28,
            top: 26,
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashPainter(EcoColors.carb),
            ),
          ),
          Positioned(
            right: 0,
            top: 20,
            child: Text(
              l.t('stats.eightHours'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: EcoColors.carb,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: Row(
              children: [
                for (final (i, b) in _data.indexed)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l.weekdayShort(i + 1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: EcoColors.sub,
                          ),
                        ),
                        const Spacer(),
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            if (b.on)
                              Container(
                                width: 30,
                                height: 130,
                                decoration: BoxDecoration(
                                  color: t.bandSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            if (b.h > 0)
                              Container(
                                width: 12,
                                height: b.h / maxH * 110,
                                decoration: BoxDecoration(
                                  color: EcoColors.carb,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.n,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
    final l = context.l10n;
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(-math.pi / 2),
                colors: [
                  EcoColors.carb,
                  EcoColors.carb,
                  EcoColors.carbSoft,
                  EcoColors.carbSoft,
                ],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.t('stats.sleepTime'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: EcoColors.sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l.t('stats.sleepCircleValue'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(child: _marker(Icons.bedtime_outlined)),
          ),
          Positioned(bottom: 22, right: 6, child: _marker(Icons.alarm)),
        ],
      ),
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
