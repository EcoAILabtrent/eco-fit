import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../nutrition/energy.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'home.dart' show WaterGlass;

// Единые акценты состава тела: иконка и полоса прогресса одного цвета.
// Вес остаётся тёмным (t.dark) и здесь не задаётся.
const _kMuscleColor = EcoColors.prot; // скелетная мускулатура — зелёный
const _kFatColor = Color(0xFFE8B53A); // жировая ткань и % жира — жёлтый
const _kWaterColor = EcoColors.water; // вода — голубой

// ── Shared helpers ────────────────────────────────────────────

/// Centered date pill (header of entry screens).
class DatePill extends StatelessWidget {
  final DateTime? date;
  final VoidCallback? onTap;
  const DatePill({super.key, this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final topInset = MediaQuery.of(context).padding.top;
    final d = date ?? DateTime.now();
    return Padding(
      padding: EdgeInsets.only(top: topInset + 24, bottom: 18),
      child: Center(
        // Дата-пилюля оформлена как единая стеклянная кнопка приложения (EcoBtn):
        // объёмное стекло + press-эффект, как у пилюли периода на экране ИИ.
        child: EcoBtn(
          t: t,
          height: 48,
          fontSize: 16,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Только дата, без дня недели и времени.
              Text('${l.dayMonth(d)} ${d.year}'),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_calendar_outlined,
                  size: 18,
                  color: t.ink,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Field row with optional icon + right widget.
class FieldRow extends StatelessWidget {
  final String? icon;
  final String label;
  final Widget right;
  final bool last;
  const FieldRow({
    super.key,
    this.icon,
    required this.label,
    required this.right,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(ecoIcon(icon!), size: 30, color: t.ink),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
          right,
        ],
      ),
    );
  }
}

/// Bottom Отмена / Сохранить footer.
Widget actionFooter(
  BuildContext context, {
  String? cancel,
  String? save,
  required VoidCallback onSave,
}) {
  final t = context.select<AppStore, EcoTheme>((s) => s.theme);
  final l = context.l10nRead;
  return Positioned(
    left: 16,
    right: 16,
    bottom: 18 + MediaQuery.of(context).padding.bottom,
    child: Row(
      children: [
        Expanded(
          child: EcoBtn(
            t: t,
            bg: t.band,
            fg: t.ink,
            onTap: () => Navigator.of(context).pop(),
            child: Text(cancel ?? l.t('common.cancel')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EcoBtn(
            t: t,
            onTap: onSave,
            child: Text(save ?? l.t('common.save')),
          ),
        ),
      ],
    ),
  );
}

// ── Вода ──────────────────────────────────────────────────────

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  // Выбранный день — смещение в днях назад от сегодня (0 = сегодня).
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    // Точечная подписка вместо watch: экран воды перестраивается только когда
    // меняется вода (сегодня или выбранный день) либо её норма, а не на каждый
    // тик шагомера.
    context.select<AppStore, int>(
      (s) => Object.hash(
          s.water, s.waterGoal, s.waterForOffset(_offset), s.waterPortion),
    );
    final s = context.read<AppStore>();
    final l = context.l10n;

    final isToday = _offset == 0;
    final selDate = DateTime.now().subtract(Duration(days: _offset));
    final selWater = s.waterForOffset(_offset);
    // «Переполнение»: каждый полностью выпитый объём нормы уходит вверх отдельным
    // маленьким полным стаканом, а большой стакан показывает прогресс к следующей
    // норме. При selWater ≤ норме маленьких стаканов нет, большой — как обычно.
    final goal = s.waterGoal;
    final overflowGlasses =
        (goal > 0 && selWater > goal) ? (selWater - 1) ~/ goal : 0;
    // По бокам большого стакана помещается до 2 маленьких с каждой стороны
    // (макет 277:2597) — максимум 4. Левой стороне достаётся «лишний» при
    // нечётном числе.
    final shownGlasses = overflowGlasses > 4 ? 4 : overflowGlasses;
    final leftGlasses = (shownGlasses + 1) ~/ 2;
    final rightGlasses = shownGlasses ~/ 2;
    final bigFill = goal > 0
        ? ((selWater - overflowGlasses * goal) / goal).clamp(0.0, 1.0)
        : 0.0;

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('home.water'),
        onBack: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── График воды за 30 дней: горизонтальная прокрутка, подложка за
          // выбранным днём (как на экране «Шаги») ──
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: EcoDayBarStrip(
              data: [
                for (final e in s.waterMonth()) (date: e.date, value: e.water),
              ],
              goal: s.waterGoal,
              minTop: (s.waterGoal * 1.3).round(),
              barColor: EcoColors.water,
              goalColor: EcoColors.waterDeep,
              unit: l.unit('ml'),
              offset: _offset,
              onSelect: (o) => setState(() => _offset = o),
            ),
          ),
          const SizedBox(height: 8),
          // Подпись выбранного дня: «Сегодня» или дата.
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
          const SizedBox(height: 14),
          EcoCard(
            t: t,
            child: Column(
              children: [
                // «Переполнение»: большой стакан по центру, а по бокам —
                // маленькие полные стаканы за каждую выпитую норму сверх цели
                // (до 2 слева/справа, макет 277:2597). Прижаты к большому и
                // выровнены по его низу; при нечёте лишний — слева.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < leftGlasses; i++) ...[
                            WaterGlass(fill: 1.0, t: t, width: 36, height: 50),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    // Тот же стакан, что на главной («Вода»): контур + волнистая
                    // анимированная вода + растение, крупнее.
                    WaterGlass(fill: bigFill, t: t, width: 107, height: 150),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < rightGlasses; i++) ...[
                            const SizedBox(width: 8),
                            WaterGlass(fill: 1.0, t: t, width: 36, height: 50),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '$selWater',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '/ ${s.waterGoal} ${l.unit('ml')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.sub,
                  ),
                ),
                // ± меняют воду ВЫБРАННОГО дня на выбранную порцию; центральная
                // кнопка (текущая порция) по тапу открывает лист-колесо выбора
                // размера. Все три — объёмное стекло (EcoGlassButton).
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EcoGlassButton(
                      height: 52,
                      width: 52,
                      padding: EdgeInsets.zero,
                      onTap: () => context
                          .read<AppStore>()
                          .stepWaterForOffset(_offset, -s.waterPortion),
                      child: Icon(Icons.remove, size: 24, color: t.ink),
                    ),
                    const SizedBox(width: 12),
                    EcoBtn(
                      t: t,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      onTap: () => _pickPortion(t, l),
                      child: Text('${s.waterPortion} ${l.unit('ml')}'),
                    ),
                    const SizedBox(width: 12),
                    EcoGlassButton(
                      height: 52,
                      width: 52,
                      padding: EdgeInsets.zero,
                      onTap: () => context
                          .read<AppStore>()
                          .stepWaterForOffset(_offset, s.waterPortion),
                      child: Icon(Icons.add, size: 24, color: t.ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Лист выбора размера порции (мл) — колесо в стиле «Размер порции».
  void _pickPortion(EcoTheme t, AppStrings l) {
    final store = context.read<AppStore>();
    const options = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];
    var idx = options.indexOf(store.waterPortion);
    if (idx < 0) idx = 1;
    final ctrl = FixedExtentScrollController(initialItem: idx);
    showEcoSheet(
      context: context,
      t: t,
      title: l.t('food.portionSize'),
      onDone: () => store.setWaterPortion(options[idx]),
      body: SizedBox(
        height: 150,
        child: CupertinoPicker(
          scrollController: ctrl,
          itemExtent: 44,
          selectionOverlay: EcoPickerSelectionOverlay(t: t),
          onSelectedItemChanged: (i) => idx = i,
          children: [
            for (final v in options)
              Center(
                child: Text(
                  '$v ${l.unit('ml')}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).whenComplete(() => ctrl.dispose());
  }
}

// ── Состав тела ───────────────────────────────────────────────

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    // Точечная подписка: экран состава тела перестраивается при изменении
    // веса/состава/истории или профиля (рост/пол влияют на «нормы»), а не на
    // каждый тик шагомера/воды.
    context.select<AppStore, int>(
      (s) => Object.hash(
        s.weight,
        s.weightKg,
        s.skeletalMuscle,
        s.bodyFat,
        s.heightCm,
        s.gender,
        s.bodyHistory.length,
      ),
    );
    final s = context.read<AppStore>();
    final l = context.l10n;
    final currentWeight = s.weight > 0 ? s.weight : (s.weightKg ?? 0);
    final entries = _chartEntries(s);
    final selectedIndex = entries.isEmpty
        ? 0
        : (_selectedIndex ?? entries.length - 1).clamp(0, entries.length - 1);
    final selected = entries.isEmpty
        ? BodyMetricEntry(
            date: DateTime.now(),
            weightKg: currentWeight,
            skeletalMuscle: s.skeletalMuscle,
            bodyFat: s.bodyFat,
          )
        : entries[selectedIndex];
    final bodyWeight = selected.weightKg;
    final skeletalMuscle = selected.skeletalMuscle;
    final bodyFat = selected.bodyFat;
    final fatMass = (bodyWeight * bodyFat / 100);
    final chartPoints = entries.map((entry) => entry.weightKg).toList();
    String fmt(num v) {
      final decimal =
          l.language == AppLanguage.ru || l.language == AppLanguage.uzCyrl
              ? ','
              : '.';
      return v.toStringAsFixed(1).replaceAll('.', decimal);
    }

    // «Нормы» состава тела считаем от профиля, а не берём фикс-значения одного
    // человека: вес — по здоровому ИМТ от роста, мышцы/жир — по полу (формулы и
    // источники в nutrition/energy.dart).
    final heightCm = (s.heightCm ?? 170).toDouble();
    final sex = s.gender == 'f' ? 'f' : 'm';
    final weightRange = healthyWeightRange(heightCm);
    final muscleRange =
        healthySkeletalMuscleRange(heightCm: heightCm, sex: sex);
    final fatRange = healthyFatMassRange(heightCm: heightCm, sex: sex);
    // Доля заполнения полосы = позиция значения внутри здорового диапазона
    // [low, high] (в _RangeRow дополнительно клампится к [0.04, 1.0]).
    double rangeFrac(double value, ({double low, double high}) range) =>
        (range.high - range.low) <= 0
            ? 0.0
            : (value - range.low) / (range.high - range.low);

    void openEntry() => Navigator.of(context).pushNamed('/bodyEntry');

    return EcoScreen(
      t: t,
      header: EcoTopBar(
        t: t,
        title: l.t('health.bodyComposition'),
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: Positioned(
        left: 16,
        right: 16,
        bottom: 18 + MediaQuery.of(context).padding.bottom,
        child: EcoBtn(
          t: t,
          // Плавающая кнопка над прокруткой — восстанавливаем искажение фона
          // (backdrop-blur), чтобы контент «плыл» под стеклом.
          frosted: true,
          onTap: () => Navigator.of(context).pushNamed('/bodyEntry'),
          child: Text(l.t('health.enterData')),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Снизу плавающая кнопка «Ввести данные» (footer, высота 56 + нижний
            // отступ 18 + системная зона жестов) — даём контенту достаточный
            // отступ, чтобы корзинка не пряталась под кнопкой.
            padding: EdgeInsets.only(
              bottom: 18 + MediaQuery.of(context).padding.bottom + 56 + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    // Full-bleed до краёв телефона: через OverflowBox отменяем
                    // боковые отступы экрана (16px), чтобы график доходил до
                    // самого края, как день-полоса в «Еде». Видимая часть —
                    // всегда ровно 7 колонок; лишние записи уходят влево под
                    // горизонтальный скролл (reverse: true).
                    const visibleCount = 7;
                    final screenWidth = MediaQuery.sizeOf(context).width;
                    final colW = screenWidth / visibleCount;
                    final scrollable = entries.length > visibleCount;
                    final contentW =
                        scrollable ? entries.length * colW : screenWidth;
                    const stripHeight = 102.0 + 4 + 30;
                    return SizedBox(
                      height: stripHeight,
                      child: OverflowBox(
                        minWidth: screenWidth,
                        maxWidth: screenWidth,
                        minHeight: stripHeight,
                        maxHeight: stripHeight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: contentW,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) => _selectChartPoint(
                                details.localPosition,
                                contentW,
                                entries.length,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 102,
                                    // RepaintBoundary: линия+точки графика
                                    // кэшируются, и горизонтальный фл­инг 7-дневной
                                    // полоски лишь композитит слой, а не
                                    // перерисовывает график каждый кадр.
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size(contentW, 102),
                                        painter: _BodyChartPainter(
                                          chartPoints,
                                          selectedIndex: selectedIndex,
                                          t: t,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _BodyDateTicks(
                                    dates: [
                                      for (final entry in entries) entry.date,
                                    ],
                                    selectedIndex: selectedIndex,
                                    t: t,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    l.dayMonth(selected.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                EcoCard(
                  t: t,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('scale', fmt(bodyWeight), l.unit('kg'), t.dark, t),
                      _stat(
                        'gauge',
                        fmt(skeletalMuscle),
                        l.unit('kg'),
                        _kMuscleColor,
                        t,
                      ),
                      _stat('flame', fmt(bodyFat), '%', _kFatColor, t),
                    ],
                  ),
                ),
                EcoCard(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('health.yourBodyComposition'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('profile.weight'),
                        value: fmt(bodyWeight),
                        unit: l.unit('kg'),
                        lo: fmt(weightRange.low),
                        hi: fmt(weightRange.high),
                        frac: rangeFrac(bodyWeight, weightRange),
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.skeletalMuscle'),
                        value: fmt(skeletalMuscle),
                        unit: l.unit('kg'),
                        lo: fmt(muscleRange.low),
                        hi: fmt(muscleRange.high),
                        frac: rangeFrac(skeletalMuscle, muscleRange),
                        accent: _kMuscleColor,
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.fatMass'),
                        value: fmt(fatMass),
                        unit: l.unit('kg'),
                        lo: fmt(fatRange.low),
                        hi: fmt(fatRange.high),
                        frac: rangeFrac(fatMass, fatRange),
                        accent: _kFatColor,
                        onTap: openEntry,
                      ),
                      _RangeRow(
                        t: t,
                        label: l.t('health.bodyWater'),
                        value: fmt(bodyWaterPercent(bodyFat)),
                        unit: '%',
                        lo: '50',
                        hi: '65',
                        frac: ((bodyWaterPercent(bodyFat) - 50) / 15)
                            .clamp(0.0, 1.0),
                        accent: _kWaterColor,
                        last: true,
                      ),
                    ],
                  ),
                ),
                // Удаление выбранной записи — иконка-корзинка внизу + диалог
                // подтверждения. Показываем только когда есть реальные записи:
                // синтетических точек больше нет, удалять «пустоту» нечего.
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Center(
                    // Кнопка удаления — стандартная стеклянная кнопка приложения
                    // (press-эффект + стеклянная подложка), круглая 52×52.
                    child: EcoGlassButton(
                      width: 52,
                      height: 52,
                      radius: 999,
                      padding: EdgeInsets.zero,
                      onTap: () => _confirmDeleteEntry(selected.date),
                      // Иконка-корзинка из Figma (117:406) — бак с листом;
                      // тонируется в t.ink, чтобы читаться в обеих темах.
                      child: SvgPicture.asset(
                        'assets/icons/trash.svg',
                        width: 26,
                        height: 26,
                        colorFilter: ColorFilter.mode(t.ink, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String v, String u, Color c, EcoTheme t) => Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            // Иконки статов из Figma: scale 117:356, gauge 209:1519, flame 117:475.
            // Тонируем в t.onDark (белый) поверх цветного круга. Спидометр (gauge)
            // визуально «тяжёлый» снизу — приподнимаем его чуть выше центра.
            child: Transform.translate(
              offset: Offset(0, icon == 'gauge' ? -2.5 : 0),
              child: SvgPicture.asset(
                'assets/icons/stat_$icon.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(t.onDark, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: v,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' $u',
                  style: TextStyle(fontSize: 12, color: t.sub),
                ),
              ],
            ),
          ),
        ],
      );

  void _selectChartPoint(Offset local, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final index = (local.dx * count / width).floor();
    setState(() => _selectedIndex = index.clamp(0, count - 1));
  }

  Future<void> _confirmDeleteEntry(DateTime date) async {
    final l = context.l10nRead;
    final store = context.read<AppStore>();
    final t = store.theme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x4714180C),
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          // Material-предок нужен заголовку, иначе текст рисуется с отладочным
          // жёлтым подчёркиванием (нет DefaultTextStyle).
          child: Material(
            type: MaterialType.transparency,
            child: EcoGlassSurface(
              t: t,
              blur: 60,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              borderRadius: BorderRadius.circular(26),
              shadows: const [
                BoxShadow(
                  color: Color(0x28FFFFFF),
                  blurRadius: 24,
                  offset: Offset(-2, -2),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.t('health.deleteEntryConfirm'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: EcoBtn(
                          t: t,
                          bg: t.band,
                          fg: t.ink,
                          height: 46,
                          onTap: () => Navigator.of(ctx).pop(false),
                          child: Text(l.t('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EcoBtn(
                          t: t,
                          height: 46,
                          onTap: () => Navigator.of(ctx).pop(true),
                          child: Text(l.t('common.yes')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      // deleteBodyEntry возвращает false, если по этой дате не было реальной
      // записи. Сбрасываем выбор только при фактическом удалении; иначе просто
      // ничего не делаем (с реальными-только точками до этой ветки не доходит).
      final removed = store.deleteBodyEntry(date);
      if (removed && mounted) setState(() => _selectedIndex = null);
    }
  }

  /// Реальные записи состава тела (по возрастанию даты). Никаких синтетических
  /// точек: график показывает ровно столько, сколько ввёл пользователь — иначе
  /// выдуманные точки нельзя ни удалить, ни отличить от настоящих.
  List<BodyMetricEntry> _chartEntries(AppStore s) {
    return s.bodyHistory.where((entry) => entry.weightKg > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

class _BodyDateTicks extends StatelessWidget {
  final List<DateTime> dates;
  final int selectedIndex;
  final EcoTheme t;

  const _BodyDateTicks({
    required this.dates,
    required this.selectedIndex,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox(height: 30);
    final currentYear = DateTime.now().year;
    // Год показываем только когда он отличается от текущего; место под него
    // резервируем для всех делений, чтобы числа стояли на одной линии.
    final anyOtherYear = dates.any((d) => d.year != currentYear);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < dates.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 75),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        i == selectedIndex ? FontWeight.w900 : FontWeight.w700,
                    color: i == selectedIndex ? t.ink : t.sub,
                  ),
                  // День/месяц через «/» (напр. 26/6).
                  child: Text('${dates[i].day}/${dates[i].month}'),
                ),
                if (anyOtherYear)
                  Text(
                    dates[i].year != currentYear ? '${dates[i].year}' : '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex ? t.ink : t.faint,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label, value, unit, lo, hi;
  final double frac;
  final VoidCallback? onTap;
  final bool last;
  // Цвет полосы: null → сплошная тёмная (как у веса), иначе градиент dark→accent.
  final Color? accent;
  final EcoTheme t;
  const _RangeRow({
    required this.t,
    required this.label,
    required this.value,
    required this.unit,
    required this.lo,
    required this.hi,
    required this.frac,
    this.onTap,
    this.accent,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = frac.clamp(0.04, 1.0);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 14, color: t.faint),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.sub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: t.bandSoft),
                  // Inset-жёлоб (утоплённость) — как у ProgressScale/макро-баров:
                  // рисуется ПОД заливкой, поэтому виден на незалитом остатке.
                  const Positioned.fill(child: EcoInsetShadow()),
                  FractionallySizedBox(
                    widthFactor: p,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        // Сплошной цвет без градиента: вес — тёмный, остальные —
                        // свой акцент.
                        color: accent ?? t.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
              Text(
                hi,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _BodyChartPainter extends CustomPainter {
  final List<double> points;
  final int selectedIndex;
  final EcoTheme t;

  _BodyChartPainter(this.points,
      {required this.selectedIndex, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var min = points.first;
    var max = points.first;
    for (final value in points.skip(1)) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    final span = max - min;
    if (span.abs() < 0.1) {
      min -= 3;
      max += 3;
    } else {
      final pad = span * 0.4;
      min -= pad;
      max += pad;
    }
    // Каждая точка — по центру своей «колонки» даты (i+0.5)/N, чтобы маркер
    // стоял ровно над числом в _BodyDateTicks (Row из Expanded-ячеек).
    double x(int i) => (i + 0.5) * (size.width / points.length);
    double y(double v) => size.height - ((v - min) / (max - min)) * size.height;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(x(i), y(points[i]));
      } else {
        path.lineTo(x(i), y(points[i]));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = t.ink,
    );
    final selected = selectedIndex.clamp(0, points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final isSelected = i == selected;
      // Обычные точки — чёрные (как линия), выбранная — зелёная и крупнее.
      canvas.drawCircle(
        Offset(x(i), y(points[i])),
        isSelected ? 8 : 4.5,
        Paint()..color = isSelected ? EcoColors.prot : t.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BodyChartPainter old) {
    if (old.selectedIndex != selectedIndex) return true;
    if (old.t != t) return true;
    if (old.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (old.points[i] != points[i]) return true;
    }
    return false;
  }
}

// ── Ввод веса ─────────────────────────────────────────────────

class BodyEntryScreen extends StatefulWidget {
  const BodyEntryScreen({super.key});
  @override
  State<BodyEntryScreen> createState() => _BodyEntryScreenState();
}

class _BodyEntryScreenState extends State<BodyEntryScreen> {
  static const _weightMin = 30;
  static const _weightMax = 200;

  late int intv;
  late int decv;
  late double skeletal = context.read<AppStore>().skeletalMuscle;
  late double fat = context.read<AppStore>().bodyFat;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final w = store.weight > 0 ? store.weight : (store.weightKg ?? 66.0);
    intv = w.floor().clamp(_weightMin, _weightMax).toInt();
    decv = (((w - w.floor()) * 10).round() % 10).toInt();
  }

  String _fmt(num v) {
    final language = context.l10nRead.language;
    final decimal = language == AppLanguage.ru || language == AppLanguage.uzCyrl
        ? ','
        : '.';
    return v.toStringAsFixed(1).replaceAll('.', decimal);
  }

  double get _weightValue =>
      double.parse((intv + decv / 10).toStringAsFixed(1));

  Future<void> _pickDate() {
    final t = context.read<AppStore>().theme;
    final l = context.l10nRead;
    final now = DateTime.now();
    var draft = _date;
    return showEcoSheet(
      context: context,
      t: t,
      title: l.t('health.entryDate'),
      doneLabel: l.t('common.save'),
      // Дата не может быть в будущем: пикер ограничивает только год, поэтому
      // клампим выбранный день к «сегодня» перед сохранением.
      onDone: () => setState(() {
        final today = DateTime.now();
        _date = draft.isAfter(today) ? today : draft;
      }),
      body: SizedBox(
        height: 200,
        child: EcoDatePicker(
          t: t,
          initialDate: _date,
          minYear: now.year - 5,
          maxYear: now.year,
          monthNames: [
            for (var m = 1; m <= 12; m++) l.monthName(m),
          ],
          onChanged: (d) => draft = d,
        ),
      ),
    );
  }

  Future<void> _pickMetric({
    required String title,
    required String unit,
    required double value,
    required int min,
    required int max,
    required ValueChanged<double> onSave,
  }) {
    final t = context.read<AppStore>().theme;
    var whole = value.floor().clamp(min, max).toInt();
    var tenth = ((value - value.floor()) * 10).round().clamp(0, 9).toInt();
    // Контроллеры создаём до показа шита и dispose'им по его закрытию: иначе
    // FixedExtentScrollController течёт на каждый показ пикера (как в T5).
    final wholeCtrl = FixedExtentScrollController(initialItem: whole - min);
    final tenthCtrl = FixedExtentScrollController(initialItem: tenth);
    return showEcoSheet(
      context: context,
      t: t,
      title: title,
      doneLabel: context.l10nRead.t('common.save'),
      onDone: () => setState(
        () => onSave(double.parse((whole + tenth / 10).toStringAsFixed(1))),
      ),
      body: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: SizedBox(
                width: 252,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker.builder(
                        scrollController: wholeCtrl,
                        itemExtent: 44,
                        selectionOverlay: EcoPickerSelectionOverlay(
                          t: t,
                        ),
                        onSelectedItemChanged: (index) => whole = min + index,
                        childCount: max - min + 1,
                        itemBuilder: (_, index) {
                          final current = min + index;
                          return Center(
                            child: Text(
                              '$current',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 34,
                      child: Center(
                        child: Text(
                          ',',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker.builder(
                        scrollController: tenthCtrl,
                        itemExtent: 44,
                        selectionOverlay: EcoPickerSelectionOverlay(
                          t: t,
                        ),
                        onSelectedItemChanged: (index) => tenth = index,
                        childCount: 10,
                        itemBuilder: (_, index) {
                          return Center(
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 28,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: t.sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      wholeCtrl.dispose();
      tenthCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    return EcoScreen(
      t: t,
      footer: actionFooter(
        context,
        onSave: () {
          final store = context.read<AppStore>();
          store.saveBodyMetrics(
            weightKg: _weightValue,
            skeletalMuscle: skeletal,
            bodyFat: fat,
            date: _date,
          );
          Navigator.of(context).pop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DatePill(date: _date, onTap: _pickDate),
          EcoCard(
            t: t,
            pad: 16,
            margin: const EdgeInsets.only(bottom: 14),
            child: FieldRow(
              label: l.t('health.bodyMass'),
              last: true,
              right: _MetricValueButton(
                value: _fmt(_weightValue),
                unit: l.unit('kg'),
                onTap: () => _pickMetric(
                  title: l.t('health.bodyMass'),
                  unit: l.unit('kg'),
                  value: _weightValue,
                  min: _weightMin,
                  max: _weightMax,
                  onSave: (v) {
                    intv = v.floor().clamp(_weightMin, _weightMax).toInt();
                    decv = ((v - v.floor()) * 10).round().clamp(0, 9).toInt();
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.t('health.weightAlsoProfile'),
              style: TextStyle(
                fontSize: 12,
                color: t.sub,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          EcoCard(
            t: t,
            pad: 16,
            child: Column(
              children: [
                FieldRow(
                  label: '${l.t('health.skeletalMuscle')} (${l.unit('kg')})',
                  right: _MetricValueButton(
                    value: _fmt(skeletal),
                    unit: l.unit('kg'),
                    onTap: () => _pickMetric(
                      title: l.t('health.skeletalMuscle'),
                      unit: l.unit('kg'),
                      value: skeletal,
                      min: 10,
                      max: 80,
                      onSave: (v) => skeletal = v,
                    ),
                  ),
                ),
                FieldRow(
                  label: '${l.t('health.bodyFat')} (%)',
                  last: true,
                  right: _MetricValueButton(
                    value: _fmt(fat),
                    unit: '%',
                    onTap: () => _pickMetric(
                      title: l.t('health.bodyFat'),
                      unit: '%',
                      value: fat,
                      min: 3,
                      max: 60,
                      onSave: (v) => fat = v,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, left: 4, right: 4),
            child: Text(
              l.t('health.bodyCompositionNote'),
              style: TextStyle(
                fontSize: 12,
                color: t.sub,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _MetricValueButton extends StatelessWidget {
  final String value;
  final String unit;
  final VoidCallback onTap;

  const _MetricValueButton({
    required this.value,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 2, bottom: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.olive, width: 1.5)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
