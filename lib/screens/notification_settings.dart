import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../notifications/notification_service.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Настройки уведомлений — открываются колокольчиком в правом верхнем углу
/// главного экрана (и мастер-тумблером в профиле). Мастер-переключатель +
/// отдельные категории: еда, вода, итог дня, шаги, взвешивание. Все флаги
/// живут в AppStore (Hive), планировщик перепланирует расписание сам.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final s = context.watch<AppStore>();
    final l = context.l10n;
    final enabled = s.notifEnabled;

    return Scaffold(
      backgroundColor: t.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EcoTopBar(
              t: t,
              title: l.t('common.notifications'),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    // Мастер-тумблер
                    EcoCard(
                      t: t,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.t('notif.settings.master'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _Toggle(
                                on: enabled,
                                onChanged: (v) async {
                                  final store = context.read<AppStore>();
                                  store.setNotifPrefs(enabled: v);
                                  if (!v) return;
                                  // Явное включение — уместный момент для
                                  // системного диалога разрешения (13+). Ждём
                                  // результат: при отказе возвращаем тумблер в
                                  // «выкл» и подсказываем разрешить уведомления —
                                  // иначе он остался бы «вкл», а уведомления
                                  // всё равно не приходили бы.
                                  final granted = await NotificationService
                                      .instance
                                      .requestPermission();
                                  if (granted || !context.mounted) return;
                                  store.setNotifPrefs(enabled: false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(l.t('notif.settings.master')),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.t('notif.settings.masterDesc'),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: t.sub,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Категории — гаснут при выключенном мастере.
                    IgnorePointer(
                      ignoring: !enabled,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: enabled ? 1 : 0.45,
                        child: EcoCard(
                          t: t,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _categoryRow(
                                t,
                                label: l.t('notif.settings.meals'),
                                desc: l.t('notif.settings.mealsDesc'),
                                on: s.notifMeals,
                                onChanged: (v) => context
                                    .read<AppStore>()
                                    .setNotifPrefs(meals: v),
                              ),
                              _categoryRow(
                                t,
                                label: l.t('notif.settings.water'),
                                desc: l.t('notif.settings.waterDesc'),
                                on: s.notifWater,
                                onChanged: (v) => context
                                    .read<AppStore>()
                                    .setNotifPrefs(water: v),
                              ),
                              _categoryRow(
                                t,
                                label: l.t('notif.settings.summary'),
                                desc: l.t('notif.settings.summaryDesc'),
                                on: s.notifSummary,
                                onChanged: (v) => context
                                    .read<AppStore>()
                                    .setNotifPrefs(summary: v),
                              ),
                              _categoryRow(
                                t,
                                label: l.t('notif.settings.steps'),
                                desc: l.t('notif.settings.stepsDesc'),
                                on: s.notifSteps,
                                onChanged: (v) => context
                                    .read<AppStore>()
                                    .setNotifPrefs(steps: v),
                              ),
                              _categoryRow(
                                t,
                                label: l.t('notif.settings.weight'),
                                desc: l.t('notif.settings.weightDesc'),
                                on: s.notifWeight,
                                onChanged: (v) => context
                                    .read<AppStore>()
                                    .setNotifPrefs(weight: v),
                                last: true,
                              ),
                            ],
                          ),
                        ),
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

  Widget _categoryRow(
    EcoTheme t, {
    required String label,
    required String desc,
    required bool on,
    required ValueChanged<bool> onChanged,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: t.bandSoft, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: t.sub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Toggle(on: on, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Тумблер в стиле настроек профиля (копия приватного _Toggle из profile.dart).
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
