import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_strings.dart';
import '../notifications/notification_service.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
          top: 24,
          bottom: 150 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 18, top: 4),
              child: Text(
                l.t('profile.profile'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),

            // Identity — avatar straddling the card top, name centred,
            // read-only body params below.
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 80, bottom: 12),
                  child: EcoCard(
                    t: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 88),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: t.bandSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              profileName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
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
                      size: 160,
                      onTap: _pickAvatar,
                    ),
                  ),
                ),
                Positioned(
                  top: 92,
                  right: 14,
                  child: GestureDetector(
                    onTap: _editProfile,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.bandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_outlined, size: 19, color: t.ink),
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
                  EcoCardHead(
                    t: t,
                    icon: 'settings',
                    title: l.t('common.settings'),
                    mb: 4,
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
                  // Мастер-тумблер уведомлений (настоящий: персистится в
                  // сторе, планировщик перепланирует расписание). Тап по
                  // строке открывает детальные настройки категорий.
                  _row(
                    t,
                    l.t('common.notifications'),
                    '',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                    control: _Toggle(
                      on: s.notifEnabled,
                      onChanged: (v) {
                        context.read<AppStore>().setNotifPrefs(enabled: v);
                        if (v) {
                          NotificationService.instance.requestPermission();
                        }
                      },
                    ),
                  ),
                  _row(
                    t,
                    l.t('common.darkTheme'),
                    '',
                    control: _Toggle(
                      on: s.darkMode,
                      onChanged: (v) =>
                          context.read<AppStore>().setDarkMode(v),
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
                      return Container(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: t.bandSoft, width: 1.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.t('common.cardTransparency'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(((0.95 - cardOpacity) / (0.95 - 0.08)) * 100).round()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.ink.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: t.olive,
                            // Полоса обрывается на бегунке — справа от него трека
                            // нет (inactive прозрачный).
                            inactiveTrackColor: Colors.transparent,
                            trackShape: const RoundedRectSliderTrackShape(),
                            thumbShape: _GlassSliderThumb(accent: t.olive),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 20,
                            ),
                            overlayColor: t.olive.withValues(alpha: 0.12),
                          ),
                          child: Slider(
                            value: ((0.95 - cardOpacity) / (0.95 - 0.08))
                                .clamp(0.0, 1.0),
                            onChanged: (v) => context
                                .read<AppStore>()
                                .setCardOpacity(0.95 - v * (0.95 - 0.08)),
                          ),
                        ),
                      ],
                    ),
                      );
                    },
                  ),
                  _row(t, l.t('common.privacy'), '', onTap: () {}, last: true),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: EcoBtn(
                t: t,
                bg: t.bandSoft,
                fg: t.ink,
                // Сброс данных — стирает профиль и весь прогресс, после чего
                // приложение ведёт в онбординг, как при первом запуске.
                onTap: _confirmResetData,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(l.t('common.resetData')),
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
    context.read<AppStore>().setAvatarPath(picked.path);
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
                    scrollController: FixedExtentScrollController(
                      initialItem: (value - min).clamp(0, max - min).toInt(),
                    ),
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
  }

  void _save() {
    final store = context.read<AppStore>();
    final savedWeight = store.weightKg ??
        (store.weight > 0 ? store.weight : _weight.toDouble());
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
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 116 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 28,
                            height: 34,
                            child: Icon(
                              Icons.chevron_left,
                              size: 30,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.t('profile.editTitle'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Big avatar straddling the name card top — tap → gallery.
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 80, bottom: 12),
                          child: EcoGlassSurface(
                            t: t,
                            padding: const EdgeInsets.fromLTRB(18, 96, 18, 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: t.bandSoft,
                                  borderRadius: BorderRadius.circular(999),
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
                                      keyboardType: TextInputType.name,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: t.ink,
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
                              size: 160,
                              onTap: () => _pickAvatar(ImageSource.gallery),
                            ),
                          ),
                        ),
                      ],
                    ),
                    EcoGlassSurface(
                      t: t,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditCardHeader(
                            icon: Icons.accessibility_new,
                            title: l.t('home.bodyParams'),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  key: _genderRowKey,
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _pickGender,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.bandSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _gender == 'm'
                                          ? l.t('profile.male')
                                          : l.t('profile.female'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: t.ink,
                                      ),
                                    ),
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
                              onSave: (v) => setState(() => _height = v),
                            ),
                          ),
                          _ProfileEditRow(
                            label: l.t('profile.weight'),
                            value: '${_formatWeight(l)} ${l.unit('kg')}',
                            last: true,
                            onTap: () async {
                              await Navigator.of(context)
                                  .pushNamed('/bodyEntry');
                              if (!context.mounted) return;
                              final store = context.read<AppStore>();
                              setState(() {
                                _weight = (store.weightKg ??
                                        (store.weight > 0 ? store.weight : 66))
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
                          icon: Icons.accessibility_new_rounded,
                          label: '1',
                          title: l.t('onboarding.activityLow'),
                          sub: l.t('onboarding.activityLowSub'),
                        ),
                        _ChoiceValue(
                          key: 'mid',
                          icon: Icons.directions_walk_rounded,
                          label: '2',
                          title: l.t('onboarding.activityMid'),
                          sub: l.t('onboarding.activityMidSub'),
                        ),
                        _ChoiceValue(
                          key: 'high',
                          icon: Icons.fitness_center_rounded,
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
                          icon: Icons.trending_down_rounded,
                          label: '1',
                          title: l.t('onboarding.goalLose'),
                          sub: '',
                        ),
                        _ChoiceValue(
                          key: 'keep',
                          icon: Icons.balance_rounded,
                          label: '2',
                          title: l.t('onboarding.goalKeep'),
                          sub: '',
                        ),
                        _ChoiceValue(
                          key: 'gain',
                          icon: Icons.trending_up_rounded,
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 18 + bottomInset,
              child: Row(
                children: [
                  Expanded(
                    child: EcoBtn(
                      t: t,
                      bg: t.pill,
                      fg: t.ink,
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(l.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EcoBtn(
                      t: t,
                      onTap: _save,
                      child: Text(l.t('common.save')),
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
  final IconData icon;
  final String title;

  const _EditCardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return Row(
      children: [
        EcoIconBadge(t: t, iconData: icon),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final hasImage =
        path != null && path!.isNotEmpty && File(path!).existsSync();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.dark,
          shape: BoxShape.circle,
          border: Border.all(color: t.bg, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: hasImage
              ? DecorationImage(
                  image: FileImage(File(path!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasImage
            ? null
            : Icon(Icons.person, size: size * 0.46, color: t.onDark),
      ),
    );
  }
}

class _ChoiceValue {
  final String key;
  final IconData icon;
  final String label;
  final String title;
  final String sub;

  const _ChoiceValue({
    required this.key,
    required this.icon,
    required this.label,
    required this.title,
    required this.sub,
  });
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
                    child: Column(
                      children: [
                        item.key == selected
                            ? Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: t.olive,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 22,
                                  color: t.onDark,
                                ),
                              )
                            : EcoIconBadge(
                                t: t,
                                iconData: item.icon,
                                size: 46,
                                icon: 22,
                              ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                height: 1.25,
                color: t.sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 58,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? t.dark : t.bandSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Бегунок слайдера в стиле «liquid glass»: матовое стекло с радиальным
/// градиентом + светящиеся канты и верхний specular-блик. Без BackdropFilter —
/// эффект рисуется на канве (без размытия фона), чтобы не нагружать растеризацию.
class _GlassSliderThumb extends SliderComponentShape {
  static const double radius = 13;
  final Color accent;
  const _GlassSliderThumb({required this.accent});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final r = radius;
    final rect = Rect.fromCircle(center: center, radius: r);

    // Мягкая тень под бегунком.
    canvas.drawCircle(
      center.translate(0, 1.6),
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Матовое стекло: светлее сверху-слева, к низу — лёгкий оттенок акцента.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [
            const Color(0xF7FFFFFF),
            const Color(0xCCFFFFFF),
            accent.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Канты (liquid-glass блики) — внутри круга.
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawPath(
      Path()..addOval(rect.deflate(0.7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xC8FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
    );
    canvas.drawPath(
      (Path()..addOval(rect.deflate(0.5))).shift(const Offset(0.7, 0.8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x55FFFFFF),
    );
    canvas.restore();

    // Чёткая внешняя обводка.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x26000000),
    );

    // Верхний specular-блик.
    canvas.drawCircle(
      center.translate(-r * 0.32, -r * 0.42),
      r * 0.26,
      Paint()
        ..color = const Color(0xF0FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
  }
}
