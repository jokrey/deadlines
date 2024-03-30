
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';

class NicerTimePickerWidget extends StatefulWidget {
  late int currentHour;
  late int currentMinute;
  final int initialHour;
  final int initialMinute;
  final Function(int, int) onChanged;
  NicerTimePickerWidget(this.initialHour, this.initialMinute, {required this.onChanged, super.key}) {
    currentHour = initialHour;
    currentMinute = initialMinute;
  }

  @override State<NicerTimePickerWidget> createState() => _NicerTimePickerWidgetState();
}

class _NicerTimePickerWidgetState extends State<NicerTimePickerWidget> {
  @override Widget build(BuildContext context) {
    return Row(
      children: [
        NumberPicker(
          value: widget.currentHour,
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
              widget.currentHour = value;
              widget.onChanged(widget.currentHour, widget.currentMinute);
            });
          },
        ),
        NumberPicker(
          value: widget.currentMinute,
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
              widget.currentMinute = value;
              widget.onChanged(widget.currentHour, widget.currentMinute);
            });
          },
        ),
      ],
    );
  }
}

class NicerDatePickerWidget extends StatelessWidget {
  final DateTime? date;
  final Function(DateTime?) onDateSelected;
  const NicerDatePickerWidget(this.date, this.onDateSelected, {super.key});

  @override Widget build(BuildContext context) {
    onPressed() async {
      final DateTime? picked = await showDatePicker(
          context: context,
          locale: const Locale('en', 'GB'),
          initialDate: date,
          firstDate: DateTime(1990),
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
