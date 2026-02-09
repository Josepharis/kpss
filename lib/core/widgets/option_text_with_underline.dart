import 'package:flutter/material.dart';

/// Seçenek metnini gösterir; [underlinedWord] verilirse metin içinde bu kelime altı çizili çizilir.
/// Alternatif: Metin içinde __kelime__ varsa, çift alt çizgi kaldırılıp sadece "kelime" altı çizili gösterilir.
class OptionTextWithUnderline extends StatelessWidget {
  const OptionTextWithUnderline({
    super.key,
    required this.text,
    this.underlinedWord,
    required this.style,
  });

  final String text;
  final String? underlinedWord;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if ((underlinedWord == null || underlinedWord!.isEmpty) && !text.contains('__')) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];

    if (underlinedWord != null && underlinedWord!.isNotEmpty) {
      final idx = text.indexOf(underlinedWord!);
      if (idx >= 0) {
        if (idx > 0) {
          spans.add(TextSpan(text: text.substring(0, idx), style: style));
        }
        spans.add(TextSpan(
          text: underlinedWord!,
          style: style.copyWith(decoration: TextDecoration.underline),
        ));
        final end = idx + underlinedWord!.length;
        if (end < text.length) {
          spans.add(TextSpan(text: text.substring(end), style: style));
        }
      } else {
        spans.add(TextSpan(text: text, style: style));
      }
    } else {
      // __kelime__ formatını parse et
      spans.addAll(_parseDoubleUnderscore(text, style));
    }

    if (spans.isEmpty) {
      return Text(text, style: style);
    }
    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }

  static List<TextSpan> _parseDoubleUnderscore(String text, TextStyle style) {
    final result = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final start = text.indexOf('__', i);
      if (start == -1) {
        result.add(TextSpan(text: text.substring(i), style: style));
        break;
      }
      if (start > i) {
        result.add(TextSpan(text: text.substring(i, start), style: style));
      }
      final end = text.indexOf('__', start + 2);
      if (end == -1) {
        result.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      final word = text.substring(start + 2, end);
      result.add(TextSpan(
        text: word,
        style: style.copyWith(decoration: TextDecoration.underline),
      ));
      i = end + 2;
    }
    return result;
  }
}
