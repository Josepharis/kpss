import 'package:flutter/material.dart';

/// Seçenek metnini gösterir; [underlinedWord] verilirse metin içinde bu kelime altı çizili çizilir.
/// Hem [underlinedWord] hem de metin içindeki __kelime__ formatını destekler.
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
    if (text.isEmpty) return const SizedBox.shrink();

    // Eğer ne underlinedWord var ne de __ ibaresi, direkt Text döndür
    if ((underlinedWord == null || underlinedWord!.trim().isEmpty) &&
        !text.contains('__') &&
        !text.contains('<u>')) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    String workingText = text;

    // Önce underlinedWord ile eşleşen kısmı işaretle (eğer varsa)
    // Bunu __word__ formatına çevirip sonra tek bir parser ile geçebiliriz
    if (underlinedWord != null && underlinedWord!.trim().isNotEmpty) {
      final String word = underlinedWord!.trim();
      // Case-insensitive match için regex kullanıyoruz
      final regex = RegExp(RegExp.escape(word), caseSensitive: false);
      final match = regex.firstMatch(workingText);

      if (match != null) {
        final start = match.start;
        final end = match.end;
        final matchedText = workingText.substring(start, end);
        workingText = workingText.replaceRange(
          start,
          end,
          '__${matchedText}__',
        );
      }
    }

    // KPSS Heuristic: 'word' in quotes usually means it should be underlined
    workingText = workingText.replaceAllMapped(
      RegExp(r"(^|\s|[(\[{])'([^']{2,})'(?=\s|[,.!?;:\])}]|$)"),
      (match) => "${match.group(1)}<u>${match.group(2)}</u>",
    );

    workingText = workingText.replaceAllMapped(
      RegExp(r'(^|\s|[(\[{])"([^"]{2,})"(?=\s|[,.!?;:\])}]|$)'),
      (match) => "${match.group(1)}<u>${match.group(2)}</u>",
    );

    // Şimdi __word__, **word** ve <u>word</u> formatlarını parse et
    int i = 0;
    while (i < workingText.length) {
      final nextUnderline = workingText.indexOf('__', i);
      final nextU = workingText.indexOf('<u>', i);
      final nextBold = workingText.indexOf('**', i);

      int nextTag = -1;
      String tagType = '';

      // En yakın tag'i bul
      if (nextUnderline != -1) {
        nextTag = nextUnderline;
        tagType = '__';
      }
      if (nextU != -1 && (nextTag == -1 || nextU < nextTag)) {
        nextTag = nextU;
        tagType = '<u>';
      }
      if (nextBold != -1 && (nextTag == -1 || nextBold < nextTag)) {
        nextTag = nextBold;
        tagType = '**';
      }

      if (nextTag == -1) {
        spans.add(TextSpan(text: workingText.substring(i), style: style));
        break;
      }

      if (nextTag > i) {
        spans.add(
          TextSpan(text: workingText.substring(i, nextTag), style: style),
        );
      }

      String endTag = tagType == '<u>' ? '</u>' : tagType;
      int closingTag = workingText.indexOf(endTag, nextTag + tagType.length);

      if (closingTag == -1) {
        spans.add(TextSpan(text: tagType, style: style));
        i = nextTag + tagType.length;
        continue;
      }

      String content = workingText.substring(
        nextTag + tagType.length,
        closingTag,
      );
      TextStyle contentStyle = style;

      if (tagType == '__' || tagType == '<u>') {
        contentStyle = contentStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationThickness: 2.0,
          fontWeight: FontWeight.w800,
          decorationColor: style.color?.withOpacity(0.8),
        );
      } else if (tagType == '**') {
        contentStyle = contentStyle.copyWith(fontWeight: FontWeight.w900);
      }

      spans.add(TextSpan(text: content, style: contentStyle));
      i = closingTag + endTag.length;
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }
}
