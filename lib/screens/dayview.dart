import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'home.dart' show showMealPicker;
import 'meallog.dart';

/// Дневник «Еда» — real per-date food diary with a day strip on top (last 7
/// days, today rightmost). Selecting a day shows that day's logged food,
/// macros and calories from the offline diary store.
class DayViewScreen extends StatefulWidget {
  const DayViewScreen({super.key});

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends State<DayViewScreen> {
  static const t = EcoTheme.meadow;
  int offset = 0; // days back from today (0 = today)

  DateTime get _selectedDate => DateTime.now().subtract(Duration(days: offset));
  String get _dateKey => AppStore.ymd(_selectedDate);
  bool get _isToday => offset == 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final consumed = s.consumedOn(_dateKey);
    final m = s.macrosOn(_dateKey);

    final bars = [
      (
        label: '',
        value: consumed.toDouble(),
        goal: s.goalKcal,
        max: (s.goalKcal * 1.4).round(),
        color: EcoColors.cal,
        soft: EcoColors.calSoft,
        head: true,
        zoneLo: s.goalKcal * 0.92,
        zoneHi: s.goalKcal * 1.05,
      ),
      (
        label: l.nutrient('carbs'),
        value: m.carbs,
        goal: s.carbGoal,
        max: (s.carbGoal * 1.6).round(),
        color: EcoColors.carb,
        soft: EcoColors.carbSoft,
        head: false,
        zoneLo: s.carbGoal * 0.85,
        zoneHi: s.carbGoal * 1.05,
      ),
      (
        label: l.nutrient('fat'),
        value: m.fat,
        goal: s.fatGoal,
        max: (s.fatGoal * 1.6).round(),
        color: EcoColors.fat,
        soft: EcoColors.fatSoft,
        head: false,
        zoneLo: s.fatGoal * 0.85,
        zoneHi: s.fatGoal * 1.05,
      ),
      (
        label: l.nutrient('protein'),
        value: m.protein,
        goal: s.protGoal,
        max: (s.protGoal * 1.6).round(),
        color: EcoColors.prot,
        soft: EcoColors.protSoft,
        head: false,
        zoneLo: s.protGoal * 0.85,
        zoneHi: s.protGoal * 1.05,
      ),
    ];

    return EcoScreen(
      t: t,
      footer: EcoBottomNav(
        t: t,
        active: 'home',
        onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onProfile: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          Navigator.of(context).pushNamed('/profile');
        },
        onPlus: () => showMealPicker(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('home.food'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 150 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Day strip: last 7 days, today rightmost ──
                _DayStrip(
                  offset: offset,
                  onSelect: (o) => setState(() => offset = o),
                  store: s,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _isToday ? l.t('common.today') : l.dayMonth(_selectedDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: EcoColors.sub,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Bars card ──
                EcoCard(
                  t: t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          l.t('food.nutritionSummary'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final (i, b) in bars.indexed)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i < bars.length - 1 ? 18 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (b.head)
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${b.value.round()}',
                                            style: const TextStyle(
                                              color: EcoColors.ink,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' /${b.goal} ${l.unit('kcal')}',
                                            style: const TextStyle(
                                              color: EcoColors.sub,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      b.label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${b.value.round()} / ${b.goal} ${l.unit('g')}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: EcoColors.sub,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              ValueBar(
                                t: t,
                                value: b.value.toDouble(),
                                max: b.max.toDouble(),
                                color: b.color,
                                soft: b.soft,
                                zoneLo: b.zoneLo,
                                zoneHi: b.zoneHi,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E2E30),
                                    ),
                                  ),
                                  Text(
                                    '${b.max}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E2E30),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
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
                            l.t('common.targetRange'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: EcoColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Журнал питания (tap a meal → that day's meal log) ──
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('food.diary'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final (i, meal) in kMealsByTime.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1.5,
                            thickness: 1.5,
                            color: t.bandSoft,
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MealLogScreen(
                                mealKey: meal.key,
                                date: _isToday ? null : _dateKey,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                CalBadge(
                                  t: t,
                                  value: s.mealKcal(meal.key, date: _dateKey),
                                  size: 48,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    l.meal(meal.key),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: t.olive,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.add, size: 22, color: t.dark),
                              ],
                            ),
                          ),
                        ),
                      ],
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

/// Horizontal strip of the last 7 days — today rightmost, each cell shows the
/// weekday, date, a goal-progress ring and a fill state.
class _DayStrip extends StatelessWidget {
  final int offset;
  final ValueChanged<int> onSelect;
  final AppStore store;

  const _DayStrip({
    required this.offset,
    required this.onSelect,
    required this.store,
  });

  static const t = EcoTheme.meadow;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var o = 6; o >= 0; o--)
          _cell(now.subtract(Duration(days: o)), o, l),
      ],
    );
  }

  Widget _cell(DateTime date, int o, AppStrings l) {
    final active = o == offset;
    final key = AppStore.ymd(date);
    final m = store.macrosOn(key);
    return GestureDetector(
      onTap: () => onSelect(o),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        constraints: const BoxConstraints(minWidth: 44),
        decoration: BoxDecoration(
          color: active ? t.band : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              l.weekdayShort(date.weekday),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? t.dark : EcoColors.sub,
              ),
            ),
            const SizedBox(height: 6),
            MacroRings(
              size: 32,
              data: [
                MacroRingData(
                  value: m.carbs,
                  goal: store.carbGoal.toDouble(),
                  color: EcoColors.carb,
                  soft: EcoColors.carbSoft,
                ),
                MacroRingData(
                  value: m.fat,
                  goal: store.fatGoal.toDouble(),
                  color: EcoColors.fat,
                  soft: EcoColors.fatSoft,
                ),
                MacroRingData(
                  value: m.protein,
                  goal: store.protGoal.toDouble(),
                  color: EcoColors.prot,
                  soft: EcoColors.protSoft,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? t.dark : EcoColors.ink,
              ),
            ),
            // "today" marker dot
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: o == 0
                    ? (active ? t.dark : t.olive)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
