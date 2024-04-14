import 'dart:math';

import 'package:flutter/widgets.dart';

class FittedText extends StatelessWidget {
  final String text;
  final Color foreground;
  final double maxWidth;
  final double maxHeight;
  final double preferredMinFontSize;
  final double maxFontSize;
  const FittedText({super.key, required this.text, required this.foreground, required this.maxWidth, required this.maxHeight, this.preferredMinFontSize = 5, this.maxFontSize = 14});

  @override Widget build(BuildContext context) {
    String t = text;
    double fontSize = maxFontSize;

    double width;
    double height;
    while(fontSize >= 1) {//admitted, this is slightly problematic in terms of performance, but it looks good
      final textSpan = TextSpan(text: t, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold));
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      width = tp.width;
      height = tp.height;
      if(height > maxHeight) {
        fontSize -= max(0.05, min(1, (height-maxHeight) / 5));
      } else if(width > maxWidth) {
        if(fontSize <= preferredMinFontSize) {
          t = t.substring(0, t.length - 1).trim();
        } else {
          fontSize -= max(0.05, min(1, (width-maxWidth) / 5));
          fontSize = max(fontSize, preferredMinFontSize);
        }
      } else {
        break;
      }
    }

    return Text(t, maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize, color: foreground, fontWeight: FontWeight.bold));
  }
}