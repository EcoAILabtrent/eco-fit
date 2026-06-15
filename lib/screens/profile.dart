import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/language_selector.dart';
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
    final l = context.l10n;
    final goalLabel = switch (s.goal) {
      'lose' => l.t('profile.goalLose'),
      'gain' => l.t('profile.goalGain'),
      'keep' => l.t('profile.goalKeep'),
      _ => l.t('profile.goalNotSelected'),
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
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Identity
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: t.dark,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 34, color: t.pill),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('profile.myProfile'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.age != null
                              ? '$goalLabel · ${l.ageValue(s.age!)}'
                              : goalLabel,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: EcoColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/onboarding'),
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
                ],
              ),
            ),

            // Goal summary
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _goalCard('pulse', '${s.goalKcal}', l.unit('kcalPerDay')),
                  const SizedBox(width: 12),
                  _goalCard(
                    'water',
                    '${s.waterGoal / 1000} ${l.unit('l')}',
                    l.t('home.water').toLowerCase(),
                  ),
                  const SizedBox(width: 12),
                  _goalCard(
                    'steps',
                    '${s.stepsGoal ~/ 1000}k',
                    l.t('home.steps').toLowerCase(),
                  ),
                ],
              ),
            ),

            // Body params
            EcoCard(
              t: t,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EcoCardHead(
                    t: t,
                    icon: 'gauge',
                    title: l.t('home.bodyParams'),
                    mb: 4,
                    right: GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pushNamed('/onboarding'),
                      child: Text(
                        l.t('common.edit'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.dark,
                        ),
                      ),
                    ),
                  ),
                  _row(
                    l.t('profile.weight'),
                    s.weight > 0 ? '${s.weight} ${l.unit('kg')}' : '—',
                  ),
                  _row(
                    l.t('profile.height'),
                    s.heightCm != null ? '${s.heightCm} ${l.unit('cm')}' : '—',
                  ),
                  _row(
                    l.t('profile.age'),
                    s.age != null ? l.ageValue(s.age!) : '—',
                  ),
                  _row(l.t('profile.sex'), switch (s.gender) {
                    'm' => l.t('profile.male'),
                    'f' => l.t('profile.female'),
                    _ => '—',
                  }, last: true),
                ],
              ),
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
                    icon: 'gauge',
                    title: l.t('common.settings'),
                    mb: 4,
                  ),
                  _row(
                    l.t('common.language'),
                    '',
                    control: const LanguageSelector(t: t),
                  ),
                  _row(
                    l.t('common.notifications'),
                    '',
                    control: _Toggle(
                      on: notif,
                      onChanged: (v) => setState(() => notif = v),
                    ),
                  ),
                  _row(
                    l.t('common.metricSystem'),
                    '',
                    control: _Toggle(
                      on: metric,
                      onChanged: (v) => setState(() => metric = v),
                    ),
                  ),
                  _row(l.t('common.connectedDevices'), '1', onTap: () {}),
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

  Widget _goalCard(String icon, String value, String label) {
    return Expanded(
      child: EcoCard(
        t: t,
        pad: 16,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: t.dark, shape: BoxShape.circle),
              child: Icon(ecoIcon(icon), size: 19, color: t.pill),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: EcoColors.sub),
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
                  fontSize: 15.5,
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
                  fontSize: 15.5,
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
        decoration: BoxDecoration(
          color: on ? t.dark : t.bandSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
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
