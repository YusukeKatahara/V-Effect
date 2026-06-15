import 'package:flutter/material.dart';

// ────────────────────────────────────────────
// タスク名の自動縮小テキスト表示用ウィジェット（フォントサイズ調整）
// ────────────────────────────────────────────
class AutoSizeText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AutoSizeText(
    this.text, {
    super.key,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    const double minFontSize = 14;
    const int maxLines = 1;
    const TextOverflow overflow = TextOverflow.ellipsis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        double fontSize = style.fontSize ?? 22;

        // 文字の描画幅を測定し、1行に収まるまでフォントサイズを縮小する
        while (fontSize >= minFontSize) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: fontSize),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          );
          textPainter.layout(maxWidth: maxWidth);

          // 1行に収まっていればループを終了する
          if (!textPainter.didExceedMaxLines) {
            break;
          }
          fontSize -= 1.0;
        }

        // 最小フォントサイズ（14px）まで縮小しても収まらない場合は、2行表示を許容する
        final finalFontSize = fontSize < minFontSize ? minFontSize : fontSize;
        final finalMaxLines = fontSize < minFontSize ? 2 : maxLines;

        return Text(
          text,
          style: style.copyWith(fontSize: finalFontSize),
          maxLines: finalMaxLines,
          overflow: overflow,
        );
      },
    );
  }
}
