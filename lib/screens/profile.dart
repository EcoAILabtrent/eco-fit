import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';
import 'home.dart' show showMealPicker;

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
  bool metric = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final goalLabel = switch (s.goal) {
      'lose' => 'Снижение веса',
      'gain' => 'Набор массы',
      'keep' => 'Удержание веса',
      _ => 'Цель не выбрана',
    };

    return EcoScreen(
      t: t,
      footer: EcoBottomNav(
        t: t,
        active: 'profile',
        onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onProfile: () {},
        onPlus: () => showMealPicker(context),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 24, bottom: 150 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 18, top: 4),
              child: Text('Профиль', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),

            // Identity
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
                  child: Icon(Icons.person, size: 34, color: t.pill),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Мой профиль', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      s.age != null ? '$goalLabel · ${s.age} лет' : goalLabel,
                      style: const TextStyle(fontSize: 13.5, color: EcoColors.sub),
                    ),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/onboarding'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: t.bandSoft, shape: BoxShape.circle),
                    child: Icon(Icons.edit_outlined, size: 19, color: t.dark),
                  ),
                ),
              ]),
            ),

            // Goal summary
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                _goalCard('pulse', '${s.goalKcal}', 'ккал/день'),
                const SizedBox(width: 12),
                _goalCard('water', '${s.waterGoal / 1000} л', 'вода'),
                const SizedBox(width: 12),
                _goalCard('steps', '${s.stepsGoal ~/ 1000}k', 'шаги'),
              ]),
            ),

            // Body params
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                EcoCardHead(
                  t: t,
                  icon: 'gauge',
                  title: 'Параметры тела',
                  mb: 4,
                  right: GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/onboarding'),
                    child: Text('Изменить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.dark)),
                  ),
                ),
                _row('Вес', s.weight > 0 ? '${s.weight} кг' : '—'),
                _row('Рост', s.heightCm != null ? '${s.heightCm} см' : '—'),
                _row('Возраст', s.age != null ? '${s.age} лет' : '—'),
                _row('Пол', switch (s.gender) { 'm' => 'Мужской', 'f' => 'Женский', _ => '—' }, last: true),
              ]),
            ),

            // Settings
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const EcoCardHead(t: t, icon: 'gauge', title: 'Настройки', mb: 4),
                _row('Уведомления', '', control: _Toggle(on: notif, onChanged: (v) => setState(() => notif = v))),
                _row('Метрическая система', '', control: _Toggle(on: metric, onChanged: (v) => setState(() => metric = v))),
                _row('Подключённые устройства', '1', onTap: () {}),
                _row('Конфиденциальность', '', onTap: () {}, last: true),
              ]),
            ),

            SizedBox(
              width: double.infinity,
              child: EcoBtn(
                t: t,
                bg: t.bandSoft,
                fg: t.dark,
                onTap: () => Navigator.of(context).pushNamed('/onboarding'),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text('Выйти'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(String icon, String value, String label) {
    return Expanded(
      child: EcoCard(
        t: t,
        pad: 16,
        child: Column(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
            child: Icon(ecoIcon(icon), size: 19, color: t.pill),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: EcoColors.sub)),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {Widget? control, VoidCallback? onTap, bool last = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
          if (control != null)
            control
          else ...[
            Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: EcoColors.sub)),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: EcoColors.faint),
          ],
        ]),
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
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: on ? t.dark : t.bandSoft, borderRadius: BorderRadius.circular(999)),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
