import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Сон / аналитика — port of logscreens.jsx::Stats (SleepBars + SleepCircle).
///
/// Реальных данных сна в приложении пока нет: график, средние и круг —
/// статичный макет. Поэтому экран честно помечен как демонстрационный
/// (бейдж `common.stubInProgress`), иллюстрация приглушена, а сегмент-контрол
/// «7/31/12» и кнопка «Сохранить» (обе ничего не меняли) убраны — остаётся
/// только «Назад».
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    // Демо-диапазон: последняя неделя до сегодня — только чтобы шаблон
    // averageSleepRange не показывал сырые плейсхолдеры {from}/{to}.
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('home.sleep'),
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(
          t: t,
          bg: t.band,
          fg: t.ink,
          onTap: () => Navigator.of(context).pop(),
          child: Text(l.t('common.cancel')),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Бейдж «раздел в разработке» — прямо сообщаем, что данные ниже
          // демонстрационные.
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.bandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.construction_rounded, size: 18, color: t.sub),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.t('common.stubInProgress'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            // Иллюстрация макета приглушена (0.5), чтобы визуально отличаться от
            // реальных данных на других экранах.
            child: Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: RepaintBoundary(child: _SleepBars()),
                  ),
                  EcoCard(
                    t: t,
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.format('stats.averageSleepRange', {
                            'from': l.dayMonth(from),
                            'to': l.dayMonth(now),
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.sub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '23:15',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: t.sub,
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.sub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '07:13',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: t.sub,
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
                        const Center(
                            child: RepaintBoundary(child: _SleepCircle())),
                      ],
                    ),
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
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
                    style: TextStyle(
                      fontSize: 12,
                      color: t.sub,
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
            child: Center(child: _marker(t, Icons.bedtime_outlined)),
          ),
          Positioned(bottom: 22, right: 6, child: _marker(t, Icons.alarm)),
        ],
      ),
    );
  }

  Widget _marker(EcoTheme t, IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: t.onDark),
    );
  }
}
