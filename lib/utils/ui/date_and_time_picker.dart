import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';

/// Widget consisting of two number picker, representing hour and minute
/// Will callback with both values if either changes
class NicerTimePickerWidget extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final Function(int, int) onChanged;
  const NicerTimePickerWidget(this.initialHour, this.initialMinute, {required this.onChanged, super.key});

  @override State<NicerTimePickerWidget> createState() => _NicerTimePickerWidgetState();
}

class _NicerTimePickerWidgetState extends State<NicerTimePickerWidget> {
  late int currentHour;
  late int currentMinute;
  @override void initState() {
    super.initState();
    currentHour = widget.initialHour;
    currentMinute = widget.initialMinute;
  }

  @override Widget build(BuildContext context) {
    return Row(
      children: [
        NumberPicker(
          value: currentHour,
          minValue: 0,
          maxValue: 23,
          step: 1,
          infiniteLoop: true,
          itemWidth: 75,
          textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
          zeroPad: true,
          selectedTextStyle: const TextStyle(fontSize: 18),
          onChanged: (value) {
            setState(() {
              currentHour = value;
              widget.onChanged(currentHour, currentMinute);
            });
          },
        ),
        NumberPicker(
          value: currentMinute,
          minValue: 0,
          maxValue: 59,
          step: 1,
          infiniteLoop: true,
          itemWidth: 75,
          textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
          zeroPad: true,
          selectedTextStyle: const TextStyle(fontSize: 18),
          onChanged: (value) {
            setState(() {
              currentMinute = value;
              widget.onChanged(currentHour, currentMinute);
            });
          },
        ),
      ],
    );
  }
}

/// Text displaying current date and an event icon
/// Will show DatePicker ui on tap and pass the result to the onDateSelected callback
/// ui using this widget must reload and update the shown date of this StateLESS Widget again
class NicerDatePickerWidget extends StatelessWidget {
  /// Initial date, if null -> text will say none and datepicker will start at today
  final DateTime? date;
  /// callback if date selected with the given date or null if selection canceled
  final Function(DateTime?) onDateSelected;
  const NicerDatePickerWidget(this.date, this.onDateSelected, {super.key});

  @override Widget build(BuildContext context) {
    onPressed() async {
      final DateTime? picked = await showDatePicker(
          context: context,
          locale: const Locale('en', 'GB'),
          initialDate: date,
          firstDate: DateTime(1970),
          lastDate: DateTime(2100));
      onDateSelected(picked);
    }
    return Row(
      children: [
        InkWell(
          onTap: onPressed,
          child: Text("${date?.toLocal()??"none"}".split(' ')[0],),
        ),
        const SizedBox(width: 5.0,),
        GestureDetector(
          onTap: onPressed,
          child: const Icon(Icons.event, size: 25,),
        ),
      ]
    );
  }
}
