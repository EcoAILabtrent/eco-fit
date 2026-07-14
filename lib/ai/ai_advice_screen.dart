import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  // Интервал совета: пресет (день/неделя/месяц) или произвольный диапазон из
  // календаря (preset == null — сегмент периода без выделения).
  AiAdviceRange _range = AiAdviceRange.preset(AiAdvicePeriod.day);
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
  // Ключ локализации ai.error.* последней ошибки (не сырой серверный текст).
  String? _error;

  // Прокрутка результата: во время «потоковой» генерации держим низ в поле
  // зрения — как в чате ИИ, где новые карточки появляются снизу, а прежние
  // уходят вверх.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnline());
  }

  @override
  void dispose() {
    _stopTyping();
    _revealed.dispose();
    _scroll.dispose();
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
      header: EcoTopBar(
        t: t,
        title: l.t('ai.pageTitle'),
        onBack: () => Navigator.of(context).pop(),
      ),
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _AiRobot(t: t)),
          const SizedBox(height: 16),
          Padding(
            // Небольшой боковой отступ: клип контента EcoScreen (по ширине карточек
            // 380) срезает drop-тень стеклянного трека/пилюли по бокам. Отступ даёт
            // тени поместиться — как у селектора порции, что лежит в листе с полями.
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: EcoSegmented(
              t: t,
              options: [l.t('ai.tabNew'), l.t('ai.tabSaved')],
              value: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
          ),
          const SizedBox(height: 16),
          // Период (день/неделя/месяц) держим постоянно на вкладке «Новый совет»,
          // над контентом: раньше он жил внутри стартовой карточки и пропадал
          // после генерации. Под сегментом — пилюля с датами интервала (макет
          // 307:2066): тап открывает календарь произвольного периода. Во время
          // загрузки смену периода блокируем.
          if (_tab == 0) ...[
            IgnorePointer(
              ignoring: _loading,
              child: Opacity(
                opacity: _loading ? 0.5 : 1,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: EcoSegmented(
                        t: t,
                        options: _periodOptions(l),
                        value: _range.preset?.index ?? -1,
                        onChanged: _setPreset,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(child: _rangePill(t)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
    final foodCount = _foodCount(store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EcoCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    // Карточки появляются ПОСЛЕДОВАТЕЛЬНО, как в чате ИИ: сначала печатается
    // КБЖУ, и только когда печать доходит до начала следующего блока — с плавным
    // появлением возникает следующая карточка. Микронутриенты за период и
    // дисклеймер/кнопки показываем в самом конце, когда весь текст «допечатан».
    return ValueListenableBuilder<String>(
      valueListenable: _revealed,
      builder: (context, revealed, _) {
        final n = revealed.length;
        final macroDone = macro == null || n >= macro.end;
        final children = <Widget>[
          // КБЖУ — первая карточка, печатается по буквам.
          EcoCard(
            t: t,
            child: AdviceBulletList(
              t: t,
              text: macro == null ? '' : _visible(macro, n),
              showCursor: macro != null && n >= macro.start && n < macro.end,
            ),
          ),
        ];

        // После КБЖУ — ЕДИНАЯ карточка микронутриентов: сверху критичные
        // (дефицит/избыток), ниже — остальные в норме. Без дублей: критичные
        // исключены из общего списка, отдельной секции критичных нет (макет 308:28).
        // Дисклеймер и кнопки «Сохранить»/«Готово» лежат ВНУТРИ этой карточки, в
        // самом низу (макет 313:12), а не отдельным блоком под ней.
        if (macroDone) {
          children
            ..add(const SizedBox(height: 12))
            ..add(_RevealIn(
              key: const ValueKey('micros'),
              child: _microsCard(store, l, t, crits),
            ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  /// Строка критичного нутриента ВНУТРИ карточки микронутриентов (без обёртки
  /// EcoCard): имя + чип дефицита/избытка, шкала [ProgressScale] и текст-
  /// последствие (целиком, без «печати»).
  Widget _criticalRow(_Seg seg, AppStrings l, EcoTheme t) {
    final key = seg.critKey!;
    final crit = seg.crit!;
    final color = micronutrientColor(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Имя + чип + значение нормы — ОДНОЙ строкой (leading шкалы). Текущее
        // значение шкала рисует под баром как обычно.
        ProgressScale(
          t: t,
          value: crit.perDay,
          target: crit.target,
          color: color,
          unit: l.unit(microUnitCode(key)),
          animateFromZero: true,
          leading: Row(
            children: [
              Flexible(
                child: Text(
                  l.nutrient(key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _critChip(crit.excess, l),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          seg.text,
          style: TextStyle(fontSize: 13, height: 1.45, color: t.sub),
        ),
      ],
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
      final target =
          mt?.target ?? adultMicronutrientTarget(key, female: female);
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
    // _error хранит ключ локализации ai.error.* (см. _loadAdvice), а не сырой
    // серверный текст — показываем пользователю переведённое сообщение.
    if (_error != null) return l.t(_error!);
    if (foodCount == 0) return _noFoodText(l);
    return _readyText(l);
  }

  // ─────────────────────── Микронутриенты за период ───────────────────────

  /// Единая карточка микронутриентов за период: заголовок, сверху — критичные
  /// (дефицит/избыток) с чипами и текстом-последствием, ниже — «Среднее по
  /// норме» и остальные шкалы. Критичные исключены из общего списка, поэтому
  /// один нутриент не выводится дважды (макет 308:28).
  Widget _microsCard(
      AppStore store, AppStrings l, EcoTheme t, List<_Seg> crits) {
    final critKeys = {
      for (final s in crits)
        if (s.critKey != null) s.critKey!,
    };
    final normRows = _microRows(store, l, t, exclude: critKeys);
    final hasCrit = crits.isNotEmpty;
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
          if (hasCrit) ...[
            const SizedBox(height: 16),
            _sectionHeader(l, t),
            for (final seg in crits) ...[
              const SizedBox(height: 12),
              _criticalRow(seg, l, t),
            ],
          ],
          if (normRows.isNotEmpty) ...[
            SizedBox(height: hasCrit ? 20 : 6),
            Text(
              l.t('ai.microsAvgNote'),
              style: TextStyle(fontSize: 12, height: 1.35, color: t.sub),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < normRows.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              normRows[i],
            ],
          ],
          if (!hasCrit && normRows.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.t('ai.microsEmpty'),
              style: TextStyle(fontSize: 13, height: 1.4, color: t.sub),
            ),
          ],
          // Дисклеймер + кнопки «Сохранить»/«Готово» — в самом низу карточки
          // (макет 313:12), а не отдельным блоком под ней.
          const SizedBox(height: 20),
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
          _resultActions(store, l, t),
        ],
      ),
    );
  }

  /// Кнопки под готовым советом ВНУТРИ карточки микронутриентов (макет 313:12):
  /// «Сохранить» (после сохранения → «Сохранено», неактивна) и «Готово»
  /// (сворачивает совет обратно к экрану выбора периода).
  Widget _resultActions(AppStore store, AppStrings l, EcoTheme t) {
    return Row(
      children: [
        Expanded(
          child: EcoBtn(
            t: t,
            height: 44,
            fontSize: 15,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            disabled: _saved,
            onTap: _saved ? null : () => _saveCurrentAdvice(store),
            child: Text(_saved ? l.t('ai.saved') : l.t('ai.save')),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: EcoBtn(
            t: t,
            height: 44,
            fontSize: 15,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: _clearAdvice,
            child: Text(l.t('common.done')),
          ),
        ),
      ],
    );
  }

  List<Widget> _microRows(AppStore store, AppStrings l, EcoTheme t,
      {Set<String> exclude = const {}}) {
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
      if (exclude.contains(key)) continue;
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
    for (final date in _range.dateKeys) {
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
        // Растягиваем на всю ширину контента (как остальные карточки), иначе
        // Column обжимается по тексту и карточка выходит уже сегмента/карточек.
        child: SizedBox(
          width: double.infinity,
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
            periodLabel: _savedPeriodLabel(advice, l),
            onDelete: () => store.deleteAiAdvice(advice.id),
          ),
      ],
    );
  }

  // ─────────────────────────── Логика ───────────────────────────

  int _foodCount(AppStore store) {
    var count = 0;
    for (final date in _range.dateKeys) {
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
        range: _range,
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
    } on AiAdviceException catch (error) {
      // Серверные детали — только в лог; пользователю показываем локализованный
      // ключ ai.error.* по категории ошибки.
      debugPrint('AI advice failed: $error');
      if (!mounted) return;
      setState(() {
        _error = error.l10nKey;
        if (error.kind == AiAdviceErrorKind.network) _online = false;
      });
    } on Object catch (error) {
      debugPrint('AI advice failed: $error');
      if (!mounted) return;
      setState(() => _error = 'ai.error.generic');
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
        period: _range.preset,
        startDate: AppStore.ymd(_range.start),
        endDate: AppStore.ymd(_range.end),
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

  void _setPreset(int index) {
    final next = AiAdviceRange.preset(AiAdvicePeriod.values[index]);
    if (next.sameAs(_range)) return;
    _applyRange(next);
  }

  /// Диапазон из календаря. Если он совпадает с пресетом (сегодня / последние
  /// 7 или 30 дней) — считаем пресетом, чтобы сегмент периода подсветился.
  void _setCustomRange(DateTime start, DateTime end) {
    var next = AiAdviceRange.custom(start, end);
    for (final p in AiAdvicePeriod.values) {
      final preset = AiAdviceRange.preset(p);
      if (preset.start == next.start && preset.end == next.end) {
        next = preset;
        break;
      }
    }
    if (next.sameAs(_range)) return;
    _applyRange(next);
  }

  /// Смена интервала сбрасывает текущий совет (как прежняя смена периода).
  void _applyRange(AiAdviceRange next) {
    _stopTyping();
    _revealed.value = '';
    _segs = const [];
    _script = '';
    setState(() {
      _range = next;
      _advice = null;
      _error = null;
      _saved = false;
    });
  }

  /// Пилюля с датами интервала (макет 307:2066: EcoBtn h36, «12.07 - 14.07» +
  /// иконка календаря). Тап открывает шторку с календарём диапазона.
  Widget _rangePill(EcoTheme t) {
    return EcoBtn(
      t: t,
      height: 36,
      fontSize: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () => _pickRange(t),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_rangeLabel()),
          const SizedBox(width: 4),
          SvgPicture.asset('assets/icons/cal.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(t.iconOlive, BlendMode.srcIn)),
        ],
      ),
    );
  }

  void _pickRange(EcoTheme t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var start = _range.start;
    var end = _range.end;
    showEcoSheet(
      context: context,
      t: t,
      title: context.l10nRead.t('ai.rangeTitle'),
      body: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: EcoRangeCalendar(
          t: t,
          initialStart: _range.start,
          initialEnd: _range.end,
          // Будущее недоступно (еды там нет), назад — до года от сегодня.
          minDate: today.subtract(const Duration(days: 365)),
          maxDate: today,
          onChanged: (s, e) {
            start = s;
            end = e;
          },
        ),
      ),
      onDone: () => _setCustomRange(start, end),
    );
  }

  static String _fmtDm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  String _rangeLabel() => _range.isSingleDay
      ? _fmtDm(_range.end)
      : '${_fmtDm(_range.start)} - ${_fmtDm(_range.end)}';

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
      // Пока идёт печать — держим низ в поле зрения: новые карточки появляются
      // снизу, а прежние плавно уходят вверх (как в чате ИИ).
      _stickToBottom();
      if (index >= text.length) {
        timer.cancel();
        _typingTimer = null;
        // В самом конце появляются карточка микронутриентов и дисклеймер —
        // плавно доводим прокрутку до низа.
        _stickToBottom(animate: true);
      }
    });
  }

  /// Прокручивает результат к самому низу. Во время печати используем мгновенный
  /// [ScrollController.jumpTo] (низ «прилипает» без рывков), в конце — плавную
  /// анимацию, чтобы финальные карточки красиво доехали в кадр.
  void _stickToBottom({bool animate = false}) {
    if (_tab != 0) return; // на вкладке «Сохранённые» не трогаем прокрутку
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() < 1) return;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
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

  /// Чип периода в «Сохранённых»: пресет — прежний лейбл, кастомный интервал —
  /// его даты («12.07 - 14.07»).
  String _savedPeriodLabel(SavedAiAdvice advice, AppStrings l) {
    final preset = advice.period;
    if (preset != null) return _periodOptions(l)[preset.index];
    final start = _parseYmd(advice.startDate);
    final end = _parseYmd(advice.endDate);
    if (start == null || end == null) return _periodOptions(l).first;
    return start == end ? _fmtDm(start) : '${_fmtDm(start)} - ${_fmtDm(end)}';
  }

  static DateTime? _parseYmd(String? value) {
    if (value == null) return null;
    final parts = value.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }

  String _readyText(AppStrings l) {
    final preset = _range.preset;
    if (preset == null) {
      final range = _rangeLabel();
      return switch (l.language) {
        AppLanguage.en => 'AI can review your meals for $range.',
        AppLanguage.ru => 'ИИ разберёт питание за $range.',
        AppLanguage.uzLatn =>
          'AI $range davri uchun ratsionni tahlil qiladi.',
        AppLanguage.uzCyrl => 'ИИ $range даври учун рационни таҳлил қилади.',
      };
    }
    return switch (l.language) {
      AppLanguage.en => switch (preset) {
          AiAdvicePeriod.day => "AI can review today's meals in a short note.",
          AiAdvicePeriod.week => 'AI can review your last 7 days of meals.',
          AiAdvicePeriod.month => 'AI can review your last 30 days of meals.',
        },
      AppLanguage.ru => switch (preset) {
          AiAdvicePeriod.day => 'ИИ коротко разберёт сегодняшний рацион.',
          AiAdvicePeriod.week => 'ИИ разберёт питание за последние 7 дней.',
          AiAdvicePeriod.month => 'ИИ разберёт питание за последние 30 дней.',
        },
      AppLanguage.uzLatn => switch (preset) {
          AiAdvicePeriod.day => 'AI bugungi ratsionni qisqa tahlil qiladi.',
          AiAdvicePeriod.week => 'AI oxirgi 7 kunlik ratsionni tahlil qiladi.',
          AiAdvicePeriod.month =>
            'AI oxirgi 30 kunlik ratsionni tahlil qiladi.',
        },
      AppLanguage.uzCyrl => switch (preset) {
          AiAdvicePeriod.day => 'ИИ бугунги рационни қисқа таҳлил қилади.',
          AiAdvicePeriod.week => 'ИИ охирги 7 кунлик рационни таҳлил қилади.',
          AiAdvicePeriod.month =>
            'ИИ охирги 30 кунлик рационни таҳлил қилади.',
        },
    };
  }

  String _noFoodText(AppStrings l) {
    final preset = _range.preset;
    if (preset == null) {
      final range = _rangeLabel();
      return switch (l.language) {
        AppLanguage.en =>
          'Add foods for $range to get advice for this period.',
        AppLanguage.ru =>
          'Добавьте еду за $range, чтобы получить совет за этот период.',
        AppLanguage.uzLatn =>
          "Bu davr uchun tavsiya olish uchun $range kunlariga ovqat qo'shing.",
        AppLanguage.uzCyrl =>
          'Бу давр учун тавсия олиш учун $range кунларига овқат қўшинг.',
      };
    }
    return switch (l.language) {
      AppLanguage.en => switch (preset) {
          AiAdvicePeriod.day =>
            'Add foods for today, then AI will analyze them.',
          AiAdvicePeriod.week =>
            'Add foods in the last 7 days to get weekly advice.',
          AiAdvicePeriod.month =>
            'Add foods in the last 30 days to get monthly advice.',
        },
      AppLanguage.ru => switch (preset) {
          AiAdvicePeriod.day =>
            'Добавьте еду за сегодня, и ИИ её проанализирует.',
          AiAdvicePeriod.week =>
            'Добавьте еду за 7 дней, чтобы получить совет за неделю.',
          AiAdvicePeriod.month =>
            'Добавьте еду за 30 дней, чтобы получить совет за месяц.',
        },
      AppLanguage.uzLatn => switch (preset) {
          AiAdvicePeriod.day =>
            "Bugungi ovqatlarni qo'shing, keyin AI tahlil qiladi.",
          AiAdvicePeriod.week =>
            "Haftalik tavsiya uchun oxirgi 7 kunga ovqat qo'shing.",
          AiAdvicePeriod.month =>
            "Oylik tavsiya uchun oxirgi 30 kunga ovqat qo'shing.",
        },
      AppLanguage.uzCyrl => switch (preset) {
          AiAdvicePeriod.day =>
            'Бугунги овқатларни қўшинг, кейин ИИ таҳлил қилади.',
          AiAdvicePeriod.week =>
            'Ҳафталик тавсия учун охирги 7 кунга овқат қўшинг.',
          AiAdvicePeriod.month =>
            'Ойлик тавсия учун охирги 30 кунга овқат қўшинг.',
        },
    };
  }
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

  // Подпись печатается по буквам ОДИН раз и остаётся на экране (не мигает и не
  // исчезает). Пока печатается — за текстом идёт курсор «|», по завершении он
  // убирается и текст просто остаётся.
  void _restartCaption() {
    _captionTimer?.cancel();
    _caption.value = '';
    var index = 0;
    _captionTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (!mounted) {
        timer.cancel();
        _captionTimer = null;
        return;
      }
      index++;
      _caption.value = _hint.substring(0, math.min(index, _hint.length));
      if (index >= _hint.length) {
        timer.cancel();
        _captionTimer = null;
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
                child: SvgPicture.asset(
                  'assets/icons/trash.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(t.faint, BlendMode.srcIn),
                ),
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
  /// «Микронутриенты за период» (критичные плоскими строками + бары), БЕЗ
  /// вложенных карточек — всё внутри одной карточки совета, как при генерации
  /// (макет 313:12). Старые советы (без сохранённых значений) показываются
  /// прежним плоским списком.
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
        if (parsed[tp] != null)
          '${AiAdviceContract.title(tp, lang)}: ${parsed[tp]}',
    ].join('\n');
    // Обычные шкалы — все микро, кроме критичных (те показаны выше со шкалой и
    // текстом), чтобы нутриент не дублировался, как в свежем `_microsCard`.
    final critKeys = {for (final c in a.criticals) c.key};
    final normalBars = _barsFromMicros(
      [for (final m in a.micros) if (!critKeys.contains(m.key)) m],
      l,
      t,
    );
    final hasCrit = a.criticals.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (macroText.isNotEmpty) AdviceBulletList(t: t, text: macroText),
        const SizedBox(height: 16),
        Text(
          l.t('ai.microsTitle'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        if (hasCrit) ...[
          const SizedBox(height: 16),
          _savedSectionHeader(lang, t),
          for (final c in a.criticals) ...[
            const SizedBox(height: 12),
            _savedCriticalRow(t, l, c, parsed[_savedMicroTopic(c.key)] ?? ''),
          ],
        ],
        if (normalBars.isNotEmpty) ...[
          SizedBox(height: hasCrit ? 20 : 6),
          Text(
            l.t('ai.microsAvgNote'),
            style: TextStyle(fontSize: 12, height: 1.35, color: t.sub),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < normalBars.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            normalBars[i],
          ],
        ],
        // Дисклеймер — в самом низу развёрнутого совета, как в свежем результате.
        const SizedBox(height: 20),
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
    );
  }

  /// Плоская строка критичного нутриента для сохранённого совета — БЕЗ обёртки
  /// EcoCard (копия свежего `_criticalRow`): имя + чип дефицита/избытка в leading
  /// шкалы, ниже — текст-последствие.
  Widget _savedCriticalRow(
      EcoTheme t, AppStrings l, SavedNutrient crit, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressScale(
          t: t,
          value: crit.value,
          target: crit.target > 0 ? crit.target : crit.value,
          color: micronutrientColor(crit.key),
          unit: l.unit(microUnitCode(crit.key)),
          animateFromZero: true,
          leading: Row(
            children: [
              Flexible(
                child: Text(
                  l.nutrient(crit.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _savedCritChip(crit.excess, l.language),
            ],
          ),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.45, color: t.sub),
          ),
        ],
      ],
    );
  }

  static String _preview(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) =>
            line.replaceAll(RegExp(r'^\s*(?:[-*]|•|\d+[\).])\s*'), '').trim())
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

/// Обёртка «появления» карточки: при первом монтировании плавно проявляет
/// содержимое (лёгкий подъём + fade). Каждая новая карточка результата выводится
/// через неё, чтобы блоки возникали по одному, как в чате ИИ.
class _RevealIn extends StatefulWidget {
  final Widget child;

  const _RevealIn({super.key, required this.child});

  @override
  State<_RevealIn> createState() => _RevealInState();
}

class _RevealInState extends State<_RevealIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
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
