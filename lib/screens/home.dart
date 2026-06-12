import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Home dashboard — port of Eco design home.jsx (Frame-1).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const t = EcoTheme.meadow;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final waterPct = (s.waterGoal > 0 ? s.water / s.waterGoal * 100 : 0).round();
    final stepsPct = (s.stepsGoal > 0 ? s.steps / s.stepsGoal * 100 : 0).round();

    return EcoScreen(
      t: t,
      footer: EcoBottomNav(
        t: t,
        active: 'home',
        onHome: () {},
        onProfile: () => Navigator.of(context).pushNamed('/profile'),
        onPlus: () => showMealPicker(context),
      ),
      child: Padding(
        // SafeArea handles the status bar. Bottom clears the fixed nav band
        // (91 + 16 float + system inset) so the last card scrolls fully out.
        padding: EdgeInsets.only(top: 24, bottom: 150 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 18, top: 4),
              child: Text('Сегодня', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),

            // Рекомендации
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EcoCardHead(t: t, icon: 'bulb', title: 'Рекомендации', mb: 12),
                  const Text(
                    'Регулярная активность полезна для здоровья. Чем больше вы двигаетесь — тем лучше себя чувствуете.',
                    style: TextStyle(fontSize: 13.5, height: 1.45, color: EcoColors.sub),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final k in ['up', 'down'])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => context.read<AppStore>().setRecFeedback(k),
                            child: Container(
                              width: 40,
                              height: 32,
                              decoration: BoxDecoration(
                                color: s.recFeedback == k ? t.dark : t.bandSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                ecoIcon(k == 'up' ? 'thumbUp' : 'thumbDn'),
                                size: 17,
                                color: s.recFeedback == k ? t.pill : t.dark,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Еда
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.of(context).pushNamed('/dayview'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EcoCardHead(t: t, icon: 'food', title: 'Еда', mb: 8),
                  Row(
                    children: [
                      MacroRings(size: 128, data: const [
                        MacroRingData(value: 652, goal: 900, color: EcoColors.carb, soft: EcoColors.carbSoft),
                        MacroRingData(value: 326, goal: 659, color: EcoColors.fat, soft: EcoColors.fatSoft),
                        MacroRingData(value: 365, goal: 589, color: EcoColors.prot, soft: EcoColors.protSoft),
                      ]),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: MacroLegend(t: t, items: [
                          (label: 'Углеводы', value: 652, goal: 900, color: EcoColors.carb),
                          (label: 'Жиры', value: 326, goal: 659, color: EcoColors.fat),
                          (label: 'Белки', value: 365, goal: 589, color: EcoColors.prot),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CalorieTrack(t: t, value: s.consumed, goal: s.goalKcal),
                ],
              ),
            ),

            // Параметры тела
            _MetricCard(
              icon: 'gauge',
              title: 'Параметры тела',
              onTap: () => Navigator.of(context).pushNamed('/body'),
              left: EcoPill(
                t: t,
                bg: t.bandSoft,
                fontSize: 16,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                text: '${s.weight > 0 ? s.weight : '—'} кг',
              ),
              right: SizedBox(
                width: 150,
                child: Column(children: [
                  EcoPill(t: t, text: 'Средняя', fontSize: 11),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: [t.bandSoft, t.dark, EcoColors.fatSoft]),
                    ),
                  ),
                ]),
              ),
            ),

            // Шаги — тап включает шагомер (разрешение) либо обновляет счёт
            _MetricCard(
              icon: 'steps',
              title: 'Шаги',
              onTap: () => context.read<AppStore>().enableSteps(),
              left: EcoPill(
                t: t,
                bg: t.bandSoft,
                fontSize: 16,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                text: '${s.steps} / ${s.stepsGoal}',
              ),
              right: _MiniProgress(pct: stepsPct, label: '$stepsPct%'),
            ),

            // Сон
            _MetricCard(
              icon: 'bed',
              title: 'Сон',
              onTap: () => Navigator.of(context).pushNamed('/stats'),
              left: EcoBtn(
                t: t,
                height: 44,
                fontSize: 15,
                onTap: () => Navigator.of(context).pushNamed('/stats'),
                child: const Text('Ввод'),
              ),
              right: const _MiniProgress(pct: 62, label: '?'),
            ),

            // Вода
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.of(context).pushNamed('/water'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EcoCardHead(t: t, icon: 'water', title: 'Вода'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      EcoBtn(
                        t: t,
                        height: 44,
                        fontSize: 15,
                        onTap: () => context.read<AppStore>().addWater(250),
                        child: const Text('+ 250 мл'),
                      ),
                      Row(children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${s.water}', style: const TextStyle(color: EcoColors.ink)),
                            TextSpan(text: ' / ${s.waterGoal} мл', style: const TextStyle(color: EcoColors.sub, fontWeight: FontWeight.w600)),
                          ]),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 14),
                        _WaterGlass(pct: waterPct.toDouble()),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            // Кровяное давление
            _MetricCard(
              icon: 'pulse',
              title: 'Кровяное давление',
              onTap: () => _quickEntry(context, kind: 'pressure'),
              left: EcoBtn(
                t: t,
                height: 44,
                fontSize: 15,
                onTap: () => _quickEntry(context, kind: 'pressure'),
                child: Text(s.pressure ?? 'Ввод'),
              ),
              right: _MiniProgress(pct: s.pressure != null ? 70 : 50, label: s.pressure != null ? 'норма' : '?'),
            ),

            // Сахар крови
            _MetricCard(
              icon: 'sugar',
              title: 'Сахар крови',
              onTap: () => _quickEntry(context, kind: 'sugar'),
              left: EcoBtn(
                t: t,
                height: 44,
                fontSize: 15,
                onTap: () => _quickEntry(context, kind: 'sugar'),
                child: Text(s.sugar != null ? '${s.sugar} ммоль/л' : 'Ввод'),
              ),
              right: _MiniProgress(pct: s.sugar != null ? 64 : 50, label: s.sugar != null ? 'норма' : '?'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet with quick presets (давление / сахар) — from home.jsx QuickEntry.
  static void _quickEntry(BuildContext context, {required String kind}) {
    final presets = kind == 'pressure' ? ['110/70', '120/80', '130/85', '140/90'] : ['4.5', '5.2', '5.8', '6.4'];
    final title = kind == 'pressure' ? 'Давление, мм рт. ст.' : 'Сахар крови, ммоль/л';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.r + 8))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.band, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3,
              children: [
                for (final p in presets)
                  GestureDetector(
                    onTap: () {
                      final store = context.read<AppStore>();
                      if (kind == 'pressure') {
                        store.setPressure(p);
                      } else {
                        store.setSugar(double.parse(p));
                      }
                      Navigator.of(sheetCtx).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: Text(p, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Приём пищи" meal-picker — the FAB modal from home.jsx.
void showMealPicker(BuildContext context) {
  const t = HomeScreen.t;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(color: t.band, borderRadius: BorderRadius.circular(t.r + 6)),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Приём пищи', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: t.dark)),
          const SizedBox(height: 14),
          for (final (i, meal) in kMealsByTime.indexed) ...[
            if (i > 0) Divider(height: 1.5, color: t.bandSoft),
            Builder(builder: (rowCtx) {
              final kcal = rowCtx.read<AppStore>().mealKcal(meal.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        Navigator.of(context).pushNamed('/meallog', arguments: meal.key);
                      },
                      child: Row(children: [
                        CalBadge(t: t, value: kcal, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(meal.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.dark)),
                        ),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).pushNamed('/addfood', arguments: meal.key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
                      child: Row(children: [
                        Container(width: 2, height: 20, decoration: BoxDecoration(color: t.olive, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Icon(Icons.add, size: 22, color: t.dark),
                      ]),
                    ),
                  ),
                ]),
              );
            }),
          ],
        ],
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget left;
  final Widget right;
  final VoidCallback? onTap;

  const _MetricCard({required this.icon, required this.title, required this.left, required this.right, this.onTap});

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    return EcoCard(
      t: t,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoCardHead(t: t, icon: icon, title: title),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [left, right]),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final int pct;
  final String label;

  const _MiniProgress({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) {
    const t = HomeScreen.t;
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          EcoPill(t: t, text: label, fontSize: 11, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              width: double.infinity,
              child: Stack(children: [
                Container(color: t.bandSoft),
                FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: t.olive, borderRadius: BorderRadius.circular(999))),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterGlass extends StatelessWidget {
  final double pct;
  const _WaterGlass({required this.pct});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 64, height: 76, child: CustomPaint(painter: _GlassPainter(pct)));
  }
}

class _GlassPainter extends CustomPainter {
  final double pct;
  _GlassPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Trapezoid cup: polygon(8% 0, 92% 0, 84% 100%, 16% 100%)
    final cup = Path()
      ..moveTo(w * 0.08, 0)
      ..lineTo(w * 0.92, 0)
      ..lineTo(w * 0.84, h)
      ..lineTo(w * 0.16, h)
      ..close();
    canvas.save();
    canvas.clipPath(cup);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFDCEAF6));
    final fillH = h * (pct / 100).clamp(0.0, 1.0);
    final grad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [EcoColors.water, EcoColors.waterDeep],
      ).createShader(Rect.fromLTWH(0, h - fillH, w, fillH));
    canvas.drawRect(Rect.fromLTWH(0, h - fillH, w, fillH), grad);
    canvas.restore();
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4E7FC4).withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.pct != pct;
}
