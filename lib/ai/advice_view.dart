import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Renders AI advice text as a bullet list: every non-empty line becomes a
/// bullet, list markers (`-`, `*`, `•`, `1.`) are stripped, and any text before
/// the first `:` is emphasised. Shared by the AI advice card and screen.
class AdviceBulletList extends StatelessWidget {
  final EcoTheme t;
  final String text;

  /// Appends a caret to the last item while the text is still "typing".
  final bool showCursor;

  const AdviceBulletList({
    super.key,
    required this.t,
    required this.text,
    this.showCursor = false,
  });

  // Регэкспы компилируются один раз, а не на каждом тике печати.
  static final RegExp _lineSplit = RegExp(r'\r?\n');
  static final RegExp _bulletPrefix = RegExp('^\\s*(?:[-*]|\\u2022)\\s*');
  static final RegExp _numberPrefix = RegExp(r'^\s*\d+[\).]\s*');

  @override
  Widget build(BuildContext context) {
    final items = text
        .split(_lineSplit)
        .map(_cleanItem)
        .where((item) => item.isNotEmpty)
        .toList();
    if (items.isEmpty && showCursor) {
      items.add('|');
    } else if (showCursor) {
      items[items.length - 1] = '${items.last}|';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 8, right: 9),
                decoration: BoxDecoration(
                  color: t.sub,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: _AdviceItemText(t, items[i])),
            ],
          ),
        ],
      ],
    );
  }

  static String _cleanItem(String value) {
    return value
        .replaceAll(_bulletPrefix, '')
        .replaceAll(_numberPrefix, '')
        .trim();
  }
}

class _AdviceItemText extends StatelessWidget {
  final EcoTheme t;
  final String value;

  const _AdviceItemText(this.t, this.value);

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.42,
      color: t.sub,
    );
    final separator = value.indexOf(':');
    if (separator <= 0) {
      return Text(value, overflow: TextOverflow.visible, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: value.substring(0, separator + 1),
            style: TextStyle(
              color: t.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: value.substring(separator + 1)),
        ],
      ),
      overflow: TextOverflow.visible,
    );
  }
}
