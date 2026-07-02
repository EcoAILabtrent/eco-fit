import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/products.dart';
import '../l10n/app_language.dart';
import '../state/store.dart';
import '../theme/tokens.dart';
import 'ui.dart';

class LanguageSelector extends StatefulWidget {
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
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  // Якорь поповера держим ПОЛЕМ, а не создаём в build: новый GlobalKey на каждый
  // rebuild ремоунтит поддерево (теряет состояние, лишняя работа) и рвёт привязку
  // всплывающего меню к кнопке.
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final compact = widget.compact;
    final width = widget.width;
    final height = widget.height;
    // select только по языку: раньше здесь был watch<AppStore>(), из-за чего
    // кнопка перестраивалась на любой notify стора (тики шагомера/воды и т.п.).
    final language = context.select<AppStore, AppLanguage>((s) => s.language);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final store = context.read<AppStore>();
        final selected = await showEcoChoicePopup<AppLanguage>(
          context: context,
          t: t,
          anchorKey: _anchorKey,
          selected: store.language,
          options: [
            for (final option in AppLanguage.values)
              EcoChoiceOption(
                value: option,
                prefix: option.shortName,
                label: option.nativeName,
              ),
          ],
        );
        if (selected == null || selected == store.language) return;
        await FoodDb.instance.load(
          localeCode: selected.productLocale,
          force: true,
        );
        if (context.mounted) {
          await context.read<AppStore>().setLanguage(selected);
        }
      },
      child: Container(
        key: _anchorKey,
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
              language.shortName,
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
