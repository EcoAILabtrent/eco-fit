import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
import '../nutrition/energy.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/language_selector.dart';
import '../ui/ui.dart';
import 'home.dart' show HomeScreen, MealPickerHost;

/// Профиль — port of profile.jsx::Profile. Identity + goals + body params +
/// settings, fed by the real onboarding data from the store.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _editProfile() {
    Navigator.of(context).push(
      EcoPageRoute<void>(
        builder: (_) => const _ProfileEditScreen(),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    context.read<AppStore>().setAvatarPath(picked.path);
  }

  // Сброс данных: спрашиваем подтверждение (действие необратимо), затем
  // очищаем хранилище и уводим в онбординг, как при первом запуске.
  Future<void> _confirmResetData() async {
    final l = context.l10nRead;
    final store = context.read<AppStore>();
    final t = store.theme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x4714180C),
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          // Material-предок нужен тексту, иначе он рисуется с отладочным
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
                    l.t('common.resetData'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.t('common.resetDataConfirm'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: t.sub,
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
    if (confirmed != true || !mounted) return;
    await store.resetUserData();
    if (!mounted) return;
    // База продуктов под язык по умолчанию (reset вернул язык к дефолту), как
    // при чистом запуске; язык всё равно переспрашивается на 1-м шаге онбординга.
    await FoodDb.instance.load(localeCode: store.language.productLocale);
    if (!mounted) return;
    // Чистый старт: вычищаем стек навигации и ведём в онбординг.
    Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (_) => false);
  }

  // Read-only label/value row (same look as the editor, without the chevron).
  Widget _paramRow(EcoTheme t, String label, String value,
      {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: t.sub),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: t.sub),
          ),
        ],
      ),
    );
  }

  String _weightStr(AppStore s, AppStrings l) {
    final kg = s.weightKg ?? (s.weight > 0 ? s.weight : null);
    if (kg == null) return '—';
    final decimal =
        l.language.code == 'ru' || l.language.code == 'uz_cyrl' ? ',' : '.';
    return '${kg.toStringAsFixed(1).replaceAll('.', decimal)} ${l.unit('kg')}';
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся только на ПОКАЗАННЫЕ поля профиля (без cardOpacity — он
    // обновляется в ползунке/карточках через свой select; иначе перетаскивание
    // перестраивало бы весь экран каждый кадр) и без тиков шагомера/воды.
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    context.select<AppStore, int>((s) => Object.hash(
          s.profileName,
          s.gender,
          s.birthDate,
          s.heightCm,
          s.avatarPath,
          s.darkMode,
        ));
    final s = context.read<AppStore>();
    final l = context.l10n;
    final profileName = s.profileName ?? l.t('profile.myProfile');

    return EcoScreen(
      t: t,
      // Заголовок закреплён сверху (не скроллится): контент уезжает под него.
      header: EcoTopBar(t: t, title: l.t('profile.profile')),
      footer: MealPickerHost(
        t: t,
        active: 'profile',
        onHome: () => Navigator.of(context).pushAndRemoveUntil(
          // Профиль → главная мгновенно (без анимации), как переключение вкладок.
          EcoInstantRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => const HomeScreen(),
          ),
          (_) => false,
        ),
        onProfile: () {},
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 150 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity — avatar straddling the card top, name centred,
            // read-only body params below.
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 60, bottom: 12),
                  child: EcoCard(
                    t: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 62),
                        Center(
                          // Пилюля-имя, единый glass-объём (макет 167:1242).
                          child: EcoGlassChip(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            child: Text(
                              profileName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: t.sub,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _paramRow(
                          t,
                          l.t('profile.sex'),
                          s.gender == 'f'
                              ? l.t('profile.female')
                              : s.gender == 'm'
                                  ? l.t('profile.male')
                                  : '—',
                        ),
                        _paramRow(
                          t,
                          l.t('profile.age'),
                          s.birthDate != null
                              ? l.birthValue(s.birthDate!)
                              : '—',
                        ),
                        _paramRow(
                          t,
                          l.t('profile.height'),
                          s.heightCm != null
                              ? '${s.heightCm} ${l.unit('cm')}'
                              : '—',
                        ),
                        _paramRow(
                          t,
                          l.t('profile.weight'),
                          _weightStr(s, l),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ProfileAvatar(
                      path: s.avatarPath,
                      size: 128,
                      onTap: _pickAvatar,
                    ),
                  ),
                ),
                Positioned(
                  top: 80,
                  right: 14,
                  // Стандартная стеклянная кнопка (как «Начать») с press-эффектом,
                  // круг 48×48 (размер прежний).
                  child: EcoGlassButton(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.zero,
                    onTap: _editProfile,
                    child: Center(
                      child: SvgPicture.asset('assets/icons/edit.svg',
                          height: 22,
                          colorFilter:
                              ColorFilter.mode(t.iconOlive, BlendMode.srcIn)),
                    ),
                  ),
                ),
              ],
            ),

            // Settings
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Шапка: иконка-шестерёнка без белого бейджа (макет 167:1196
                  // header), консистентно с карточками Home.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SvgPicture.asset('assets/icons/gear.svg',
                                height: 38,
                                colorFilter: ColorFilter.mode(
                                    t.iconOlive, BlendMode.srcIn)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l.t('common.settings'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  // Первая строка настроек (макет 160-2): открывает экран
                  // «Соглашение и разрешения» с тумблерами ИИ/уведомлений/шагов.
                  _row(
                    t,
                    l.t('consent.title'),
                    '',
                    onTap: () => Navigator.of(context).pushNamed('/consent'),
                  ),
                  _row(
                    t,
                    l.t('common.language'),
                    '',
                    control: LanguageSelector(
                      t: t,
                      compact: true,
                      width: 58,
                      height: 32,
                    ),
                  ),
                  _row(
                    t,
                    l.t('common.darkTheme'),
                    '',
                    control: EcoSettingToggle(
                      on: s.darkMode,
                      onChanged: (v) => context.read<AppStore>().setDarkMode(v),
                      iconOff: 'assets/icons/theme_sun.svg',
                      iconOn: 'assets/icons/theme_moon.svg',
                    ),
                  ),
                  // Ползунок прозрачности карточек (вправо = прозрачнее).
                  // Свой Builder со select(cardOpacity): перетаскивание
                  // перестраивает только эту строку (и стеклянные карточки — у них
                  // свой select), а не весь экран профиля каждый кадр.
                  Builder(
                    builder: (context) {
                      final cardOpacity = context
                          .select<AppStore, double>((x) => x.cardOpacity);
                      // Последняя строка карточки настроек (мёртвый пункт
                      // «Конфиденциальность» удалён) — без нижней разделительной
                      // линии.
                      return Container(
                        padding: const EdgeInsets.only(top: 14, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.t('common.cardTransparency'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: t.sub,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(((0.95 - cardOpacity) / (0.95 - 0.08)) * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: t.sub,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Кастомный ползунок «стекло» (макет slider 167:1400):
                            // жёлоб-трек с наружной drop-тенью + внутренней тёмной
                            // (утоплённость), заливка петроль #045157 с белым
                            // inset-хайлайтом, бегунок — frosted-стекло 29×18 r9
                            // (олива α0.3 + backdrop-blur). Трек во всю ширину.
                            _GlassSlider(
                              value: ((0.95 - cardOpacity) / (0.95 - 0.08))
                                  .clamp(0.0, 1.0),
                              onChanged: (v) => context
                                  .read<AppStore>()
                                  .setCardOpacity(0.95 - v * (0.95 - 0.08)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              // Reset-кнопка собрана 1-в-1 по макету reset-button 163:601:
              // плоское стекло (БЕЗ backdrop-blur) через EcoGlassButton —
              // white × cardOpacity + drop-тень 2/2/2 α25 (рисуется ТОЛЬКО
              // снаружи контура, не темнит заливку) + inset-белый хайлайт
              // 2/2/2 α25, r999, padH22, h56, иконка 32 + gap12 + текст Onest
              // Bold 18 #010103. Прозрачность заливки привязана к ползунку
              // «Прозрачность карточек» (как у карточек).
              // Сброс данных стирает профиль и прогресс → ведёт в онбординг.
              child: EcoGlassButton(
                height: 56,
                onTap: _confirmResetData,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/icons/reset.svg',
                        height: 32,
                        colorFilter:
                            ColorFilter.mode(t.iconOlive, BlendMode.srcIn)),
                    const SizedBox(width: 12),
                    Text(
                      l.t('common.resetData'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    EcoTheme t,
    String label,
    String value, {
    Widget? control,
    VoidCallback? onTap,
    bool last = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Row(
          children: [
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
            if (control != null)
              control
            else ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: t.faint,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileEditScreen extends StatefulWidget {
  const _ProfileEditScreen();

  @override
  State<_ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<_ProfileEditScreen> {
  final _genderRowKey = GlobalKey();
  late final TextEditingController _nameCtrl;
  String? _avatarPath;
  late String _gender;
  late DateTime _birthDate;
  late int _height;
  late double _weight;
  late String _activity;
  late String _goal;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _nameCtrl = TextEditingController(
      text: store.profileName ?? context.l10nRead.t('profile.myProfile'),
    );
    _avatarPath = store.avatarPath;
    _gender = store.gender == 'f' ? 'f' : 'm';
    _birthDate = store.birthDate ?? DateTime(DateTime.now().year - 25, 1, 1);
    _height = store.heightCm ?? 178;
    _weight = (store.weightKg ?? (store.weight > 0 ? store.weight : 66))
        .clamp(30, 200)
        .toDouble();
    _activity = store.activity ?? 'mid';
    _goal = store.goal ?? 'lose';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _norm => calorieGoalFor(
        ageYears: AppStore.ageFromBirth(_birthDate),
        sex: _gender,
        weightKg: _weight,
        heightCm: _height.toDouble(),
        activity: _activity,
        goal: _goal,
      );

  String _formatWeight(AppStrings l) {
    final decimal =
        l.language.code == 'ru' || l.language.code == 'uz_cyrl' ? ',' : '.';
    return _weight.toStringAsFixed(1).replaceAll('.', decimal);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    // Аватар держим в локальном состоянии до «Сохранить»: «Отмена» должна
    // откатывать выбор, а не оставлять новый аватар в сторе.
    setState(() => _avatarPath = picked.path);
  }

  Future<void> _pickBirthDate() {
    final t = context.read<AppStore>().theme;
    var draft = _birthDate;
    return showEcoSheet(
      context: context,
      t: t,
      title: context.l10nRead.t('profile.age'),
      doneLabel: context.l10nRead.t('common.save'),
      onDone: () => setState(() => _birthDate = draft),
      body: SizedBox(
        height: 200,
        child: EcoDatePicker(
          t: t,
          initialDate: _birthDate,
          minYear: DateTime.now().year - 100,
          maxYear: DateTime.now().year - 5,
          monthNames: [
            for (var m = 1; m <= 12; m++) context.l10nRead.monthName(m),
          ],
          onChanged: (d) => draft = d,
        ),
      ),
    );
  }

  Future<void> _pickGender() async {
    final l = context.l10nRead;
    final t = context.read<AppStore>().theme;
    final next = await showEcoChoicePopup<String>(
      context: context,
      t: t,
      anchorKey: _genderRowKey,
      selected: _gender,
      options: [
        EcoChoiceOption(value: 'm', label: l.t('profile.male')),
        EcoChoiceOption(value: 'f', label: l.t('profile.female')),
      ],
    );
    if (next != null && mounted) {
      setState(() => _gender = next);
    }
  }

  Future<void> _pickNumber({
    required String title,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onSave,
  }) async {
    final t = context.read<AppStore>().theme;
    var draft = value;
    // Контроллер создаём заранее и dispose'им после закрытия шита, иначе
    // FixedExtentScrollController течёт на каждый показ пикера.
    final ctrl = FixedExtentScrollController(
      initialItem: (value - min).clamp(0, max - min).toInt(),
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x4714180C),
      builder: (sheetCtx) => EcoGlassSurface(
        t: t,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
        // Окно ввода: полупрозрачная стеклянная подложка как у пикеров
        // онбординга («Ваш рост»). solid:false → фон просвечивает, + сильное
        // размытие, чтобы фон не мешал.
        solid: false,
        blur: 60,
        borderRadius: BorderRadius.circular(26),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 156,
                  child: CupertinoPicker.builder(
                    scrollController: ctrl,
                    itemExtent: 42,
                    selectionOverlay: EcoPickerSelectionOverlay(
                      t: t,
                    ),
                    onSelectedItemChanged: (index) =>
                        setSheetState(() => draft = min + index),
                    childCount: max - min + 1,
                    itemBuilder: (_, index) {
                      final current = min + index;
                      return Center(
                        child: Text(
                          '$current $unit',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: EcoBtn(
                        t: t,
                        height: 46,
                        fontSize: 16,
                        bg: t.pill,
                        fg: t.ink,
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        child: Text(context.l10nRead.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EcoBtn(
                        t: t,
                        height: 46,
                        fontSize: 16,
                        onTap: () {
                          onSave(draft);
                          Navigator.of(sheetCtx).pop();
                        },
                        child: Text(context.l10nRead.t('common.save')),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    ctrl.dispose();
  }

  void _save() {
    final store = context.read<AppStore>();
    final savedWeight = store.weightKg ??
        (store.weight > 0 ? store.weight : _weight.toDouble());
    // Аватар пишем в стор только сейчас (в _pickAvatar он был локальным).
    store.setAvatarPath(_avatarPath);
    store.completeOnboarding(
      profileName: _nameCtrl.text,
      gender: _gender,
      birthDate: _birthDate,
      heightCm: _height,
      weightKg: savedWeight,
      activity: _activity,
      goal: _goal,
      targetKcal: _norm,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(
              child: EcoGlassBackground(t: t),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Заголовок ЗАКРЕПЛЁН сверху (не скроллится): контент уезжает
                  // под него. Инсет 16 по бокам — как у прокрутки ниже.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EcoTopBar(
                      t: t,
                      title: l.t('profile.editTitle'),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    // Верх области прокрутки скруглён (радиус карточки): контент
                    // уезжает под шапку и обрезается СО СКРУГЛЕНИЕМ. Инсет 16 —
                    // на Padding снаружи клипа, чтобы скругление совпало с краями
                    // карточек.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(t.r)),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: 116 + bottomInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Big avatar straddling the name card top — tap → gallery.
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                        top: 64, bottom: 12),
                                    child: EcoGlassSurface(
                                      t: t,
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 82, 18, 16),
                                      child: Center(
                                        child: EcoGlassChip(
                                          radius: 999,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 12,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minWidth: 80,
                                              maxWidth: 240,
                                            ),
                                            child: IntrinsicWidth(
                                              child: TextField(
                                                controller: _nameCtrl,
                                                textAlign: TextAlign.center,
                                                keyboardType:
                                                    TextInputType.name,
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: t.sub,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _ProfileAvatar(
                                        path: _avatarPath,
                                        size: 128,
                                        onTap: () =>
                                            _pickAvatar(ImageSource.gallery),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              EcoGlassSurface(
                                t: t,
                                padding:
                                    const EdgeInsets.fromLTRB(14, 16, 14, 0),
                                margin: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _EditCardHeader(
                                      title: l.t('home.bodyParams'),
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: t.bandSoft,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              l.t('profile.sex'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: t.sub,
                                              ),
                                            ),
                                          ),
                                          EcoGlassChip(
                                            key: _genderRowKey,
                                            onTap: _pickGender,
                                            radius: 999,
                                            padding: const EdgeInsets.all(6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SvgPicture.asset(
                                                  _gender == 'm'
                                                      ? 'assets/icons/gender_male.svg'
                                                      : 'assets/icons/gender_female.svg',
                                                  width: 20,
                                                  height: 20,
                                                  colorFilter:
                                                      ColorFilter.mode(
                                                          t.sub,
                                                          BlendMode.srcIn),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _gender == 'm'
                                                      ? l.t('profile.male')
                                                      : l.t('profile.female'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: t.sub,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _ProfileEditRow(
                                      label: l.t('profile.age'),
                                      value: l.birthValue(_birthDate),
                                      onTap: _pickBirthDate,
                                    ),
                                    _ProfileEditRow(
                                      label: l.t('profile.height'),
                                      value: '$_height ${l.unit('cm')}',
                                      onTap: () => _pickNumber(
                                        title: l.t('profile.height'),
                                        value: _height,
                                        min: 120,
                                        max: 220,
                                        unit: l.unit('cm'),
                                        onSave: (v) =>
                                            setState(() => _height = v),
                                      ),
                                    ),
                                    _ProfileEditRow(
                                      label: l.t('profile.weight'),
                                      value:
                                          '${_formatWeight(l)} ${l.unit('kg')}',
                                      last: true,
                                      onTap: () async {
                                        await Navigator.of(context)
                                            .pushNamed('/bodyEntry');
                                        if (!context.mounted) return;
                                        final store = context.read<AppStore>();
                                        setState(() {
                                          _weight = (store.weightKg ??
                                                  (store.weight > 0
                                                      ? store.weight
                                                      : 66))
                                              .clamp(30, 200)
                                              .toDouble();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              _ChoicePanel(
                                title: l.t('onboarding.activityTitle'),
                                values: [
                                  _ChoiceValue(
                                    key: 'low',
                                    svg: 'assets/icons/act_person.svg',
                                    label: '1',
                                    title: l.t('onboarding.activityLow'),
                                    sub: l.t('onboarding.activityLowSub'),
                                  ),
                                  _ChoiceValue(
                                    key: 'mid',
                                    svg: 'assets/icons/act_walk.svg',
                                    label: '2',
                                    title: l.t('onboarding.activityMid'),
                                    sub: l.t('onboarding.activityMidSub'),
                                  ),
                                  _ChoiceValue(
                                    key: 'high',
                                    svg: 'assets/icons/act_dumbbell.svg',
                                    label: '3',
                                    title: l.t('onboarding.activityHigh'),
                                    sub: l.t('onboarding.activityHighSub'),
                                  ),
                                ],
                                selected: _activity,
                                onChanged: (v) => setState(() => _activity = v),
                              ),
                              const SizedBox(height: 14),
                              _ChoicePanel(
                                title: l.t('onboarding.goalTitle'),
                                values: [
                                  _ChoiceValue(
                                    key: 'lose',
                                    svg: 'assets/icons/goal_trend.svg',
                                    flipY: true,
                                    label: '1',
                                    title: l.t('onboarding.goalLose'),
                                    sub: '',
                                  ),
                                  _ChoiceValue(
                                    key: 'keep',
                                    svg: 'assets/icons/goal_balance.svg',
                                    label: '2',
                                    title: l.t('onboarding.goalKeep'),
                                    sub: '',
                                  ),
                                  _ChoiceValue(
                                    key: 'gain',
                                    svg: 'assets/icons/goal_trend.svg',
                                    label: '3',
                                    title: l.t('onboarding.goalGain'),
                                    sub: '',
                                  ),
                                ],
                                selected: _goal,
                                onChanged: (v) => setState(() => _goal = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18 + bottomInset,
              // Обе кнопки — стандартная стеклянная (макет Button 217:85:
              // Secondary/Primary = светлое стекло, Type3/4 = нажатое). Размеры
              // из Figma (213:2097/2100): h56 r999 padH22, gap16, по ширине
              // поровну (Expanded); текст Onest SemiBold 16 ink; press встроен.
              child: Row(
                children: [
                  Expanded(
                    child: EcoGlassButton(
                      // Пинятся над прокруткой → искажение фона (backdrop-blur).
                      frosted: true,
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        l.t('common.cancel'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EcoGlassButton(
                      frosted: true,
                      onTap: _save,
                      child: Text(
                        l.t('common.save'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
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

class _EditCardHeader extends StatelessWidget {
  final String title;

  const _EditCardHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/body_figure.svg',
              height: 40,
              colorFilter: ColorFilter.mode(t.iconOlive, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  const _ProfileEditRow({
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.3)),
      ),
      child: Row(
        children: [
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
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: t.sub,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 17, color: t.faint),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? path;
  final double size;
  final VoidCallback? onTap;

  const _ProfileAvatar({this.path, this.size = 80, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        path != null && path!.isNotEmpty && File(path!).existsSync();
    // Фото — обычный круг с тенью; без фото — петролевый круг с белой эко-иконкой
    // и ЕДИНЫМ glass-объёмом (drop + inset-хайлайт), макет profile-o 167:1245.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: hasImage
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 3,
                    offset: Offset(2, 2),
                  ),
                ],
                image: DecorationImage(
                  image: FileImage(File(path!)),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : EcoGlassChip(
              width: size,
              height: size,
              radius: size / 2,
              color: const Color(0xFF045157),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/profile.svg',
                  height: size * 0.64,
                ),
              ),
            ),
    );
  }
}

class _ChoiceValue {
  final String key;
  final String svg;

  /// true → зеркалить иконку по вертикали (trending-up → trending-down).
  final bool flipY;
  final String label;
  final String title;
  final String sub;

  const _ChoiceValue({
    required this.key,
    required this.svg,
    this.flipY = false,
    required this.label,
    required this.title,
    required this.sub,
  });
}

/// Круг-иконка выбора (активность/цель) по макету 213:1921/1922: glass-чип 52,
/// выбранный залит петролем #045157 (иконка белая), пассивный — frosted-стекло
/// (иконка олива #555F3B). Иконки — кастомные контурные SVG, тинт через srcIn.
class _ChoiceCircle extends StatelessWidget {
  final String svg;
  final bool flipY;
  final bool selected;
  final VoidCallback? onTap;

  const _ChoiceCircle({
    required this.svg,
    required this.flipY,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    Widget icon = SvgPicture.asset(
      svg,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        selected ? Colors.white : t.iconOlive,
        BlendMode.srcIn,
      ),
    );
    if (flipY) {
      icon = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, -1, 1),
        child: icon,
      );
    }
    return EcoGlassChip(
      width: 52,
      height: 52,
      radius: 26,
      color: selected ? const Color(0xFF045157) : null,
      onTap: onTap,
      child: SizedBox(width: 30, height: 30, child: icon),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  final String title;
  final List<_ChoiceValue> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChoicePanel({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final selectedValue = values.firstWhere(
      (item) => item.key == selected,
      orElse: () => values.first,
    );
    return EcoGlassSurface(
      t: t,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final item in values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(item.key),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        _ChoiceCircle(
                          svg: item.svg,
                          flipY: item.flipY,
                          selected: item.key == selected,
                          onTap: () => onChanged(item.key),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            selectedValue.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          if (selectedValue.sub.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              selectedValue.sub,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                color: t.sub,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Кастомный ползунок прозрачности «жидкое стекло» — 1-в-1 по макету
/// slider 167:1400 (Material Slider не тянет frosted-thumb и двойную тень трека).
/// Трек-жёлоб: cardAlt + НАРУЖНАЯ drop-тень `2/2/2 α25` + ВНУТРЕННЯЯ тёмная
/// `inset 2/2/2 α25` (утоплённость). Заливка: петроль `#045157` + inset белый
/// хайлайт `2/2/2 α25`. Бегунок: 29×18 r9, олива α0.3 + backdrop-blur (frosted).
/// Трек — во всю доступную ширину (без боковых отступов Material-слайдера).
class _GlassSlider extends StatefulWidget {
  final double value; // 0..1
  final ValueChanged<double> onChanged;

  const _GlassSlider({required this.value, required this.onChanged});

  @override
  State<_GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<_GlassSlider> {
  bool _active = false;

  static const double _band = 22;
  static const double _thumbW = 29;
  static const double _thumbH = 18;
  static const double _grooveH = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final travel = (w - _thumbW).clamp(1.0, double.infinity);
        final v = widget.value.clamp(0.0, 1.0);
        final thumbLeft = v * travel;
        final fillW = thumbLeft + _thumbW / 2;
        final grooveTop = (_band - _grooveH) / 2;
        void handle(double dx) =>
            widget.onChanged(((dx - _thumbW / 2) / travel).clamp(0.0, 1.0));
        void press() {
          if (!_active) setState(() => _active = true);
        }

        void release() {
          if (_active) setState(() => _active = false);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            press();
            handle(d.localPosition.dx);
          },
          onTapUp: (_) => release(),
          onTapCancel: release,
          onHorizontalDragStart: (d) {
            press();
            handle(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => handle(d.localPosition.dx),
          onHorizontalDragEnd: (_) => release(),
          onHorizontalDragCancel: release,
          child: SizedBox(
            height: _band,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Жёлоб-трек: заливка cardAlt + наружная drop-тень + внутренняя
                // тёмная (утоплённость).
                Positioned(
                  left: 0,
                  right: 0,
                  top: grooveTop,
                  height: _grooveH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.cardAlt,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _EdgeShadowPainter(color: Color(0x40000000)),
                    ),
                  ),
                ),
                // Заливка: петроль + наружная drop-тень + внутренний белый хайлайт.
                Positioned(
                  left: 0,
                  top: grooveTop,
                  width: fillW,
                  height: _grooveH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF045157),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _EdgeShadowPainter(color: Color(0x40FFFFFF)),
                    ),
                  ),
                ),
                // Бегунок: frosted-стекло + олива α0.3, 29×18 r9. При захвате
                // «пульсирует» масштабом (овершут ×2 → оседает ×1.8, узел 203:692),
                // при отпускании возвращается к ×1.
                Positioned(
                  left: thumbLeft,
                  top: (_band - _thumbH) / 2,
                  width: _thumbW,
                  height: _thumbH,
                  child: AnimatedScale(
                    scale: _active ? 1.8 : 1.0,
                    duration: Duration(milliseconds: _active ? 300 : 170),
                    curve: _active ? const _ThumbPop() : Curves.easeOut,
                    // Раньше бегунок был frosted-стекло (BackdropFilter σ8) + олива
                    // α0.3. Живой блюр убран — вместо него сплошной приглушённый
                    // бирюзовый того же тона, чтобы вид не изменился.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.isDark
                            ? const Color(0xFF3E5A52)
                            : const Color(0xFF8FAAA3),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            offset: Offset(1, 2),
                            blurRadius: 4,
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
      },
    );
  }
}

/// Overshoot-кривая пульса бегунка: масштаб доходит до ×2 и оседает на ×1.8
/// (back-out, s≈3 → пик кривой ≈1.25 ⇒ scale = lerp(1, 1.8, 1.25) ≈ 2.0).
class _ThumbPop extends Curve {
  const _ThumbPop();

  @override
  double transformInternal(double t) {
    const s = 3.0;
    final u = t - 1.0;
    return u * u * ((s + 1) * u + s) + 1.0;
  }
}

/// Inset-тень/хайлайт у верхне-левой кромки скруглённого прямоугольника
/// (`inset 2 2 blur α`). Белым — «приподнятость», чёрным — «утоплённость».
/// Тот же приём dstOut, что у [EcoGlassChip]/[EcoInsetShadow].
class _EdgeShadowPainter extends CustomPainter {
  final Color color;
  const _EdgeShadowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = radiusFor(size);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(rr, Paint()..color = color);
    canvas.drawRRect(
      rr.shift(const Offset(2, 2)),
      Paint()
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.restore();
  }

  double radiusFor(Size size) {
    final half = size.shortestSide / 2;
    return half < 999 ? half : 999;
  }

  @override
  bool shouldRepaint(_EdgeShadowPainter old) => old.color != color;
}
