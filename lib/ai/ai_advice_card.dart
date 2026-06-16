import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'ai_advice_service.dart';
import 'ai_config.dart';

class AiAdviceCard extends StatefulWidget {
  final EcoTheme t;

  const AiAdviceCard({super.key, required this.t});

  @override
  State<AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends State<AiAdviceCard>
    with SingleTickerProviderStateMixin {
  static const _service = AiAdviceService();

  bool _checking = false;
  bool _loading = false;
  bool? _online;
  AiAdvicePeriod _period = AiAdvicePeriod.day;
  bool _periodPickerOpen = false;
  String? _advice;
  String _typedAdvice = '';
  bool _typing = false;
  Timer? _typingTimer;
  String? _error;
  late final AnimationController _aiMotion;

  @override
  void initState() {
    super.initState();
    _aiMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnline());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l10n;
    final foodCount = _foodCount(store, _period);
    final hasFoodInAnyPeriod = AiAdvicePeriod.values.any(
      (period) => _foodCount(store, period) > 0,
    );
    final canOpenPicker = AiConfig.hasApiKey && !_loading && _online != false;
    final canGenerate = canOpenPicker && foodCount > 0;
    final visibleAdvice = _visibleAdvice;

    return EcoCard(
      t: widget.t,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiCardHeader(t: widget.t, title: _aiTitle(l), animation: _aiMotion),
          const SizedBox(height: 12),
          _advice == null
              ? Text(
                  _bodyText(
                    l,
                    foodCount,
                    revealPeriod: _periodPickerOpen,
                    hasFoodInAnyPeriod: hasFoodInAnyPeriod,
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: EcoColors.sub,
                  ),
                )
              : _AdviceList(text: visibleAdvice, showCursor: _typing),
          if (_advice == null && _periodPickerOpen) ...[
            const SizedBox(height: 14),
            Text(
              _periodPrompt(l),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                color: widget.t.dark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            EcoSegmented(
              t: widget.t,
              options: _periodOptions(l),
              value: _period.index,
              onChanged: _setPeriod,
            ),
          ],
          if (_advice != null) ...[
            const SizedBox(height: 10),
            Text(
              l.t('ai.disclaimer'),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: EcoColors.sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_advice != null) ...[
                EcoBtn(
                  t: widget.t,
                  height: 38,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: _clearAdvice,
                  child: Text(_closeLabel(l)),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  t: widget.t,
                  icon: Icons.refresh,
                  onTap: canGenerate ? () => _loadAdvice(store) : null,
                ),
              ] else if (_periodPickerOpen) ...[
                Expanded(
                  child: EcoBtn(
                    t: widget.t,
                    height: 38,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    disabled: _online == false ? false : !canGenerate,
                    onTap: _online == false
                        ? _checkOnline
                        : canGenerate
                        ? () => _loadAdvice(store)
                        : null,
                    child: Text(
                      _online == false ? l.t('ai.retry') : l.t('ai.generate'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  t: widget.t,
                  icon: Icons.close,
                  onTap: _closePeriodPicker,
                ),
              ] else if (AiConfig.hasApiKey && _online == false)
                EcoBtn(
                  t: widget.t,
                  height: 38,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: _checkOnline,
                  child: Text(l.t('ai.retry')),
                )
              else if (AiConfig.hasApiKey)
                Expanded(
                  child: EcoBtn(
                    t: widget.t,
                    height: 38,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    disabled: !canOpenPicker,
                    onTap: canOpenPicker ? _openPeriodPicker : null,
                    child: Text(l.t('ai.generate')),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _bodyText(
    AppStrings l,
    int foodCount, {
    required bool revealPeriod,
    required bool hasFoodInAnyPeriod,
  }) {
    if (!AiConfig.hasApiKey) return l.t('ai.notConfigured');
    if (_checking) return l.t('ai.checking');
    if (_online == false) return l.t('ai.offline');
    if (_loading) return l.t('ai.loading');
    if (_error != null) return l.t('ai.error');
    if (revealPeriod) {
      if (foodCount == 0) return _noFoodText(l);
      return _readyText(l);
    }
    if (!hasFoodInAnyPeriod) return l.t('ai.noFood');
    return l.t('ai.ready');
  }

  String get _visibleAdvice {
    if (!_typing) return _advice ?? '';
    return _typedAdvice;
  }

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
    _stopTyping();
    setState(() {
      _loading = true;
      _typing = false;
      _typedAdvice = '';
      _error = null;
    });
    try {
      final advice = await _service.fetchDailyAdvice(
        store: store,
        language: store.language,
        period: _period,
      );
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _periodPickerOpen = false;
        _typedAdvice = '';
        _typing = true;
        _online = true;
      });
      _startTyping(advice);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        if ('$error'.toLowerCase().contains('internet')) _online = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPeriod(int index) {
    final next = AiAdvicePeriod.values[index];
    if (next == _period) return;
    _stopTyping();
    setState(() {
      _period = next;
      _advice = null;
      _typedAdvice = '';
      _typing = false;
      _error = null;
    });
  }

  void _openPeriodPicker() {
    setState(() {
      _periodPickerOpen = true;
      _error = null;
    });
  }

  void _closePeriodPicker() {
    _stopTyping();
    setState(() {
      _periodPickerOpen = false;
      _typedAdvice = '';
      _typing = false;
      _error = null;
    });
  }

  void _clearAdvice() {
    _stopTyping();
    setState(() {
      _advice = null;
      _periodPickerOpen = false;
      _typedAdvice = '';
      _typing = false;
      _error = null;
    });
  }

  void _startTyping(String text) {
    _stopTyping();
    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index = (index + 2).clamp(0, text.length);
      setState(() {
        _typedAdvice = text.substring(0, index);
        _typing = index < text.length;
      });
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

  @override
  void dispose() {
    _stopTyping();
    _aiMotion.dispose();
    super.dispose();
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
      AiAdvicePeriod.day => 'Add foods for today, then AI will analyze them.',
      AiAdvicePeriod.week =>
        'Add foods in the last 7 days to get weekly advice.',
      AiAdvicePeriod.month =>
        'Add foods in the last 30 days to get monthly advice.',
    },
    AppLanguage.ru => switch (_period) {
      AiAdvicePeriod.day => 'Добавьте еду за сегодня, и ИИ её проанализирует.',
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
      AiAdvicePeriod.month => 'Ойлик тавсия учун охирги 30 кунга овқат қўшинг.',
    },
  };

  // ignore: unused_element
  String _moreLabel(AppStrings l) => switch (l.language) {
    AppLanguage.en => 'Details',
    AppLanguage.ru => 'Подробнее',
    AppLanguage.uzLatn => 'Batafsil',
    AppLanguage.uzCyrl => 'Батафсил',
  };

  String _closeLabel(AppStrings l) => switch (l.language) {
    AppLanguage.en => 'Close',
    AppLanguage.ru => 'Закрыть',
    AppLanguage.uzLatn => 'Yopish',
    AppLanguage.uzCyrl => 'Ёпиш',
  };

  String _aiTitle(AppStrings l) => switch (l.language) {
    AppLanguage.en => 'AI nutrition advice',
    AppLanguage.ru => 'ИИ-совет по питанию',
    AppLanguage.uzLatn => 'AI ovqatlanish tavsiyasi',
    AppLanguage.uzCyrl => 'ИИ овқатланиш тавсияси',
  };

  // ignore: unused_element
  String _aiLabel(AppStrings l) => switch (l.language) {
    AppLanguage.ru || AppLanguage.uzCyrl => 'ИИ',
    _ => 'AI',
  };

  // ignore: unused_element
  String _detailsTitle(AppStrings l) =>
      '${l.t('home.recommendations')} · ${_periodOptions(l)[_period.index]}';
}

class _AiCardHeader extends StatelessWidget {
  final EcoTheme t;
  final String title;
  final Animation<double> animation;

  const _AiCardHeader({
    required this.t,
    required this.title,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AnimatedAiBadge(t: t, animation: animation),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: EcoColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedAiBadge extends StatelessWidget {
  final EcoTheme t;
  final Animation<double> animation;

  const _AnimatedAiBadge({required this.t, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = math.sin(animation.value * math.pi * 2);
        final scale = 1 + wave * 0.045;
        final turn = wave * 0.035;
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(angle: turn, child: child),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: t.pill, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 21, color: t.dark),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: t.dark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceList extends StatelessWidget {
  final String text;
  final bool showCursor;

  const _AdviceList({required this.text, this.showCursor = false});

  @override
  Widget build(BuildContext context) {
    final items = text
        .split(RegExp(r'\r?\n'))
        .map(_cleanItem)
        .where((item) => item.isNotEmpty)
        .toList();
    if (items.isEmpty && showCursor) {
      items.add('|');
    } else if (showCursor) {
      items[items.length - 1] = '${items.last}|';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 8, right: 9),
                decoration: const BoxDecoration(
                  color: EcoColors.sub,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  items[i],
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.42,
                    color: EcoColors.sub,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _cleanItem(String value) {
    return value
        .replaceAll(RegExp('^\\s*(?:[-*]|\\u2022)\\s*'), '')
        .replaceAll(RegExp(r'^\s*\d+[\).]\s*'), '')
        .trim();
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
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null ? t.cardAlt : t.bandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 17,
          color: onTap == null ? EcoColors.faint : t.dark,
        ),
      ),
    );
  }
}
