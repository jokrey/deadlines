import 'package:flutter/material.dart';

/// A colored circle around a text widget with checkbox functionality
class CircledTextCheckbox extends StatefulWidget {
  /// displayed text within the circle
  final String text;
  /// whether it should be displayed as checked initially
  final bool initial;
  /// The color of circle and text if the checkbox is checked (or null for a default)
  final Color? checkedColor;
  /// The color of circle and text if the checkbox is not-checked (or null for a default)
  final Color? notCheckedColor;
  /// Callback with the new checked-state when the checkbox is tapped
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