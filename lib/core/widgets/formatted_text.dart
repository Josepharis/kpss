import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  const FormattedText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (!text.contains('**') && !text.contains('__')) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final spans = <TextSpan>[];
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;

    // Simple state machine to parse **bold** and __underline__
    // Note: This doesn't handle nested tags perfectly but sufficient for standard use

    int i = 0;
    while (i < text.length) {
      int nextBold = text.indexOf('**', i);
      int nextUnderline = text.indexOf('__', i);

      int nextTag = -1;
      if (nextBold != -1 && (nextUnderline == -1 || nextBold < nextUnderline)) {
        nextTag = nextBold;
      } else if (nextUnderline != -1) {
        nextTag = nextUnderline;
      }

      if (nextTag == -1) {
        // No more tags
        spans.add(TextSpan(text: text.substring(i), style: defaultStyle));
        break;
      }

      if (nextTag > i) {
        // Text before the tag
        spans.add(
          TextSpan(text: text.substring(i, nextTag), style: defaultStyle),
        );
      }

      String tag = text.substring(nextTag, nextTag + 2);
      int closingTag = text.indexOf(tag, nextTag + 2);

      if (closingTag == -1) {
        // Unclosed tag, treat as plain text
        spans.add(TextSpan(text: tag, style: defaultStyle));
        i = nextTag + 2;
        continue;
      }

      String content = text.substring(nextTag + 2, closingTag);
      TextStyle contentStyle = defaultStyle;
      if (tag == '**') {
        contentStyle = contentStyle.copyWith(fontWeight: FontWeight.bold);
      } else if (tag == '__') {
        contentStyle = contentStyle.copyWith(
          decoration: TextDecoration.underline,
        );
      }

      spans.add(TextSpan(text: content, style: contentStyle));
      i = closingTag + 2;
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans, style: defaultStyle),
    );
  }
}
