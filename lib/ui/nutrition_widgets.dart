import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Итоговая шкала калорий приёма/дня. Раньше идентичный виджет был продублирован
/// как `_TotalCaloriesSummary` в `dayview.dart` и `meallog.dart`.
class TotalCaloriesSummary extends StatelessWidget {
  final String label;
  final int total;
  final double target;
  final String unit;

  const TotalCaloriesSummary({
    super.key,
    required this.label,
    required this.total,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return ProgressScale(
      t: t,
      value: total.toDouble(),
      target: target,
      color: EcoColors.cal,
      unit: unit,
      label: label,
    );
  }
}

/// Строка вклада продукта в нутриент. Раньше один и тот же layout существовал в
/// двух копиях: `_ContributionRow` (dayview) и `_MealMacroContributionRow`
/// (meallog).
class NutrientContributionRow extends StatelessWidget {
  final String name;
  final String value;
  final bool last;

  const NutrientContributionRow({
    super.key,
    required this.name,
    required this.value,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: t.sub,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 86,
                child: Text(
                  value,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),
      ],
    );
  }
}
