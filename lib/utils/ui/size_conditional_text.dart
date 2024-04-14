import 'dart:math';

import 'package:flutter/widgets.dart';

class WidthConditionalText extends StatelessWidget {
  final String text;
  final String otherText;
  final double switchWidth;
  final TextStyle? style;
  const WidthConditionalText({super.key, required this.text, required this.otherText, required this.switchWidth, this.style});

  @override Widget build(BuildContext context) {
    var t = text;
    final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr);
    tp.layout();
    if(tp.width > switchWidth) t = otherText;
    return Text(t, style: style);
  }
}