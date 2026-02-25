import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  const FormattedText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.isQuestionStem = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool isQuestionStem;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final defaultStyle = style ?? DefaultTextStyle.of(context).style;

    // Process text for premises (I, II, III) and auto-detect the stem
    // Also handle single quotes as underlines for KPSS questions
    String workingText = text;

    // Heuristic: If the text contains single quotes like 'kelime', it's often intended to be underlined in KPSS.
    // We convert 'word' to <u>word</u> to leverage our existing parser.
    // We try to avoid matching possessive suffixes like "Türkiye'nin" by ensuring the start quote is preceded by space/start
    // and the end quote is followed by space/punct/end.
    workingText = workingText.replaceAllMapped(
      RegExp(r"(^|\s|[(\[{])'([^']{2,})'(?=\s|[,.!?;:\])}]|$)"),
      (match) => "${match.group(1)}<u>${match.group(2)}</u>",
    );

    // Also handle double quotes if they are used similarly
    workingText = workingText.replaceAllMapped(
      RegExp(r'(^|\s|[(\[{])"([^"]{2,})"(?=\s|[,.!?;:\])}]|$)'),
      (match) => "${match.group(1)}<u>${match.group(2)}</u>",
    );

    final lines = workingText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    // Heuristic: Count how many lines look like premises (I., II., 1., 2. etc.)
    // If there's only one, it's likely part of a sentence like "I. TBMM" or "1. Dünya Savaşı"
    final premiseRegex = RegExp(
      r'^([IVXLCDM]+|[0-9]+)\.\s+',
      caseSensitive: false,
    );
    int premiseCount = 0;
    for (final line in lines) {
      if (premiseRegex.hasMatch(line.trim())) {
        premiseCount++;
      }
    }
    final bool usePremiseStyle = premiseCount > 1;

    final children = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Regex for premises like I., II., III. or 1., 2., 3.
      final premiseMatch = premiseRegex.firstMatch(trimmedLine);

      // Auto-detect stem:
      // 1. If it's the last line and there are premises before it
      // 2. If it's the last line and starts with common question words
      // 3. If isQuestionStem is explicitly true (for the whole widget)
      bool isThisLineStem = isQuestionStem;
      if (!isQuestionStem && i == lines.length - 1 && lines.length > 1) {
        final stemStarters = [
          'hangisi',
          'hangileri',
          'buna göre',
          'aşağıdakilerden',
          'bu parça',
        ];
        final lowerLine = trimmedLine.toLowerCase();
        bool startsWithStemWord = stemStarters.any(
          (s) => lowerLine.startsWith(s),
        );
        bool followsPremise =
            i > 0 && premiseRegex.hasMatch(lines[i - 1].trim());

        if (startsWithStemWord || (usePremiseStyle && followsPremise)) {
          isThisLineStem = true;
        }
      }

      if (usePremiseStyle && premiseMatch != null) {
        final number = premiseMatch.group(1);
        final content = trimmedLine.substring(premiseMatch.end);

        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0, top: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$number.',
                    style: defaultStyle.copyWith(
                      fontWeight: FontWeight.w900,
                      color: defaultStyle.color?.withOpacity(0.85),
                    ),
                  ),
                ),
                Expanded(
                  child: _RichTextParser(
                    text: content,
                    style: defaultStyle,
                    textAlign: textAlign,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 10.0),
            child: _RichTextParser(
              text: line,
              style: isThisLineStem
                  ? defaultStyle.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: (defaultStyle.fontSize ?? 15) + 0.5,
                      height: 1.4,
                    )
                  : defaultStyle,
              textAlign: textAlign,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _RichTextParser extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const _RichTextParser({
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (!text.contains('**') &&
        !text.contains('__') &&
        !text.contains('<u>') &&
        !text.contains('<b>')) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final spans = <TextSpan>[];
    int i = 0;

    while (i < text.length) {
      final nextBoldMarkdown = text.indexOf('**', i);
      final nextUnderlineMarkdown = text.indexOf('__', i);
      final nextU = text.indexOf('<u>', i);
      final nextB = text.indexOf('<b>', i);

      int nextTag = -1;
      String tagType = '';

      // Find the earliest tag
      if (nextBoldMarkdown != -1) {
        nextTag = nextBoldMarkdown;
        tagType = '**';
      }
      if (nextUnderlineMarkdown != -1 &&
          (nextTag == -1 || nextUnderlineMarkdown < nextTag)) {
        nextTag = nextUnderlineMarkdown;
        tagType = '__';
      }
      if (nextU != -1 && (nextTag == -1 || nextU < nextTag)) {
        nextTag = nextU;
        tagType = '<u>';
      }
      if (nextB != -1 && (nextTag == -1 || nextB < nextTag)) {
        nextTag = nextB;
        tagType = '<b>';
      }

      if (nextTag == -1) {
        spans.add(TextSpan(text: text.substring(i), style: style));
        break;
      }

      if (nextTag > i) {
        spans.add(TextSpan(text: text.substring(i, nextTag), style: style));
      }

      String endTag = tagType;
      if (tagType == '<u>')
        endTag = '</u>';
      else if (tagType == '<b>')
        endTag = '</b>';

      int closingTag = text.indexOf(endTag, nextTag + tagType.length);

      if (closingTag == -1) {
        spans.add(TextSpan(text: tagType, style: style));
        i = nextTag + tagType.length;
        continue;
      }

      String content = text.substring(nextTag + tagType.length, closingTag);
      TextStyle contentStyle = style;

      if (tagType == '**' || tagType == '<b>') {
        contentStyle = contentStyle.copyWith(fontWeight: FontWeight.w900);
      } else if (tagType == '__' || tagType == '<u>') {
        contentStyle = contentStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationThickness: 2.0,
          fontWeight: FontWeight.w800,
          decorationColor: style.color?.withOpacity(0.8),
        );
      }

      spans.add(TextSpan(text: content, style: contentStyle));
      i = closingTag + endTag.length;
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans, style: style),
    );
  }
}
