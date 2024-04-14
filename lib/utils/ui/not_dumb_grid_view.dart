import 'package:flutter/material.dart';

class NotDumbGridView extends StatelessWidget {
  final int xCount;
  final int yCount;
  final double xMargin;
  final double yMargin;
  final Widget Function(int) builder;
  const NotDumbGridView({super.key, required this.xCount, required this.yCount, this.xMargin = 0, this.yMargin = 0, required this.builder});

  @override Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth - xMargin * 2;
        var h = constraints.maxHeight - yMargin * 2;
        var availableW = w / xCount - xMargin * 2;
        var availableH = h / yCount - yMargin * 2;

        var children = <Widget>[];
        for(int i = 0; i < xCount * yCount; i++) {
          double x = w/xCount * (i % xCount);
          double y = h * (((i / xCount).floor()) / yCount);
          children.add(Positioned(
            left: xMargin + x,
            width: availableW,
            top: yMargin + y,
            height: availableH,
            child: builder(i),
          ));
        }
        return Container(
          margin: EdgeInsets.only(left: xMargin, right: xMargin, top: yMargin, bottom: yMargin),
          child: Stack(children: children,)
        );
      }
    );
  }
}