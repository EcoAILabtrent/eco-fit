import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import '../ui/ui.dart';

/// Компактная карточка-вход на главной. Тап открывает страницу ИИ-совета
/// (`/aiAdvice`), где можно получить совет, увидеть разбор микронутриентов и
/// посмотреть сохранённые советы. Вся генерация вынесена на ту страницу.
class AiAdviceCard extends StatelessWidget {
  final EcoTheme t;

  const AiAdviceCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // ИИ отключён тумблером согласия — карточку-вход не показываем вовсе.
    final aiConsent = context.select<AppStore, bool>((s) => s.aiConsent);
    if (!aiConsent) return const SizedBox.shrink();

    return EcoCard(
      t: t,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.of(context).pushNamed('/aiAdvice'),
      child: Row(
        children: [
          const _AiBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('ai.pageTitle'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.t('ai.cardSubtitle'),
                  style: TextStyle(fontSize: 13, height: 1.3, color: t.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    // Логотип «AI» (зелёные буквы с листьями) с прозрачным фоном, БЕЗ рамки.
    return RepaintBoundary(
      child: Image.asset(
        'assets/branding/ai_badge.png',
        width: 50,
        height: 50,
        fit: BoxFit.contain,
        cacheWidth: 256,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) =>
            const SizedBox(width: 50, height: 50),
      ),
    );
  }
}
