import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'home.dart' show showMealPicker;

/// Дневник дня «Еда» — port of logscreens.jsx::DayView.
/// Today (rightmost) is live store data; earlier days are demo history until
/// per-day logging lands with the Supabase sync phase.
class DayViewScreen extends StatefulWidget {
  const DayViewScreen({super.key});

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayHist {
  final int consumed, carb, fat, prot;
  final Map<String, int> meals;
  const _DayHist(this.consumed, this.carb, this.fat, this.prot, this.meals);
}

const _history = [
  _DayHist(1832, 598, 401, 322, {'breakfast': 415, 'lunch': 640, 'dinner': 510, 'snackM': 95, 'snackD': 102, 'snackE': 70}),
  _DayHist(2104, 705, 480, 410, {'breakfast': 480, 'lunch': 700, 'dinner': 560, 'snackM': 130, 'snackD': 120, 'snackE': 114}),
  _DayHist(1948, 640, 430, 355, {'breakfast': 430, 'lunch': 665, 'dinner': 540, 'snackM': 105, 'snackD': 118, 'snackE': 90}),
  _DayHist(1620, 530, 355, 300, {'breakfast': 360, 'lunch': 590, 'dinner': 450, 'snackM': 80, 'snackD': 90, 'snackE': 50}),
  _DayHist(2210, 740, 505, 430, {'breakfast': 505, 'lunch': 730, 'dinner': 610, 'snackM': 125, 'snackD': 140, 'snackE': 100}),
  _DayHist(1895, 620, 418, 348, {'breakfast': 440, 'lunch': 660, 'dinner': 525, 'snackM': 95, 'snackD': 105, 'snackE': 70}),
];

class _DayViewScreenState extends State<DayViewScreen> {
  static const t = EcoTheme.meadow;
  int sel = 6; // today

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final today = sel >= _history.length;
    final h = today ? null : _history[sel];

    // Macro grams: real for today (from the diary), derived from the day's
    // kcal via the 45/30/25 split for the demo history days.
    final consumed = today ? s.consumed : h!.consumed;
    final m = dayMacros(s, sel);

    final bars = [
      (label: '', value: consumed.toDouble(), goal: s.goalKcal, max: (s.goalKcal * 1.4).round(), color: EcoColors.cal, soft: EcoColors.calSoft, head: true, zoneLo: s.goalKcal * 0.92, zoneHi: s.goalKcal * 1.05),
      (label: 'Углеводы', value: m.carbs, goal: s.carbGoal, max: (s.carbGoal * 1.6).round(), color: EcoColors.carb, soft: EcoColors.carbSoft, head: false, zoneLo: s.carbGoal * 0.85, zoneHi: s.carbGoal * 1.05),
      (label: 'Жиры', value: m.fat, goal: s.fatGoal, max: (s.fatGoal * 1.6).round(), color: EcoColors.fat, soft: EcoColors.fatSoft, head: false, zoneLo: s.fatGoal * 0.85, zoneHi: s.fatGoal * 1.05),
      (label: 'Белки', value: m.protein, goal: s.protGoal, max: (s.protGoal * 1.6).round(), color: EcoColors.prot, soft: EcoColors.protSoft, head: false, zoneLo: s.protGoal * 0.85, zoneHi: s.protGoal * 1.05),
    ];

    final now = DateTime.now();
    const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

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
          EcoTopBar(t: t, title: 'Еда', onBack: () => Navigator.of(context).pop()),
          Padding(
            padding: EdgeInsets.only(bottom: 150 + MediaQuery.of(context).padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Week rings selector
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _dayRing(
                        s,
                        i,
                        wd[(now.subtract(Duration(days: 6 - i)).weekday - 1) % 7],
                        '${now.subtract(Duration(days: 6 - i)).day}',
                      ),
                  ],
                ),
              ),

              // Bars card
              EcoCard(
                t: t,
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pushNamed('/nutrition'),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: [
                        const Expanded(
                          child: Text('Сведение о питании', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.chevron_right, size: 22, color: t.dark),
                      ]),
                    ),
                  ),
                  for (final (i, b) in bars.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: i < bars.length - 1 ? 18 : 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          if (b.head)
                            Text.rich(TextSpan(children: [
                              TextSpan(text: '${b.value}', style: const TextStyle(color: EcoColors.ink)),
                              TextSpan(text: ' /${b.goal} ккал', style: const TextStyle(color: EcoColors.sub, fontWeight: FontWeight.w600)),
                            ]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                          else ...[
                            Text(b.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('${b.value.round()} / ${b.goal} г', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: EcoColors.sub)),
                          ],
                        ]),
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
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2E2E30))),
                          Text('${b.max}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2E2E30))),
                        ]),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Container(width: 14, height: 13, decoration: BoxDecoration(color: t.dark, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    const Text('Целевой промежуток', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EcoColors.sub)),
                  ]),
                ]),
              ),

              // Журнал питания
              EcoCard(
                t: t,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Журнал питания', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final (i, meal) in kMealsByTime.indexed) ...[
                    if (i > 0) Divider(height: 1.5, thickness: 1.5, color: t.bandSoft),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: today
                          ? () => Navigator.of(context).pushNamed('/meallog', arguments: meal.key)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          CalBadge(t: t, value: today ? s.mealKcal(meal.key) : (h!.meals[meal.key] ?? 0), size: 48),
                          const SizedBox(width: 14),
                          Expanded(child: Text(meal.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                          if (today) ...[
                            Container(width: 2, height: 20, decoration: BoxDecoration(color: t.olive, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Icon(Icons.add, size: 22, color: t.dark),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Macro grams for the given day index: real (diary) for today, derived from
  /// the demo history day's kcal otherwise.
  static ({double protein, double carbs, double fat}) dayMacros(AppStore s, int i) {
    if (i >= _history.length) return s.macros;
    final kcal = _history[i].consumed;
    return (protein: kcal * 0.30 / 4, carbs: kcal * 0.45 / 4, fat: kcal * 0.25 / 9);
  }

  Widget _dayRing(AppStore s, int i, String wd, String day) {
    final active = i == sel;
    final d = dayMacros(s, i);
    return GestureDetector(
      onTap: () => setState(() => sel = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        constraints: const BoxConstraints(minWidth: 46),
        decoration: BoxDecoration(
          color: active ? t.band : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(children: [
          Text(wd, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? t.dark : EcoColors.sub)),
          const SizedBox(height: 7),
          MacroRings(size: 36, data: [
            MacroRingData(value: d.carbs, goal: s.carbGoal.toDouble(), color: EcoColors.carb, soft: EcoColors.carbSoft),
            MacroRingData(value: d.fat, goal: s.fatGoal.toDouble(), color: EcoColors.fat, soft: EcoColors.fatSoft),
            MacroRingData(value: d.protein, goal: s.protGoal.toDouble(), color: EcoColors.prot, soft: EcoColors.protSoft),
          ]),
          const SizedBox(height: 7),
          Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? t.dark : EcoColors.ink)),
        ]),
      ),
    );
  }
}
