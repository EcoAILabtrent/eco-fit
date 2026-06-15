import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'addfood.dart';

/// Журнал питания — port of logscreens.jsx::MealLog.
class MealLogScreen extends StatefulWidget {
  final String mealKey;
  final String? date; // null = today
  const MealLogScreen({super.key, required this.mealKey, this.date});

  @override
  State<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends State<MealLogScreen> {
  static const t = EcoTheme.meadow;
  late String mealKey = widget.mealKey;
  String? get date => widget.date;

  Meal get meal =>
      kMeals.firstWhere((m) => m.key == mealKey, orElse: () => kMeals[1]);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final items = s.itemsFor(mealKey, date: date);
    final time = s.mealTime(mealKey);

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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddFoodScreen(mealKey: mealKey, date: date),
                  ),
                ),
                child: Text(l.t('common.add')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EcoBtn(
                t: t,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(l.t('common.done')),
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
            title: l.t('food.diary'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              children: [
                // meal dropdown + time pill
                Center(
                  child: Column(
                    children: [
                      PopupMenuButton<String>(
                        color: t.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (k) => setState(() => mealKey = k),
                        itemBuilder: (_) => [
                          for (final m in kMealsByTime)
                            PopupMenuItem(
                              value: m.key,
                              child: Text(
                                l.meal(m.key),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: m.key == mealKey
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.meal(meal.key),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_down, size: 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickTime(context, time),
                        child: EcoPill(
                          t: t,
                          bg: t.band,
                          text: time,
                          fontSize: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                EcoCard(
                  t: t,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('food.products'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 50),
                            child: Center(
                              child: Text(
                                l.t('food.emptyMeal'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: EcoColors.sub,
                                ),
                              ),
                            ),
                          ),
                        for (final (i, it) in items.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1.5,
                              thickness: 1.5,
                              color: t.bandSoft,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                CalBadge(t: t, value: it.kcal, size: 48),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context
                                      .read<AppStore>()
                                      .removeFood(mealKey, i, date: date),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: t.band,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 20,
                                      color: t.dark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

  void _pickTime(BuildContext context, String current) {
    final l = context.l10nRead;
    final parts = current.split(':');
    var h = int.tryParse(parts[0]) ?? 8;
    var mi = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    showEcoSheet(
      context: context,
      t: t,
      title: l.t('common.setTime'),
      onDone: () => context.read<AppStore>().setMealTime(
        mealKey,
        '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
      ),
      body: SizedBox(
        height: 130,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: h),
                itemExtent: 36,
                onSelectedItemChanged: (v) => h = v,
                children: [
                  for (var i = 0; i < 24; i++)
                    Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              ':',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.dark,
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: mi),
                itemExtent: 36,
                onSelectedItemChanged: (v) => mi = v,
                children: [
                  for (var i = 0; i < 60; i++)
                    Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
