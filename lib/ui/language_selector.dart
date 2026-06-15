import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/store.dart';
import '../theme/tokens.dart';

class LanguageSelector extends StatelessWidget {
  final EcoTheme t;
  final bool compact;

  const LanguageSelector({super.key, required this.t, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = context.l10n;
    return PopupMenuButton<AppLanguage>(
      tooltip: l.t('common.language'),
      color: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (language) async {
        await FoodDb.instance.load(
          localeCode: language.productLocale,
          force: true,
        );
        if (context.mounted) {
          await context.read<AppStore>().setLanguage(language);
        }
      },
      itemBuilder: (_) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    language.shortName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.dark,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (language == store.language)
                  Icon(Icons.check, size: 18, color: t.dark),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: t.bandSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: compact ? 16 : 18, color: t.dark),
            SizedBox(width: compact ? 6 : 8),
            Text(
              compact ? store.language.shortName : store.language.nativeName,
              style: TextStyle(
                fontSize: compact ? 12 : 13.5,
                fontWeight: FontWeight.w700,
                color: t.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
