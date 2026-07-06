import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../notifications/notification_service.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Открывает прокручиваемый лист с полным текстом политики конфиденциальности.
/// Используется и на экране согласия, и из настроек профиля, чтобы политика была
/// доступна в приложении в любой момент (требование магазинов).
void showPrivacyPolicySheet(BuildContext context, EcoTheme t, AppStrings l) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PolicySheet(t: t, l: l),
  );
}

/// Экран согласия и разрешений — показывается один раз после онбординга
/// (после ввода всех данных профиля) и до входа на главный экран. Собирает в
/// одном месте:
///   • согласие на обработку данных для ИИ-советов (Firebase + DeepSeek);
///   • разрешение на уведомления (POST_NOTIFICATIONS);
///   • разрешение на распознавание активности/шаги (ACTIVITY_RECOGNITION).
///
/// Кнопка «Принять и продолжить» последовательно запрашивает системные
/// разрешения (по одному диалогу за раз), фиксирует согласие в сторе
/// (`consentAccepted`) и уводит на главный экран. Пока согласие не принято,
/// планировщик уведомлений и вход в приложение заблокированы (см. main.dart и
/// NotificationService).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _processing = false;

  Future<void> _accept() async {
    if (_processing) return;
    setState(() => _processing = true);
    final store = context.read<AppStore>();
    final navigator = Navigator.of(context);

    // Системные диалоги показываем по очереди (await между ними) — два
    // одновременных промпта Android схлопнул бы. Отказ в любом из них не мешает
    // войти: разрешения опциональны, гейтом служит только согласие ИИ/политики.
    try {
      await NotificationService.instance.requestPermission();
    } catch (_) {
      // На платформах без плагина/на вебе запрос недоступен — не критично.
    }
    if (!mounted) return;
    try {
      await store.enableSteps();
    } catch (_) {
      // Нет нативного шагомера (desktop/web) — тоже не критично.
    }

    store.setConsentAccepted(true);
    if (!mounted) return;
    navigator.pushReplacementNamed('/');
  }

  void _showPolicy(EcoTheme t, AppStrings l) =>
      showPrivacyPolicySheet(context, t, l);

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
            Positioned.fill(child: EcoGlassBackground(t: t)),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EcoTopBar(t: t, title: l.t('consent.title')),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.t('consent.intro'),
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: t.sub,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _InfoCard(
                                t: t,
                                icon: 'ai',
                                title: l.t('consent.aiTitle'),
                                body: l.t('consent.aiBody'),
                              ),
                              const SizedBox(height: 12),
                              _InfoCard(
                                t: t,
                                iconData: Icons.notifications_none_rounded,
                                title: l.t('consent.notifTitle'),
                                body: l.t('consent.notifBody'),
                              ),
                              const SizedBox(height: 12),
                              _InfoCard(
                                t: t,
                                icon: 'walk',
                                title: l.t('consent.stepsTitle'),
                                body: l.t('consent.stepsBody'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.t('consent.note'),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: t.sub,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showPolicy(t, l),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 18,
                                        color: t.olive,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          l.t('consent.readPolicy'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: t.olive,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: t.olive,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: bottomInset + 20,
                          top: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.t('consent.agree'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: t.sub,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: EcoBtn(
                                t: t,
                                disabled: _processing,
                                onTap: _accept,
                                child: Text(
                                  _processing
                                      ? l.t('consent.processing')
                                      : l.t('consent.accept'),
                                ),
                              ),
                            ),
                          ],
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
}

/// Карточка одной темы согласия: круглый бейдж с иконкой + заголовок + текст.
class _InfoCard extends StatelessWidget {
  final EcoTheme t;
  final String? icon;
  final IconData? iconData;
  final String title;
  final String body;

  const _InfoCard({
    required this.t,
    this.icon,
    this.iconData,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      t: t,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcoIconBadge(t: t, name: icon, iconData: iconData),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, height: 1.4, color: t.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Прокручиваемый лист с полным текстом политики конфиденциальности.
class _PolicySheet extends StatelessWidget {
  final EcoTheme t;
  final AppStrings l;

  const _PolicySheet({required this.t, required this.l});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: t.bandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.t('consent.policyTitle'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 24, color: t.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.t('consent.policyUpdated'),
              style: TextStyle(fontSize: 12, color: t.sub),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Text(
                    l.t('consent.policyBody'),
                    style: TextStyle(fontSize: 14, height: 1.55, color: t.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
