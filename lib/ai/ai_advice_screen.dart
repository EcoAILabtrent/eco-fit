import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../nutrition/micronutrient_display.dart';
import '../nutrition/micronutrients.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'advice_view.dart';
import 'ai_advice_contract.dart';
import 'ai_advice_service.dart';
import 'ai_config.dart';
import 'saved_advice.dart';

/// Полноэкранная страница ИИ-совета (роут `/aiAdvice`). Две вкладки: «Новый
/// совет» (выбор периода, генерация, сохранение, разбор микронутриентов) и
/// «Сохранённые» (список ранее сохранённых советов). Логика генерации/сети/
/// «печати» перенесена сюда из прежней инлайн-карточки на главной.
class AiAdviceScreen extends StatefulWidget {
  const AiAdviceScreen({super.key});

  @override
  State<AiAdviceScreen> createState() => _AiAdviceScreenState();
}

class _AiAdviceScreenState extends State<AiAdviceScreen> {
  static const _service = AiAdviceService();

  int _tab = 0; // 0 = новый совет, 1 = сохранённые
  bool _checking = false;
  bool _loading = false;
  bool? _online;
  AiAdvicePeriod _period = AiAdvicePeriod.day;
  String? _advice;
  bool _saved = false;
  // Порядок и разметка блоков результата (КБЖУ + критичные нутриенты) для
  // «печати по буквам»: единый сценарий `_script` печатается посимвольно, а
  // каждый блок берёт свою видимую часть по смещению [_Seg.start].
  List<_Seg> _segs = const [];
  String _script = '';

  // Раскрываемый («печатающийся») текст — обновляет только список советов.
  final ValueNotifier<String> _revealed = ValueNotifier<String>('');
  Timer? _typingTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnline());
  }

  @override
  void dispose() {
    _stopTyping();
    _revealed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>((s) => s.diaryRevision);
    context.select<AppStore, int>((s) => s.aiAdvices.length);
    final store = context.read<AppStore>();
    final l = context.l10n;

    return EcoScreen(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoTopBar(
            t: t,
            title: l.t('ai.pageTitle'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Center(child: _AiRobot(t: t)),
          const SizedBox(height: 16),
          EcoSegmented(
            t: t,
            options: [l.t('ai.tabNew'), l.t('ai.tabSaved')],
            value: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.only(
              bottom: 32 + MediaQuery.of(context).padding.bottom,
            ),
            child: _tab == 0
                ? _buildNewTab(context, store, l, t)
                : _buildSavedTab(context, store, l, t),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Новый совет ───────────────────────────

  Widget _buildNewTab(
    BuildContext context,
    AppStore store,
    AppStrings l,
    EcoTheme t,
  ) {
    // Готовый совет показываем новой раскладкой: КБЖУ → критичные нутриенты →
    // микронутриенты за период → дисклеймер/кнопки. До генерации/во время
    // загрузки — прежний экран (выбор периода, вступление, кнопка).
    if (_advice != null && !_loading) {
      return _buildResult(context, store, l, t);
    }
    return _buildIdle(context, store, l, t);
  }

  Widget _buildIdle(
    BuildContext context,
    AppStore store,
    AppStrings l,
    EcoTheme t,
  ) {
    final foodCount = _foodCount(store, _period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EcoCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_advice == null && !_loading) ...[
                Text(
                  _periodPrompt(l),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                EcoSegmented(
                  t: t,
                  options: _periodOptions(l),
                  value: _period.index,
                  onChanged: _setPeriod,
                ),
                const SizedBox(height: 14),
              ],
              _resultArea(store, l, t, foodCount),
              if (_advice != null && !_loading) ...[
                const SizedBox(height: 10),
                Text(
                  l.t('ai.disclaimer'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: t.sub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!_loading) ...[
                const SizedBox(height: 16),
                _actions(store, l, t, foodCount),
              ],
            ],
          ),
        ),
        // Карточка «Микронутриенты за период» показывается только вместе с
        // готовым советом (см. _buildResult), а не на стартовом экране.
      ],
    );
  }

  // ───────────── Результат: КБЖУ + критичные нутриенты + бары ─────────────

  Widget _buildResult(
    BuildContext context,
    AppStore store,
    AppStrings l,
    EcoTheme t,
  ) {
    final macro = _segs.isNotEmpty ? _segs.first : null;
    final crits = _segs.length > 1 ? _segs.sublist(1) : const <_Seg>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // КБЖУ — прежний текст совета, печатается по буквам.
        EcoCard(
          t: t,
          child: ValueListenableBuilder<String>(
            valueListenable: _revealed,
            builder: (context, revealed, _) {
              final n = revealed.length;
              final text = macro == null ? '' : _visible(macro, n);
              final typing =
                  macro != null && n >= macro.start && n < macro.end;
              return AdviceBulletList(t: t, text: text, showCursor: typing);
            },
          ),
        ),
        if (crits.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(l, t),
          for (final seg in crits) ...[
            const SizedBox(height: 10),
            _criticalCard(seg, store, l, t),
          ],
        ],
        const SizedBox(height: 12),
        _microsCard(store, l, t),
        const SizedBox(height: 12),
        EcoCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('ai.disclaimer'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: t.sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _actions(store, l, t, _foodCount(store, _period)),
            ],
          ),
        ),
      ],
    );
  }

  /// Карточка одного критичного нутриента: заголовок (без дублирования имени в
  /// шкале), анимированная шкала [ProgressScale] и печатаемый текст-последствие.
  Widget _criticalCard(_Seg seg, AppStore store, AppStrings l, EcoTheme t) {
    final key = seg.critKey!;
    final crit = seg.crit!;
    final color = micronutrientColor(key);
    return EcoCard(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.nutrient(key),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
              _critChip(crit.excess, l),
            ],
          ),
          const SizedBox(height: 12),
          ProgressScale(
            t: t,
            value: crit.perDay,
            target: crit.target,
            color: color,
            unit: l.unit(microUnitCode(key)),
            animateFromZero: true,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _revealed,
            builder: (context, revealed, _) {
              final n = revealed.length;
              final typing = n >= seg.start && n < seg.end;
              return Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, height: 1.45, color: t.sub),
                  children: [
                    TextSpan(text: _visible(seg, n)),
                    if (typing)
                      const TextSpan(
                        text: '|',
                        style: TextStyle(
                          color: EcoColors.statusGood,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _critChip(bool excess, AppStrings l) {
    final base = excess ? const Color(0xFFA96666) : const Color(0xFFB07A34);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            excess ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: base,
          ),
          const SizedBox(width: 3),
          Text(
            _critLabel(excess, l.language),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: base,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppStrings l, EcoTheme t) {
    final label = switch (l.language) {
      AppLanguage.ru => 'Критичные показатели',
      AppLanguage.en => 'Critical values',
      AppLanguage.uzLatn => 'Muhim koʼrsatkichlar',
      AppLanguage.uzCyrl => 'Муҳим кўрсаткичлар',
    };
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFA96666),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
  }

  String _critLabel(bool excess, AppLanguage lang) => switch (lang) {
        AppLanguage.ru => excess ? 'Избыток' : 'Дефицит',
        AppLanguage.en => excess ? 'Excess' : 'Deficit',
        AppLanguage.uzLatn => excess ? 'Ortiqcha' : 'Kamlik',
        AppLanguage.uzCyrl => excess ? 'Ортиқча' : 'Камлик',
      };

  String _visible(_Seg seg, int n) {
    final take = (n - seg.start).clamp(0, seg.text.length);
    return seg.text.substring(0, take);
  }

  /// Разбирает готовую строку совета на КБЖУ-блок и критичные нутриенты и
  /// собирает единый сценарий печати `_script` (порядок = порядок на экране).
  void _prepareResult(String advice, AppStore store) {
    final lang = store.language;
    final parsed = _parseAdvice(advice, lang);
    final criticals = _criticalMicros(store);
    const macroTopics = [
      AiAdviceTopic.calories,
      AiAdviceTopic.protein,
      AiAdviceTopic.fat,
      AiAdviceTopic.carbohydrates,
    ];
    final macroLines = [
      for (final tp in macroTopics)
        if (parsed[tp] != null)
          '${AiAdviceContract.title(tp, lang)}: ${parsed[tp]}',
    ];
    final segs = <_Seg>[];
    var cursor = 0;
    final macroText = macroLines.join('\n');
    segs.add(_Seg(start: cursor, text: macroText));
    cursor += macroText.length;
    for (final c in criticals) {
      final tp = _microTopic(c.key);
      final text = (tp != null ? parsed[tp] : null) ?? '';
      if (text.isEmpty) continue;
      segs.add(_Seg(start: cursor, text: text, critKey: c.key, crit: c));
      cursor += text.length;
    }
    _segs = segs;
    _script = segs.map((s) => s.text).join();
  }

  Map<AiAdviceTopic, String> _parseAdvice(String advice, AppLanguage lang) {
    final byTitle = {
      for (final tp in AiAdviceTopic.values)
        AiAdviceContract.title(tp, lang): tp,
    };
    final map = <AiAdviceTopic, String>{};
    for (final line in advice.split('\n')) {
      final idx = line.indexOf(': ');
      if (idx <= 0) continue;
      final tp = byTitle[line.substring(0, idx)];
      if (tp != null) map[tp] = line.substring(idx + 2).trim();
    }
    return map;
  }

  /// Критичные нутриенты: сильный дефицит (<=50% нормы) или превышение
  /// безопасного предела (UL, а для натрия — CDRR). Форм-специфичные UL
  /// (mg, vit_a, vit_e, vit_b3, vit_b9) как «избыток из еды» не считаем.
  List<_Crit> _criticalMicros(AppStore store) {
    final period = _periodMicros(store);
    if (period.totals.isEmpty) return const [];
    final days = math.max(1, period.loggedDays);
    final targets = _microTargets(store);
    final female = store.gender == 'f';
    const formSpecific = {'mg', 'vit_a', 'vit_e', 'vit_b3', 'vit_b9'};
    final out = <_Crit>[];
    for (final entry in period.totals.entries) {
      final key = entry.key;
      if (_microTopic(key) == null) continue;
      final perDay = entry.value / days;
      if (perDay <= 0) continue;
      final mt = targets[key];
      final target = mt?.target ?? adultMicronutrientTarget(key, female: female);
      if (target == null || target <= 0) continue;
      final ratio = perDay / target;
      final ul = mt?.ul;
      final cdrr = mt?.cdrr;
      bool? excess;
      if (key == 'na' && cdrr != null && perDay > cdrr) {
        excess = true;
      } else if (ul != null && !formSpecific.contains(key) && perDay > ul) {
        excess = true;
      } else if (ratio <= 0.5) {
        excess = false;
      }
      if (excess == null) continue;
      out.add(_Crit(
        key: key,
        perDay: perDay,
        target: target,
        excess: excess,
        ratio: ratio,
      ));
    }
    out.sort((a, b) {
      if (a.excess != b.excess) return a.excess ? -1 : 1;
      if (a.excess) return b.ratio.compareTo(a.ratio);
      return a.ratio.compareTo(b.ratio);
    });
    return out;
  }

  AiAdviceTopic? _microTopic(String key) => switch (key) {
        'fe' => AiAdviceTopic.iron,
        'mg' => AiAdviceTopic.magnesium,
        'ca' => AiAdviceTopic.calcium,
        'p' => AiAdviceTopic.phosphorus,
        'k' => AiAdviceTopic.potassium,
        'na' => AiAdviceTopic.sodium,
        'zn' => AiAdviceTopic.zinc,
        'vit_a' => AiAdviceTopic.vitaminA,
        'vit_c' => AiAdviceTopic.vitaminC,
        'vit_d' => AiAdviceTopic.vitaminD,
        'vit_e' => AiAdviceTopic.vitaminE,
        'vit_k' => AiAdviceTopic.vitaminK,
        'vit_b1' => AiAdviceTopic.vitaminB1,
        'vit_b2' => AiAdviceTopic.vitaminB2,
        'vit_b3' => AiAdviceTopic.vitaminB3,
        'vit_b6' => AiAdviceTopic.vitaminB6,
        'vit_b9' => AiAdviceTopic.vitaminB9,
        'vit_b12' => AiAdviceTopic.vitaminB12,
        _ => null,
      };

  Widget _resultArea(
    AppStore store,
    AppStrings l,
    EcoTheme t,
    int foodCount,
  ) {
    if (_loading) {
      return _LoadingBody(t: t, label: l.t('ai.loading'));
    }
    if (_advice == null) {
      return Text(
        _introText(l, foodCount),
        style: TextStyle(fontSize: 14, height: 1.45, color: t.sub),
      );
    }
    return ValueListenableBuilder<String>(
      valueListenable: _revealed,
      builder: (context, revealed, _) {
        final full = _advice ?? '';
        final typing = revealed.length < full.length;
        return AdviceBulletList(
          t: t,
          text: typing ? revealed : full,
          showCursor: typing,
        );
      },
    );
  }

  Widget _actions(AppStore store, AppStrings l, EcoTheme t, int foodCount) {
    final canGenerate =
        AiConfig.hasBackend && _online != false && foodCount > 0;

    if (_advice != null) {
      return Row(
        children: [
          Expanded(
            child: EcoBtn(
              t: t,
              height: 38,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              disabled: _saved,
              onTap: _saved ? null : () => _saveCurrentAdvice(store),
              child: Text(_saved ? l.t('ai.saved') : l.t('ai.save')),
            ),
          ),
          const SizedBox(width: 8),
          _IconChip(
            t: t,
            icon: Icons.refresh,
            onTap: canGenerate ? () => _loadAdvice(store) : null,
          ),
          const SizedBox(width: 8),
          _IconChip(t: t, icon: Icons.close, onTap: _clearAdvice),
        ],
      );
    }

    if (!AiConfig.hasBackend) return const SizedBox.shrink();

    if (_online == false) {
      return EcoBtn(
        t: t,
        height: 38,
        fontSize: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: _checkOnline,
        child: Text(l.t('ai.retry')),
      );
    }

    return Row(
      children: [
        Expanded(
          child: EcoBtn(
            t: t,
            height: 38,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            disabled: !canGenerate,
            onTap: canGenerate ? () => _loadAdvice(store) : null,
            child: Text(l.t('ai.generate')),
          ),
        ),
      ],
    );
  }

  String _introText(AppStrings l, int foodCount) {
    if (!AiConfig.hasBackend) return l.t('ai.notConfigured');
    if (_checking) return l.t('ai.checking');
    if (_online == false) return l.t('ai.offline');
    if (_error != null) {
      return kDebugMode ? '${l.t('ai.error')}\n$_error' : l.t('ai.error');
    }
    if (foodCount == 0) return _noFoodText(l);
    return _readyText(l);
  }

  // ─────────────────────── Микронутриенты за период ───────────────────────

  Widget _microsCard(AppStore store, AppStrings l, EcoTheme t) =>
      _MicrosPeriodCard(t: t, l: l, rows: _microRows(store, l, t));

  List<Widget> _microRows(AppStore store, AppStrings l, EcoTheme t) {
    final period = _periodMicros(store);
    if (period.totals.isEmpty) return const [];
    // Норма (target) — СУТОЧНАЯ. Поэтому потребление приводим к среднему за день:
    // сумму за период делим на число дней с записями. Иначе за неделю/месяц
    // сравнивалась бы 7-/30-дневная сумма с 1-дневной нормой (полоса всегда
    // «переполнена»). Для дня делитель = 1, значения не меняются.
    final days = math.max(1, period.loggedDays);
    final targets = _microTargets(store);
    final female = store.gender == 'f';

    final orderedKeys = [
      ...kMicronutrientDisplayOrder.where(period.totals.containsKey),
      for (final key in period.totals.keys)
        if (!kMicronutrientDisplayOrder.contains(key)) key,
    ];

    final rows = <Widget>[];
    for (final key in orderedKeys) {
      final perDay = (period.totals[key] ?? 0) / days;
      if (perDay <= 0) continue;
      final target =
          targets[key]?.target ?? adultMicronutrientTarget(key, female: female);
      rows.add(
        ProgressScale(
          t: t,
          value: perDay,
          target: (target != null && target > 0) ? target : perDay,
          color: micronutrientColor(key),
          unit: l.unit(microUnitCode(key)),
          label: l.nutrient(key),
        ),
      );
    }
    return rows;
  }

  ({Map<String, double> totals, int loggedDays}) _periodMicros(AppStore store) {
    final totals = <String, double>{};
    var loggedDays = 0;
    for (var i = 0; i < _period.days; i++) {
      final date = AppStore.ymd(DateTime.now().subtract(Duration(days: i)));
      final hasFood =
          kMealsByTime.any((m) => store.itemsFor(m.key, date: date).isNotEmpty);
      if (hasFood) loggedDays++;
      store.microsOn(date).forEach((key, value) {
        totals.update(key, (current) => current + value, ifAbsent: () => value);
      });
    }
    return (totals: totals, loggedDays: loggedDays);
  }

  Map<String, MicroTarget> _microTargets(AppStore store) {
    final weight = store.weightKg ?? (store.weight > 0 ? store.weight : 66.0);
    final profile = NutritionProfile(
      ageYears: store.age ?? 28,
      sex: store.gender == 'f' ? ProfileSex.female : ProfileSex.male,
      weightKg: weight,
      heightCm: (store.heightCm ?? 178).toDouble(),
    );
    return {
      for (final target in calculateMicroTargets(
        profile,
        databaseNutrientKeys: FoodDb.instance.availableMicronutrientKeys,
      ))
        target.key: target,
    };
  }

  // ─────────────────────────── Сохранённые ───────────────────────────

  Widget _buildSavedTab(
    BuildContext context,
    AppStore store,
    AppStrings l,
    EcoTheme t,
  ) {
    final advices = store.aiAdvices;
    if (advices.isEmpty) {
      return EcoCard(
        t: t,
        child: Column(
          children: [
            Icon(Icons.bookmark_border, size: 36, color: t.faint),
            const SizedBox(height: 12),
            Text(
              l.t('ai.emptySaved'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: t.sub),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final advice in advices)
          _SavedAdviceCard(
            key: ValueKey(advice.id),
            t: t,
            l: l,
            advice: advice,
            periodLabel: _periodOptions(l)[advice.period.index],
            onDelete: () => store.deleteAiAdvice(advice.id),
          ),
      ],
    );
  }

  // ─────────────────────────── Логика ───────────────────────────

  int _foodCount(AppStore store, AiAdvicePeriod period) {
    var count = 0;
    for (var i = 0; i < period.days; i++) {
      final date = AppStore.ymd(DateTime.now().subtract(Duration(days: i)));
      for (final meal in kMealsByTime) {
        count += store.itemsFor(meal.key, date: date).length;
      }
    }
    return count;
  }

  Future<void> _checkOnline() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final online = await _service.hasInternet();
    if (!mounted) return;
    setState(() {
      _online = online;
      _checking = false;
    });
  }

  Future<void> _loadAdvice(AppStore store) async {
    final startedAt = DateTime.now();
    _stopTyping();
    _revealed.value = '';
    setState(() {
      _loading = true;
      _error = null;
      _saved = false;
    });
    try {
      final advice = await _service.fetchDailyAdvice(
        store: store,
        language: store.language,
        period: _period,
      );
      final elapsed = DateTime.now().difference(startedAt);
      const minimumLoaderDuration = Duration(milliseconds: 2400);
      if (elapsed < minimumLoaderDuration) {
        await Future<void>.delayed(minimumLoaderDuration - elapsed);
      }
      if (!mounted) return;
      _revealed.value = '';
      _prepareResult(advice, store);
      setState(() {
        _advice = advice;
        _loading = false;
        _online = true;
        _saved = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || _advice != advice) return;
      _startTyping(_script);
    } on Object catch (error) {
      debugPrint('AI advice failed: $error');
      if (!mounted) return;
      setState(() {
        _error = '$error';
        if ('$error'.toLowerCase().contains('internet')) _online = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _saveCurrentAdvice(AppStore store) {
    final advice = _advice;
    if (advice == null || advice.trim().isEmpty) return;
    final now = DateTime.now();
    // Сохраняем значения шкал, чтобы «Сохранённые» показывали совет так же, как
    // режим генерации: критичные нутриенты со шкалами + бары за период.
    final criticals = [
      for (final seg in _segs)
        if (seg.crit != null)
          SavedNutrient(
            key: seg.crit!.key,
            value: seg.crit!.perDay,
            target: seg.crit!.target,
            excess: seg.crit!.excess,
          ),
    ];
    store.saveAiAdvice(
      SavedAiAdvice(
        id: now.millisecondsSinceEpoch.toString(),
        text: advice,
        period: _period,
        createdAt: now,
        languageCode: store.language.code,
        criticals: criticals,
        micros: _savedMicros(store),
      ),
    );
    setState(() => _saved = true);
  }

  /// Все микронутриенты за период (значение за день + норма) — для шкал в
  /// «Сохранённых». Порядок и фильтрация совпадают с [_microRows].
  List<SavedNutrient> _savedMicros(AppStore store) {
    final period = _periodMicros(store);
    if (period.totals.isEmpty) return const [];
    final days = math.max(1, period.loggedDays);
    final targets = _microTargets(store);
    final female = store.gender == 'f';
    final orderedKeys = [
      ...kMicronutrientDisplayOrder.where(period.totals.containsKey),
      for (final key in period.totals.keys)
        if (!kMicronutrientDisplayOrder.contains(key)) key,
    ];
    final out = <SavedNutrient>[];
    for (final key in orderedKeys) {
      final perDay = (period.totals[key] ?? 0) / days;
      if (perDay <= 0) continue;
      final target =
          targets[key]?.target ?? adultMicronutrientTarget(key, female: female);
      out.add(SavedNutrient(
        key: key,
        value: perDay,
        target: (target != null && target > 0) ? target : perDay,
      ));
    }
    return out;
  }

  void _setPeriod(int index) {
    final next = AiAdvicePeriod.values[index];
    if (next == _period) return;
    _stopTyping();
    _revealed.value = '';
    _segs = const [];
    _script = '';
    setState(() {
      _period = next;
      _advice = null;
      _error = null;
      _saved = false;
    });
  }

  void _clearAdvice() {
    _stopTyping();
    _revealed.value = '';
    _segs = const [];
    _script = '';
    setState(() {
      _advice = null;
      _error = null;
      _saved = false;
    });
  }

  void _startTyping(String text) {
    _stopTyping();
    var index = 0;
    final charsPerTick = math.max(1, (text.length / 110).ceil());
    _typingTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) {
        timer.cancel();
        _typingTimer = null;
        return;
      }
      index = math.min(index + charsPerTick, text.length);
      _revealed.value = text.substring(0, index);
      if (index >= text.length) {
        timer.cancel();
        _typingTimer = null;
      }
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
  }

  List<String> _periodOptions(AppStrings l) => switch (l.language) {
        AppLanguage.en => const ['Day', 'Week', 'Month'],
        AppLanguage.ru => const ['День', 'Неделя', 'Месяц'],
        AppLanguage.uzLatn => const ['Kun', 'Hafta', 'Oy'],
        AppLanguage.uzCyrl => const ['Кун', 'Ҳафта', 'Ой'],
      };

  String _periodPrompt(AppStrings l) => switch (l.language) {
        AppLanguage.en => 'Choose the advice period',
        AppLanguage.ru => 'Выберите период совета',
        AppLanguage.uzLatn => 'Tavsiya davrini tanlang',
        AppLanguage.uzCyrl => 'Тавсия даврини танланг',
      };

  String _readyText(AppStrings l) => switch (l.language) {
        AppLanguage.en => switch (_period) {
            AiAdvicePeriod.day => "AI can review today's meals in a short note.",
            AiAdvicePeriod.week => 'AI can review your last 7 days of meals.',
            AiAdvicePeriod.month => 'AI can review your last 30 days of meals.',
          },
        AppLanguage.ru => switch (_period) {
            AiAdvicePeriod.day => 'ИИ коротко разберёт сегодняшний рацион.',
            AiAdvicePeriod.week => 'ИИ разберёт питание за последние 7 дней.',
            AiAdvicePeriod.month => 'ИИ разберёт питание за последние 30 дней.',
          },
        AppLanguage.uzLatn => switch (_period) {
            AiAdvicePeriod.day => 'AI bugungi ratsionni qisqa tahlil qiladi.',
            AiAdvicePeriod.week => 'AI oxirgi 7 kunlik ratsionni tahlil qiladi.',
            AiAdvicePeriod.month => 'AI oxirgi 30 kunlik ratsionni tahlil qiladi.',
          },
        AppLanguage.uzCyrl => switch (_period) {
            AiAdvicePeriod.day => 'ИИ бугунги рационни қисқа таҳлил қилади.',
            AiAdvicePeriod.week => 'ИИ охирги 7 кунлик рационни таҳлил қилади.',
            AiAdvicePeriod.month => 'ИИ охирги 30 кунлик рационни таҳлил қилади.',
          },
      };

  String _noFoodText(AppStrings l) => switch (l.language) {
        AppLanguage.en => switch (_period) {
            AiAdvicePeriod.day =>
              'Add foods for today, then AI will analyze them.',
            AiAdvicePeriod.week =>
              'Add foods in the last 7 days to get weekly advice.',
            AiAdvicePeriod.month =>
              'Add foods in the last 30 days to get monthly advice.',
          },
        AppLanguage.ru => switch (_period) {
            AiAdvicePeriod.day =>
              'Добавьте еду за сегодня, и ИИ её проанализирует.',
            AiAdvicePeriod.week =>
              'Добавьте еду за 7 дней, чтобы получить совет за неделю.',
            AiAdvicePeriod.month =>
              'Добавьте еду за 30 дней, чтобы получить совет за месяц.',
          },
        AppLanguage.uzLatn => switch (_period) {
            AiAdvicePeriod.day =>
              "Bugungi ovqatlarni qo'shing, keyin AI tahlil qiladi.",
            AiAdvicePeriod.week =>
              "Haftalik tavsiya uchun oxirgi 7 kunga ovqat qo'shing.",
            AiAdvicePeriod.month =>
              "Oylik tavsiya uchun oxirgi 30 kunga ovqat qo'shing.",
          },
        AppLanguage.uzCyrl => switch (_period) {
            AiAdvicePeriod.day =>
              'Бугунги овқатларни қўшинг, кейин ИИ таҳлил қилади.',
            AiAdvicePeriod.week =>
              'Ҳафталик тавсия учун охирги 7 кунга овқат қўшинг.',
            AiAdvicePeriod.month =>
              'Ойлик тавсия учун охирги 30 кунга овқат қўшинг.',
          },
      };
}

/// Крупный «живой» робот-ассистент вверху страницы: плавно покачивается, «говорит»
/// (изо рта расходятся звуковые волны), а под ним печатается и исчезает подсказка.
class _AiRobot extends StatefulWidget {
  final EcoTheme t;

  const _AiRobot({required this.t});

  @override
  State<_AiRobot> createState() => _AiRobotState();
}

class _AiRobotState extends State<_AiRobot> with TickerProviderStateMixin {
  static const double _size = 144; // 96 × 1.5

  // Покачивание вверх-вниз (плавное «парение»).
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  // Расходящиеся звуковые волны изо рта.
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  // Подсказка под роботом, печатается по буквам, затем исчезает и печатается снова.
  final ValueNotifier<String> _caption = ValueNotifier<String>('');
  Timer? _captionTimer;
  String _hint = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // l10nRead (read), а не l10n (select): select запрещён вне build().
    final next = context.l10nRead.t('ai.robotHint');
    if (next != _hint) {
      _hint = next;
      _restartCaption();
    }
  }

  void _restartCaption() {
    _captionTimer?.cancel();
    _caption.value = '';
    var index = 0;
    var mode = 0; // 0 — печать, 1 — пауза с текстом, 2 — пауза без текста
    var ticks = 0;
    _captionTimer = Timer.periodic(const Duration(milliseconds: 95), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      switch (mode) {
        case 0:
          index++;
          _caption.value = _hint.substring(0, math.min(index, _hint.length));
          if (index >= _hint.length) {
            mode = 1;
            ticks = 0;
          }
        case 1:
          if (++ticks > 18) {
            mode = 2;
            ticks = 0;
            _caption.value = '';
          }
        default:
          if (++ticks > 7) {
            mode = 0;
            index = 0;
          }
      }
    });
  }

  @override
  void dispose() {
    _captionTimer?.cancel();
    _caption.dispose();
    _float.dispose();
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size + 48,
          height: _size + 16,
          child: AnimatedBuilder(
            animation: Listenable.merge([_float, _waves]),
            builder: (context, child) {
              final dy = math.sin(_float.value * math.pi) * -9; // покачивание
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SpeechWavePainter(
                        progress: _waves.value,
                        color: const Color(0xFF4CC9E6),
                        robotSize: _size,
                        dy: dy,
                      ),
                    ),
                  ),
                  Transform.translate(offset: Offset(0, dy), child: child),
                ],
              );
            },
            child: RepaintBoundary(
              child: Image.asset(
                'assets/branding/ai_badge.png',
                width: _size,
                height: _size,
                fit: BoxFit.contain,
                cacheWidth: 384,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) =>
                    const SizedBox(width: _size, height: _size),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Фикс. высота под 2 строки: подпись длиннее и может переноситься, а
        // резерв высоты не даёт роботу «прыгать» при печати.
        SizedBox(
          height: 40,
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: _caption,
              builder: (context, text, _) {
                final typing = text.isNotEmpty && text.length < _hint.length;
                return Text(
                  text.isEmpty ? '' : (typing ? '$text|' : text),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: t.sub,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Рисует расходящиеся полукруглые «звуковые» волны из области рта робота.
class _SpeechWavePainter extends CustomPainter {
  final double progress; // 0..1, зациклено
  final Color color;
  final double robotSize;
  final double dy;

  _SpeechWavePainter({
    required this.progress,
    required this.color,
    required this.robotSize,
    required this.dy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Рот примерно на уровне лица (по центру); волны следуют за покачиванием и
    // расходятся В СТОРОНЫ от рта — в пустое пространство за пределами головы,
    // иначе их скрывает белый корпус робота.
    final top = (size.height - robotSize) / 2;
    final mouth = Offset(size.width / 2, top + robotSize * 0.46 + dy);
    const rings = 3;
    final minR = robotSize * 0.34; // начинаем у края головы
    final maxR = robotSize * 0.58;
    for (var k = 0; k < rings; k++) {
      final phase = (progress + k / rings) % 1.0;
      final radius = minR + (maxR - minR) * phase;
      final alpha = (1.0 - phase) * 0.6;
      if (alpha <= 0.02) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0 * (1 - phase) + 1.0
        ..color = color.withValues(alpha: alpha);
      final rect = Rect.fromCircle(center: mouth, radius: radius);
      // Правый и левый веер («звук» вправо и влево от рта).
      canvas.drawArc(rect, -math.pi * 0.26, math.pi * 0.52, false, paint);
      canvas.drawArc(rect, math.pi * 0.74, math.pi * 0.52, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeechWavePainter old) =>
      old.progress != progress || old.dy != dy || old.color != color;
}

class _LoadingBody extends StatelessWidget {
  final EcoTheme t;
  final String label;

  const _LoadingBody({required this.t, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        height: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EcoDotsLoader(),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: t.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAdviceCard extends StatefulWidget {
  final EcoTheme t;
  final AppStrings l;
  final SavedAiAdvice advice;
  final String periodLabel;
  final VoidCallback onDelete;

  const _SavedAdviceCard({
    super.key,
    required this.t,
    required this.l,
    required this.advice,
    required this.periodLabel,
    required this.onDelete,
  });

  @override
  State<_SavedAdviceCard> createState() => _SavedAdviceCardState();
}

class _SavedAdviceCardState extends State<_SavedAdviceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final l = widget.l;
    final advice = widget.advice;
    return EcoCard(
      t: t,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PeriodChip(t: t, label: widget.periodLabel),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.dayMonth(advice.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.sub,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDelete,
                child: Icon(Icons.delete_outline, size: 20, color: t.faint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_expanded)
            _buildSavedBody(t, l, advice)
          else
            Text(
              _preview(advice.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.42, color: t.sub),
            ),
        ],
      ),
    );
  }

  /// Разворачивает сохранённый совет в ту же раскладку, что и свежий: КБЖУ →
  /// критичные нутриенты (заголовок + шкала + текст) → бары за период. Старые
  /// советы (без сохранённых значений) показываются прежним плоским списком.
  Widget _buildSavedBody(EcoTheme t, AppStrings l, SavedAiAdvice a) {
    if (a.criticals.isEmpty && a.micros.isEmpty) {
      return AdviceBulletList(t: t, text: a.text);
    }
    final lang = AppLanguage.values.firstWhere(
      (e) => e.code == a.languageCode,
      orElse: () => l.language,
    );
    final parsed = _parseSavedAdvice(a.text, lang);
    const macroTopics = [
      AiAdviceTopic.calories,
      AiAdviceTopic.protein,
      AiAdviceTopic.fat,
      AiAdviceTopic.carbohydrates,
    ];
    final macroText = [
      for (final tp in macroTopics)
        if (parsed[tp] != null) '${AiAdviceContract.title(tp, lang)}: ${parsed[tp]}',
    ].join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (macroText.isNotEmpty) AdviceBulletList(t: t, text: macroText),
        if (a.criticals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _savedSectionHeader(lang, t),
          for (final c in a.criticals) ...[
            const SizedBox(height: 10),
            _SavedCriticalCard(
              t: t,
              l: l,
              crit: c,
              text: parsed[_savedMicroTopic(c.key)] ?? '',
            ),
          ],
        ],
        if (a.micros.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MicrosPeriodCard(t: t, l: l, rows: _barsFromMicros(a.micros, l, t)),
        ],
      ],
    );
  }

  static String _preview(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'^\s*(?:[-*]|•|\d+[\).])\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .join(' · ');
  }
}

class _PeriodChip extends StatelessWidget {
  final EcoTheme t;
  final String label;

  const _PeriodChip({required this.t, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.bandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: t.ink,
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final EcoTheme t;
  final IconData icon;
  final VoidCallback? onTap;

  const _IconChip({required this.t, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: onTap == null ? t.cardAlt : t.bandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 17,
          color: onTap == null ? t.faint : t.ink,
        ),
      ),
    );
  }
}

/// Карточка «Микронутриенты за период» — заголовок, подпись и шкалы (без
/// сворачивания). Используется и в свежем совете, и в «Сохранённых».
class _MicrosPeriodCard extends StatelessWidget {
  final EcoTheme t;
  final AppStrings l;
  final List<Widget> rows;

  const _MicrosPeriodCard({required this.t, required this.l, required this.rows});

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('ai.microsTitle'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          if (rows.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.t('ai.microsEmpty'),
              style: TextStyle(fontSize: 13, height: 1.4, color: t.sub),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              l.t('ai.microsAvgNote'),
              style: TextStyle(fontSize: 12, height: 1.35, color: t.sub),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              rows[i],
            ],
          ],
        ],
      ),
    );
  }
}

/// Статичная (без «печати») карточка критичного нутриента для «Сохранённых».
class _SavedCriticalCard extends StatelessWidget {
  final EcoTheme t;
  final AppStrings l;
  final SavedNutrient crit;
  final String text;

  const _SavedCriticalCard({
    required this.t,
    required this.l,
    required this.crit,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      t: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.nutrient(crit.key),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
              _savedCritChip(crit.excess, l.language),
            ],
          ),
          const SizedBox(height: 12),
          ProgressScale(
            t: t,
            value: crit.value,
            target: crit.target > 0 ? crit.target : crit.value,
            color: micronutrientColor(crit.key),
            unit: l.unit(microUnitCode(crit.key)),
            animateFromZero: true,
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.45, color: t.sub),
            ),
          ],
        ],
      ),
    );
  }
}

List<Widget> _barsFromMicros(
  List<SavedNutrient> micros,
  AppStrings l,
  EcoTheme t,
) =>
    [
      for (final m in micros)
        if (m.value > 0)
          ProgressScale(
            t: t,
            value: m.value,
            target: m.target > 0 ? m.target : m.value,
            color: micronutrientColor(m.key),
            unit: l.unit(microUnitCode(m.key)),
            label: l.nutrient(m.key),
          ),
    ];

Map<AiAdviceTopic, String> _parseSavedAdvice(String advice, AppLanguage lang) {
  final byTitle = {
    for (final tp in AiAdviceTopic.values) AiAdviceContract.title(tp, lang): tp,
  };
  final map = <AiAdviceTopic, String>{};
  for (final line in advice.split('\n')) {
    final idx = line.indexOf(': ');
    if (idx <= 0) continue;
    final tp = byTitle[line.substring(0, idx)];
    if (tp != null) map[tp] = line.substring(idx + 2).trim();
  }
  return map;
}

AiAdviceTopic? _savedMicroTopic(String key) => switch (key) {
      'fe' => AiAdviceTopic.iron,
      'mg' => AiAdviceTopic.magnesium,
      'ca' => AiAdviceTopic.calcium,
      'p' => AiAdviceTopic.phosphorus,
      'k' => AiAdviceTopic.potassium,
      'na' => AiAdviceTopic.sodium,
      'zn' => AiAdviceTopic.zinc,
      'vit_a' => AiAdviceTopic.vitaminA,
      'vit_c' => AiAdviceTopic.vitaminC,
      'vit_d' => AiAdviceTopic.vitaminD,
      'vit_e' => AiAdviceTopic.vitaminE,
      'vit_k' => AiAdviceTopic.vitaminK,
      'vit_b1' => AiAdviceTopic.vitaminB1,
      'vit_b2' => AiAdviceTopic.vitaminB2,
      'vit_b3' => AiAdviceTopic.vitaminB3,
      'vit_b6' => AiAdviceTopic.vitaminB6,
      'vit_b9' => AiAdviceTopic.vitaminB9,
      'vit_b12' => AiAdviceTopic.vitaminB12,
      _ => null,
    };

Widget _savedSectionHeader(AppLanguage lang, EcoTheme t) {
  final label = switch (lang) {
    AppLanguage.ru => 'Критичные показатели',
    AppLanguage.en => 'Critical values',
    AppLanguage.uzLatn => 'Muhim koʼrsatkichlar',
    AppLanguage.uzCyrl => 'Муҳим кўрсаткичлар',
  };
  return Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: Color(0xFFA96666),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
      ],
    ),
  );
}

Widget _savedCritChip(bool excess, AppLanguage lang) {
  final base = excess ? const Color(0xFFA96666) : const Color(0xFFB07A34);
  final label = switch (lang) {
    AppLanguage.ru => excess ? 'Избыток' : 'Дефицит',
    AppLanguage.en => excess ? 'Excess' : 'Deficit',
    AppLanguage.uzLatn => excess ? 'Ortiqcha' : 'Kamlik',
    AppLanguage.uzCyrl => excess ? 'Ортиқча' : 'Камлик',
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: base.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          excess ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: base,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: base,
          ),
        ),
      ],
    ),
  );
}

/// Один печатаемый блок результата: КБЖУ (первый) или критичный нутриент.
/// [start] — смещение начала блока в общем сценарии печати `_script`.
class _Seg {
  final int start;
  final String text;
  final String? critKey;
  final _Crit? crit;

  const _Seg({
    required this.start,
    required this.text,
    this.critKey,
    this.crit,
  });

  int get end => start + text.length;
}

/// Критичный нутриент: среднесуточное потребление, норма и направление
/// отклонения (дефицит/избыток) для сортировки и цвета чипа.
class _Crit {
  final String key;
  final double perDay;
  final double target;
  final bool excess;
  final double ratio;

  const _Crit({
    required this.key,
    required this.perDay,
    required this.target,
    required this.excess,
    required this.ratio,
  });
}
