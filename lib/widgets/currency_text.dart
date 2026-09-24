import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Keeps descriptive copy in the app font and styles only embedded amounts.
class CurrencyText extends StatelessWidget {
  const CurrencyText(this.data,
      {super.key,
      this.style,
      this.textAlign,
      this.maxLines,
      this.overflow,
      this.softWrap,
      this.textScaler});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextScaler? textScaler;

  static final _amount =
      RegExp(r'[+−-]?(?:[0-9][0-9.,\s]*[KMBTkmbt]?|[•●]+)\s*[₫đ]');

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final money = currencyTextStyle(context, base);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _amount.allMatches(data)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: data.substring(offset, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: money));
      offset = match.end;
    }
    if (offset < data.length) spans.add(TextSpan(text: data.substring(offset)));
    return Text.rich(TextSpan(children: spans),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textScaler: textScaler);
  }
}
