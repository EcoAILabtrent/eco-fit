import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import 'ui.dart';

class LanguageSelector extends StatelessWidget {
  final EcoTheme t;
  final bool compact;
  final double? width;
  final double? height;

  const LanguageSelector({
    super.key,
    required this.t,
    this.compact = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final anchorKey = GlobalKey();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final language = await showEcoChoicePopup<AppLanguage>(
          context: context,
          t: t,
          anchorKey: anchorKey,
          selected: store.language,
          options: [
            for (final language in AppLanguage.values)
              EcoChoiceOption(
                value: language,
                prefix: language.shortName,
                label: language.nativeName,
              ),
          ],
        );
        if (language == null || language == store.language) return;
        await FoodDb.instance.load(
          localeCode: language.productLocale,
          force: true,
        );
        if (context.mounted) {
          await context.read<AppStore>().setLanguage(language);
        }
      },
      child: Container(
        key: anchorKey,
        width: width,
        height: height,
        alignment: (width != null || height != null) ? Alignment.center : null,
        padding: (width != null || height != null)
            ? null
            : EdgeInsets.symmetric(
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
            Icon(Icons.language, size: compact ? 16 : 18, color: t.ink),
            SizedBox(width: compact ? 6 : 8),
            Text(
              store.language.shortName,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
