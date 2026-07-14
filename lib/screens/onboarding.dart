import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../nutrition/energy.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Тёмный петроль активных карточек-опций (макет Selection Item State=Active
/// 234:90) — тот же, что у залитой кнопки воды на Home.
const Color _petrol = Color(0xFF045157);

/// Onboarding — Eco design profile.jsx::Onboarding port.
/// welcome+язык (одна страница) → имя → дата рождения → рост → вес →
/// цель → активность → пол → норма (порядок по макетам 04 Screens, ряд
/// «Onboarding 0..8»).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const total = 8;

  int step = 0;
  String profileName = '';
  String sex = 'm';
  late DateTime birthDate;
  int height = 178;
  int weight = 66;
  String activity = 'mid';
  String goal = 'lose';
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    profileName = store.profileName ?? '';
    sex = store.gender == 'f' ? 'f' : 'm';
    birthDate = store.birthDate ?? DateTime(DateTime.now().year - 25, 1, 1);
    height = store.heightCm ?? 178;
    weight = (store.weightKg ?? (store.weight > 0 ? store.weight : 66))
        .round()
        .clamp(30, 200)
        .toInt();
    activity = store.activity ?? 'mid';
    goal = store.goal ?? 'lose';
    _nameCtrl = TextEditingController(text: profileName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Daily calorie goal: BMR (Schofield under 18, else Mifflin–St Jeor) → TDEE →
  // goal adjustment, clamped to a safe minimum. See nutrition/energy.dart.
  int get _norm => calorieGoalFor(
        ageYears: AppStore.ageFromBirth(birthDate),
        sex: sex,
        weightKg: weight.toDouble(),
        heightCm: height.toDouble(),
        activity: activity,
        goal: goal,
      );

  void _next() {
    if (step < total) {
      setState(() => step++);
      return;
    }
    final norm = _norm;
    context.read<AppStore>().completeOnboarding(
          profileName: profileName,
          gender: sex,
          birthDate: birthDate,
          heightCm: height,
          weightKg: weight.toDouble(),
          activity: activity,
          goal: goal,
          targetKcal: norm,
        );
    // После онбординга — экран согласия и разрешений (уведомления/шаги/
    // конфиденциальность), затем главный экран (см. гейт в main.dart).
    Navigator.of(context).pushReplacementNamed('/consent');
  }

  void _prev() {
    if (step > 0) setState(() => step--);
  }

  // Шаг выбора языка: переключаем язык приложения и перезагружаем базу продуктов
  // под новую локаль. Активный чип берётся из store (context.select в build),
  // поэтому setState здесь не нужен — setLanguage сам триггерит notifyListeners.
  Future<void> _selectLanguage(AppLanguage language) async {
    final store = context.read<AppStore>();
    if (language == store.language) return;
    await FoodDb.instance.load(localeCode: language.productLocale, force: true);
    if (!mounted) return;
    await store.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final lang = context.select<AppStore, AppLanguage>((s) => s.language);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(child: EcoGlassBackground(t: t)),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _ProgressHeader(
                        t: t,
                        step: step,
                        total: total,
                        onBack: _prev,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: box.maxHeight,
                                ),
                                // Шаги-вопросы (не welcome) якорятся к ВЕРХУ с
                                // одинаковым отступом → заголовок каждого шага на
                                // одном уровне, не «прыгает» при переходе (макеты
                                // онбординга: контент начинается на фикс. высоте).
                                // Welcome (лого+языки) — своя раскладка, центр.
                                child: Align(
                                  alignment: step == 0
                                      ? Alignment.center
                                      : Alignment.topCenter,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: step == 0 ? 18 : 200,
                                      bottom: 18,
                                    ),
                                    child: _buildStep(t, l, lang),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: bottomInset + 24,
                          top: 8,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          // Светлая стеклянная кнопка с press-состоянием
                          // (Default↔Variant2), макет компонента 227:6287.
                          child: EcoGlassButton(
                            onTap: _next,
                            child: Text(
                              step == 0
                                  ? l.t('onboarding.start')
                                  : step == total
                                      ? l.t('onboarding.enterApp')
                                      : l.t('onboarding.next'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // t и l приходят из build(): context.select нельзя вызывать здесь, потому что
  // _buildStep исполняется внутри builder у LayoutBuilder (фаза layout, а не
  // build), и provider бросает ассерт «context.select outside of build».
  Widget _buildStep(EcoTheme t, AppStrings l, AppLanguage lang) {
    switch (step) {
      case 0:
        // welcome + выбор языка на одной странице: лого и подписи подняты
        // вверх, под ними — переключатель языка (кнопка «Boshlash» остаётся
        // внизу, в общем footer-е build()).
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/branding/eco_logo.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Eco',
                      style: TextStyle(
                        color: t.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' health',
                      style: TextStyle(
                        color: t.olive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 38,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              // Подзаголовок занимает разное число строк в зависимости от языка
              // (англ. — 2, рус./узб. — 3), из-за чего «прыгало» лого. Резервируем
              // высоту под 3 строки и центрируем текст — раскладка одинаковая на
              // всех языках. Масштабируем по textScaler, чтобы не обрезалось при
              // увеличенном системном шрифте.
              SizedBox(
                width: 280,
                height: MediaQuery.textScalerOf(context).scale(16 * 1.25 * 3),
                child: Center(
                  child: Text(
                    l.t('onboarding.intro'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: t.sub,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 280,
                child: _LangSegmented(
                  t: t,
                  languages: AppLanguage.values,
                  value: lang,
                  onChanged: _selectLanguage,
                ),
              ),
            ],
          ),
        );
      case 1:
        // Поле имени (макет 222:21): glass-карточка r20 px16 py20, текст и
        // плейсхолдер Bold 16 (плейсхолдер приглушён faint).
        return _Step(
          title: l.t('onboarding.nameTitle'),
          sub: l.t('onboarding.nameSub'),
          children: [
            EcoGlassSurface(
              t: t,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (v) => profileName = v,
                decoration: InputDecoration(
                  hintText: l.t('profile.myProfile'),
                  hintStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.faint,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            ),
          ],
        );
      case 7:
        // Брендовые иконки пола (Icons Name=male 117:470 / Name=female 117:464);
        // на активной тёмной карточке глиф перекрашивается в белый.
        return _Step(
          title: l.t('onboarding.genderTitle'),
          children: [
            _OptionCard(
              svg: 'assets/icons/gender_male.svg',
              title: l.t('profile.male'),
              active: sex == 'm',
              onTap: () => setState(() => sex = 'm'),
            ),
            _OptionCard(
              svg: 'assets/icons/gender_female.svg',
              title: l.t('profile.female'),
              active: sex == 'f',
              onTap: () => setState(() => sex = 'f'),
            ),
          ],
        );
      case 2:
        // Карточка даты (макет BirthDatePicker 233:576): py12, барабан h216,
        // пилюли-оверлеи по колонкам — внутри EcoDatePicker.
        return _Step(
          title: l.t('onboarding.ageTitle'),
          children: [
            EcoGlassSurface(
              t: t,
              blur: 60,
              // py20 + барабан 216 = высота карточки как у роста/веса (256),
              // чтобы три пикер-карточки совпадали по высоте и ширине.
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                height: 216,
                child: EcoDatePicker(
                  t: t,
                  initialDate: birthDate,
                  minYear: DateTime.now().year - 100,
                  maxYear: DateTime.now().year - 5,
                  monthNames: [for (var m = 1; m <= 12; m++) l.monthName(m)],
                  // Без setState: значение пишем в поле, но НЕ перестраиваем весь
                  // Stack на каждый щелчок колеса (пикер сам держит позицию, а
                  // больше нигде значение не отображается до шага-итога).
                  onChanged: (d) => birthDate = d,
                ),
              ),
            ),
          ],
        );
      case 3:
        return _Step(
          title: l.t('onboarding.heightTitle'),
          children: [
            // Карточка колеса (макет HeightPicker 233:595): только вертикальный
            // паддинг — пилюля-оверлей шириной почти во всю карточку (348/380).
            EcoGlassSurface(
              t: t,
              blur: 60,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _WheelValuePicker(
                // Ключ обязателен: без него элемент колеса переиспользуется
                // между шагами рост→вес, а Flutter при подмене контроллера
                // сохраняет позицию скролла — колесо показывает чужой индекс
                // (рост 178 → «88 кг»), хотя в состоянии остаётся дефолт 66.
                key: const ValueKey('onboarding.height'),
                value: height,
                min: 120,
                max: 220,
                unit: l.unit('cm'),
                onChanged: (v) => height = v, // без перестройки всего экрана
              ),
            ),
          ],
        );
      case 4:
        return _Step(
          title: l.t('onboarding.weightTitle'),
          children: [
            EcoGlassSurface(
              t: t,
              blur: 60,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _WheelValuePicker(
                key: const ValueKey('onboarding.weight'),
                value: weight,
                min: 30,
                max: 200,
                unit: l.unit('kg'),
                onChanged: (v) => weight = v, // без перестройки всего экрана
              ),
            ),
          ],
        );
      case 6:
        // Иконки активности — те же брендовые SVG, что в панелях профиля
        // (act_person/act_walk/act_dumbbell), плоские 40px без круга-бейджа.
        return _Step(
          title: l.t('onboarding.activityTitle'),
          children: [
            _OptionCard(
              svg: 'assets/icons/act_person.svg',
              title: l.t('onboarding.activityLow'),
              sub: l.t('onboarding.activityLowSub'),
              active: activity == 'low',
              onTap: () => setState(() => activity = 'low'),
            ),
            _OptionCard(
              svg: 'assets/icons/act_walk.svg',
              title: l.t('onboarding.activityMid'),
              sub: l.t('onboarding.activityMidSub'),
              active: activity == 'mid',
              onTap: () => setState(() => activity = 'mid'),
            ),
            _OptionCard(
              svg: 'assets/icons/act_dumbbell.svg',
              title: l.t('onboarding.activityHigh'),
              sub: l.t('onboarding.activityHighSub'),
              active: activity == 'high',
              onTap: () => setState(() => activity = 'high'),
            ),
          ],
        );
      case 5:
        return _Step(
          title: l.t('onboarding.goalTitle'),
          children: [
            _OptionCard(
              svg: 'assets/icons/goal_trend.svg',
              flipY: true, // «Снизить вес» = тот же тренд, отражённый вниз
              title: l.t('onboarding.goalLose'),
              active: goal == 'lose',
              onTap: () => setState(() => goal = 'lose'),
            ),
            _OptionCard(
              svg: 'assets/icons/goal_balance.svg',
              title: l.t('onboarding.goalKeep'),
              active: goal == 'keep',
              onTap: () => setState(() => goal = 'keep'),
            ),
            _OptionCard(
              svg: 'assets/icons/goal_trend.svg',
              title: l.t('onboarding.goalGain'),
              active: goal == 'gain',
              onTap: () => setState(() => goal = 'gain'),
            ),
          ],
        );
      default:
        // Итоговый экран (макет DailyNormSummary 233:611): слева кольца 168
        // с числом нормы ПОД ними, справа — легенда как на Home (граммы и ккал
        // двумя строками 12px).
        final norm = _norm;
        final carbs = (norm * 0.45 / 4).round();
        final protein = (norm * 0.3 / 4).round();
        final fat = (norm * 0.25 / 9).round();
        return _Step(
          // Подпись «Рассчитана по формуле…» — НЕ между заголовком и карточкой,
          // а ПОД карточкой (второй ребёнок), чтобы карточка поднималась вплотную
          // к заголовку.
          title: l.t('onboarding.dailyNorm'),
          children: [
            EcoCard(
              t: t,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 168,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MacroRings(
                          t: t,
                          size: 168,
                          data: [
                            MacroRingData(
                              value: 1,
                              goal: 1,
                              color: EcoColors.carb,
                              soft: EcoColors.carbSoft,
                            ),
                            MacroRingData(
                              value: 0.74,
                              goal: 1,
                              color: EcoColors.fat,
                              soft: EcoColors.fatSoft,
                            ),
                            MacroRingData(
                              value: 0.48,
                              goal: 1,
                              color: EcoColors.prot,
                              soft: EcoColors.protSoft,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$norm',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.unit('kcalPerDay'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: t.sub,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _macroLine(t, l, l.nutrient('carbs'), carbs, carbs * 4,
                            EcoColors.carb),
                        _macroLine(t, l, l.nutrient('fat'), fat, fat * 9,
                            EcoColors.fat),
                        _macroLine(t, l, l.nutrient('protein'), protein,
                            protein * 4, EcoColors.prot),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Подпись-пояснение под карточкой, по центру.
            SizedBox(
              width: double.infinity,
              child: Text(
                l.t('onboarding.dailyNormSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: t.sub,
                  height: 1.3,
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Строка легенды нормы: точка-цвет + название + «граммы» и «ккал» двумя
  /// строками (жирное число + приглушённая единица), как в MacroLegend Home.
  /// [l] передаётся параметром (не через context): _macroLine вызывается из
  /// _buildStep в фазе layout LayoutBuilder, где context.select/watch запрещены.
  Widget _macroLine(
      EcoTheme t, AppStrings l, String label, int grams, int kcal, Color color) {
    Widget value(String v, String unit) => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: v,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: t.ink,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                  color: t.sub,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                value('$grams', l.unit('g')),
                const SizedBox(height: 2),
                value('$kcal', l.unit('kcal')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final EcoTheme t;
  final int step;
  final int total;
  final VoidCallback onBack;

  const _ProgressHeader({
    required this.t,
    required this.step,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Стеклянный топбар (макет _OnboardingTopBar 227:5907): glass-карточка r20
    // pad16; строка [шеврон 24 · «N/9» Bold 12 sub], ниже 9 сегментов h4 r2
    // gap4 — пройденные и текущий = olive, остальные = track.
    return EcoCard(
      t: t,
      pad: 16,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(
                  Icons.chevron_left,
                  size: 24,
                  color: step > 0 ? t.ink : t.faint,
                ),
              ),
              const Spacer(),
              Text(
                '${step + 1}/${total + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: t.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i <= total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? t.olive : t.track,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Step layout: title + optional sub + content.
class _Step extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> children;

  const _Step({required this.title, this.sub, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                sub!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: t.sub,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            c,
          ],
        ],
      ),
    );
  }
}

/// Selectable option row (макет Selection Item 234:92, h72 r20): плоская
/// брендовая SVG-иконка 40px (без круга-бейджа) + title/sub + радио-чек.
/// Активная — тёмный петроль #045157 с glass-объёмом (drop-тень + inset-блик,
/// через [EcoGlassChip]), глиф и радио белые. Неактивная — стекло EcoCard
/// (заливка ползунка прозрачности + кайма glassBorder + белый хайлайт).
class _OptionCard extends StatelessWidget {
  final String svg;
  final bool flipY;
  final String title;
  final String? sub;
  final bool active;
  final VoidCallback onTap;

  const _OptionCard({
    required this.svg,
    this.flipY = false,
    required this.title,
    this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    Widget icon = SvgPicture.asset(
      svg,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      colorFilter: active
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : ColorFilter.mode(t.iconOlive, BlendMode.srcIn),
    );
    if (flipY) icon = Transform.flip(flipY: true, child: icon);
    final row = Row(
      children: [
        SizedBox(width: 40, height: 40, child: icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: active ? t.onDark : t.ink,
                ),
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? t.onDark.withValues(alpha: 0.65) : t.sub,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            border: active ? null : Border.all(color: t.bandSoft, width: 2),
          ),
          child: active
              ? const Icon(Icons.check, size: 15, color: _petrol)
              : null,
        ),
      ],
    );
    if (active) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: EcoGlassChip(
          radius: 20,
          color: _petrol,
          width: double.infinity,
          height: 72,
          padding: const EdgeInsets.only(left: 16, right: 22),
          child: row,
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: EcoGlassSurface(
        t: t,
        width: double.infinity,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: row),
      ),
    );
  }
}

/// Big −/+ stepper around a large value.
class _WheelValuePicker extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _WheelValuePicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_WheelValuePicker> createState() => _WheelValuePickerState();
}

class _WheelValuePickerState extends State<_WheelValuePicker> {
  late FixedExtentScrollController _controller;

  int get _index =>
      (widget.value - widget.min).clamp(0, widget.max - widget.min).toInt();
  int get _count => widget.max - widget.min + 1;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant _WheelValuePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min || oldWidget.max != widget.max) {
      _controller.dispose();
      _controller = FixedExtentScrollController(initialItem: _index);
      return;
    }
    if (oldWidget.value != widget.value && _controller.selectedItem != _index) {
      _controller.jumpToItem(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return SizedBox(
      height: 216,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Пилюля выбранного значения (макет HeightPicker 233:599): r999,
          // white α34 + кайма 1.1 α55, почти во всю ширину карточки (348/380).
          EcoPickerSelectionOverlay(
            t: t,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 79),
            radius: 999,
            fill: Colors.white.withValues(alpha: 0.34),
          ),
          CupertinoPicker.builder(
            scrollController: _controller,
            itemExtent: 58,
            diameterRatio: 1.35,
            squeeze: 0.92,
            useMagnifier: true,
            magnification: 1.12,
            selectionOverlay: const SizedBox.shrink(),
            childCount: _count,
            onSelectedItemChanged: (index) =>
                widget.onChanged(widget.min + index),
            itemBuilder: (context, index) {
              final value = widget.min + index;
              return Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: t.ink,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.unit}',
                        style: TextStyle(
                          fontSize: 18,
                          color: t.sub,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _BigStepper extends StatelessWidget {
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  const _BigStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _round(t, Icons.remove, () => onChanged(value - 1)),
          SizedBox(
            width: 170,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$value',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 18,
                      color: t.sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _round(t, Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _round(EcoTheme t, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: t.onDark),
      ),
    );
  }
}

/// Language picker: glass-карточка со списком языков и скользящей СВЕТЛОЙ
/// пилюлей на активной строке (макет Welcome 224:58/224:60: карточка r20 py12,
/// строки Bold 16 ink, пилюля white α34 + кайма 1.1 α55 — как оверлей колёс).
class _LangSegmented extends StatelessWidget {
  final EcoTheme t;
  final List<AppLanguage> languages;
  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  const _LangSegmented({
    required this.t,
    required this.languages,
    required this.value,
    required this.onChanged,
  });

  static const _rowHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final index = languages.indexOf(value).clamp(0, languages.length - 1);
    return EcoGlassSurface(
      t: t,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: _alignmentFor(index),
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 1 / languages.length,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              for (final language in languages)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(language),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Center(
                      child: Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(int index) {
    if (languages.length <= 1) return Alignment.center;
    final y = -1 + 2 * (index / (languages.length - 1));
    return Alignment(0, y);
  }
}
