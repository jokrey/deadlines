import 'package:flutter/material.dart';

class CircledTextCheckbox extends StatefulWidget {
  final String text;
  final bool initial;
  final Color? checkedColor;
  final Color? notCheckedColor;
  final bool Function(bool) callback;
  const CircledTextCheckbox({super.key, required this.text, required this.initial, required this.checkedColor, required this.notCheckedColor, required this.callback});

  @override State<CircledTextCheckbox> createState() => _CircledTextCheckboxState();
}

class _CircledTextCheckboxState extends State<CircledTextCheckbox> {
  late bool _isChecked;
  @override void initState() {
    super.initState();
    _isChecked = widget.initial;
  }
  @override Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width / 8;
    return InkWell(
      onTap: () => setState(() {
        _isChecked = widget.callback(!_isChecked);
      }),
      child: Container(
        width: w,
        height: w,
        decoration: BoxDecoration (
          shape: BoxShape.circle,
          border: Border.all(
            color: _isChecked ? widget.checkedColor ?? Theme.of(context).primaryTextTheme.bodySmall?.color ?? Colors.black : widget.notCheckedColor ?? Theme.of(context).primaryTextTheme.bodySmall?.color ?? Colors.black  ,
          ),
        ),
        alignment: Alignment.center,
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(7),
        child: Text(
          widget.text,
          style: TextStyle(color: _isChecked ? widget.checkedColor : widget.notCheckedColor, fontSize: 14)
        ),
      ),
    );
  }
}