import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Экран «Шаги» — открывается по тапу на карточку «Шаги» на главной.
/// Сверху горизонтально прокручиваемый столбчатый график шагов за 30 дней с
/// линией цели и подложкой-пилюлей за выбранным днём (как день-полоса в «Еде»),
/// снизу карточка-сводка с полосами прогресса выбранного дня: шаги, сожжённые
/// калории, время активности.
class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  // Выбранный день — смещение в днях назад от сегодня (0 = сегодня).
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    // Открытие экрана = включение/обновление шагомера (раньше это делал тап по
    // карточке «Шаги» на главной).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppStore>().enableSteps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    // Перестраиваемся при изменении шагов (живой шагомер), но не на прочие тики.
    context.select<AppStore, int>((s) => Object.hash(s.steps, s.stepsGoal));
    final s = context.read<AppStore>();
    final l = context.l10n;

    final isToday = _offset == 0;
    final selDate = DateTime.now().subtract(Duration(days: _offset));
    final selSteps = s.stepsForOffset(_offset);

    return EcoScreen(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('home.steps'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 40 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Месячный график шагов: горизонтальная прокрутка, подложка
                // за выбранным днём (без карточки — прямо на фоне экрана) ──
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: EcoDayBarStrip(
                    data: [
                      for (final e in s.stepsMonth())
                        (date: e.date, value: e.steps),
                    ],
                    goal: s.stepsGoal,
                    minTop: 13000,
                    barColor: EcoColors.stepAccent,
                    goalColor: EcoColors.stepAccent,
                    offset: _offset,
                    onSelect: (o) => setState(() => _offset = o),
                  ),
                ),
                const SizedBox(height: 8),
                // Подпись выбранного дня: «Сегодня» или дата (как в «Еде»).
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
                const SizedBox(height: 18),
                // ── Сводка за выбранный день: полосы прогресса ──
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? l.t('common.today') : l.dayMonth(selDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ProgressScale(
                        t: t,
                        value: selSteps.toDouble(),
                        target: s.stepsGoal.toDouble(),
                        color: EcoColors.stepAccent,
                        label: l.t('home.steps'),
                        animateFromZero: true,
                      ),
                      const SizedBox(height: 20),
                      ProgressScale(
                        t: t,
                        value: s.activeKcalFor(selSteps).toDouble(),
                        target: 500,
                        color: EcoColors.fat,
                        unit: l.unit('kcal'),
                        label: l.t('steps.burned'),
                        animateFromZero: true,
                      ),
                      const SizedBox(height: 20),
                      ProgressScale(
                        t: t,
                        value: s.activeMinutesFor(selSteps).toDouble(),
                        target: 60,
                        color: EcoColors.carb,
                        unit: l.unit('min'),
                        label: l.t('steps.activeTime'),
                        animateFromZero: true,
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
