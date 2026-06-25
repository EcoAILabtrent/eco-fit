import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/language_selector.dart';
import '../ui/ui.dart';
import 'home.dart' show HomeScreen, showMealPicker;

/// Профиль — port of profile.jsx::Profile. Identity + goals + body params +
/// settings, fed by the real onboarding data from the store.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const t = EcoTheme.meadow;
  bool notif = true;

  void _editProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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

  // Read-only label/value row (same look as the editor, without the chevron).
  Widget _paramRow(String label, String value, {bool last = false}) {
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
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final profileName = s.profileName ?? l.t('profile.myProfile');

    return EcoScreen(
      t: t,
      footer: EcoBottomNav(
        t: t,
        active: 'profile',
        onHome: () => Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder<void>(
            settings: const RouteSettings(name: '/'),
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (_) => false,
        ),
        onProfile: () {},
        onPlus: () => showMealPicker(context, active: 'profile'),
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
                          l.t('profile.sex'),
                          s.gender == 'f'
                              ? l.t('profile.female')
                              : s.gender == 'm'
                                  ? l.t('profile.male')
                                  : '—',
                        ),
                        _paramRow(
                          l.t('profile.age'),
                          s.birthDate != null
                              ? l.birthValue(s.birthDate!)
                              : '—',
                        ),
                        _paramRow(
                          l.t('profile.height'),
                          s.heightCm != null
                              ? '${s.heightCm} ${l.unit('cm')}'
                              : '—',
                        ),
                        _paramRow(
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
                      child: Icon(Icons.edit_outlined, size: 19, color: t.dark),
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
                    l.t('common.language'),
                    '',
                    control: const LanguageSelector(
                      t: t,
                      compact: true,
                      width: 58,
                      height: 32,
                    ),
                  ),
                  _row(
                    l.t('common.notifications'),
                    '',
                    control: _Toggle(
                      on: notif,
                      onChanged: (v) => setState(() => notif = v),
                    ),
                  ),
                  _row(l.t('common.privacy'), '', onTap: () {}, last: true),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: EcoBtn(
                t: t,
                bg: t.bandSoft,
                fg: t.dark,
                onTap: () => Navigator.of(context).pushNamed('/onboarding'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text(l.t('common.logout')),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.sub,
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: EcoColors.faint,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileEditScreen extends StatefulWidget {
  static const t = EcoTheme.meadow;

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

  int get _norm {
    final age = AppStore.ageFromBirth(_birthDate);
    final bmr =
        (10 * _weight + 6.25 * _height - 5 * age + (_gender == 'm' ? 5 : -161))
            .round();
    final activityFactor = switch (_activity) {
      'low' => 1.2,
      'high' => 1.7,
      _ => 1.45,
    };
    final tdee = (bmr * activityFactor).round();
    return _goal == 'lose'
        ? tdee - 400
        : _goal == 'gain'
            ? tdee + 350
            : tdee;
  }

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
    var draft = _birthDate;
    return showEcoSheet(
      context: context,
      t: _ProfileEditScreen.t,
      title: context.l10nRead.t('profile.age'),
      doneLabel: context.l10nRead.t('common.save'),
      onDone: () => setState(() => _birthDate = draft),
      body: SizedBox(
        height: 200,
        child: EcoDatePicker(
          t: _ProfileEditScreen.t,
          initialDate: _birthDate,
          minYear: DateTime.now().year - 100,
          maxYear: DateTime.now().year - 12,
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
    final next = await showEcoChoicePopup<String>(
      context: context,
      t: _ProfileEditScreen.t,
      anchorKey: _genderRowKey,
      width: 176,
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
    var draft = value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x4714180C),
      builder: (sheetCtx) => EcoGlassSurface(
        t: _ProfileEditScreen.t,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
        bg: _ProfileEditScreen.t.band,
        blur: 18,
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
                    color: _ProfileEditScreen.t.dark,
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
                    selectionOverlay: const EcoPickerSelectionOverlay(
                      t: _ProfileEditScreen.t,
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
                        t: _ProfileEditScreen.t,
                        height: 46,
                        fontSize: 16,
                        bg: _ProfileEditScreen.t.pill,
                        fg: _ProfileEditScreen.t.dark,
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        child: Text(context.l10nRead.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EcoBtn(
                        t: _ProfileEditScreen.t,
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
    final l = context.l10n;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _ProfileEditScreen.t.bg,
      body: BackdropGroup(
        child: Stack(
          children: [
            const Positioned.fill(
              child: EcoGlassBackground(t: _ProfileEditScreen.t),
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
                          child: const SizedBox(
                            width: 28,
                            height: 34,
                            child: Icon(
                              Icons.chevron_left,
                              size: 30,
                              color: EcoColors.ink,
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
                            t: _ProfileEditScreen.t,
                            padding: const EdgeInsets.fromLTRB(18, 96, 18, 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _ProfileEditScreen.t.bandSoft,
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
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: EcoColors.ink,
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
                      t: _ProfileEditScreen.t,
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
                                  color: _ProfileEditScreen.t.bandSoft,
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
                                      color: _ProfileEditScreen.t.bandSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _gender == 'm'
                                          ? l.t('profile.male')
                                          : l.t('profile.female'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _ProfileEditScreen.t.dark,
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
                      t: _ProfileEditScreen.t,
                      bg: _ProfileEditScreen.t.pill,
                      fg: _ProfileEditScreen.t.dark,
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(l.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EcoBtn(
                      t: _ProfileEditScreen.t,
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
  static const t = EcoTheme.meadow;
  final IconData icon;
  final String title;

  const _EditCardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EcoIconBadge(t: t, iconData: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: EcoColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  static const t = EcoTheme.meadow;
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
          const Icon(Icons.chevron_right, size: 17, color: EcoColors.faint),
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
  static const t = EcoTheme.meadow;
  final String? path;
  final double size;
  final VoidCallback? onTap;

  const _ProfileAvatar({this.path, this.size = 80, this.onTap});

  @override
  Widget build(BuildContext context) {
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
            : Icon(Icons.person, size: size * 0.46, color: t.pill),
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
  static const t = EcoTheme.meadow;
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EcoColors.ink,
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
                                  color: t.pill,
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: EcoColors.sub,
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
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                color: EcoColors.sub,
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
  static const t = EcoTheme.meadow;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
