import 'dart:async';

import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/persistence/deadline_alarm_manager.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:synchronized/synchronized.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(child: GridView.builder(
          shrinkWrap: true, // new line
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 6),
          itemBuilder: (_, index) {
            return TimerWidget(DeadlineAlarms.timerOffset + index);
          },
          itemCount: 6,
        )),
      ),
    );
  }
}


class TimerWidget extends StatefulWidget {
  final int notifyId;
  const TimerWidget(this.notifyId, {super.key});

  @override State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  static const H = 0;
  static const M = 1;
  static const S = 2;
  var timeLeft = [-1, 0, 0];
  var before = [-1, 0, 0];
  late Color color;
  var notifyType = NotificationType.alarm;

  var lock = Lock();
  late Timer _repeatUpdate;
  late DelayedNumberPickerController hourController;
  late DelayedNumberPickerController minuteController;
  late DelayedNumberPickerController secondController;
  @override void initState() {
    super.initState();

    color = colors[widget.notifyId % DeadlineAlarms.timerOffset];

    hourController = DelayedNumberPickerController(
      onChangeDone: (value) => lock.synchronized(() {
        timeLeft[H] = value;
      }),
      onChanged: (value) {
        if(timeLeft[H] != 0) {
          lock.synchronized(() {
            timeLeft[H] = value;
          });
        }
      },
    );
    minuteController = DelayedNumberPickerController(
      onChangeDone: (value) => lock.synchronized(() {
        timeLeft[M] = value;
      }),
      onChanged: (value) {
        if(timeLeft[M] != 0) {
          lock.synchronized(() {
            timeLeft[M] = value;
          });
        }
      },
    );
    secondController = DelayedNumberPickerController(
      onChangeDone: (value) => lock.synchronized(() {
        timeLeft[S] = value;
      }),
      onChanged: (value) {
        if(timeLeft[S] != 0) {
          lock.synchronized(() {
            timeLeft[S] = value;
          });
        }
      },
    );

    int loadMinimizer = 8;
    updateFunction(_) async {
      await lock.synchronized(() async {
        if(!listEquals(timeLeft, before)) {
          before.setRange(0, 3, timeLeft);
          await resetAlarm();
        } else {
          if(before[H] == 0 && before[M] == 0 && before[S] == 0) {
            loadMinimizer++;
            if(loadMinimizer < 8) return;
            loadMinimizer = 0;
          }
          var (d, t) = await staticNotify.getDurationTo(widget.notifyId);
          timeLeft = [d.inHours, d.inMinutes % 60, d.inSeconds % 60];
          if((t == NotificationType.normal || t == NotificationType.alarm) && notifyType != t) {
            setState(() {
              notifyType = t;
            });
          }
          before.setRange(0, 3, timeLeft);
        }
        hourController.setValue(timeLeft[H]);
        minuteController.setValue(timeLeft[M]);
        secondController.setValue(timeLeft[S]);
      });
    }
    updateFunction(null);
    _repeatUpdate = Timer.periodic(const Duration(milliseconds: 250), updateFunction);
  }
  Future<void> resetAlarm() async {
    if(timeLeft[H] == 0 && timeLeft[M] == 0 && timeLeft[S] == 0) {
      await staticNotify.cancel(widget.notifyId);
    } else {
      await staticNotify.set(
          widget.notifyId, color, "Timer is Up", "",
          fromDateTime(
              DateTime.now().add(Duration(hours: timeLeft[H], minutes: timeLeft[M], seconds: timeLeft[S])),
              notify: notifyType
          ),
          null, null
      );
    }
  }
  @override void dispose() {
    _repeatUpdate.cancel();
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DelayedNumberPicker(
                hourController,
                minValue: 0,
                maxValue: 23,
                step: 1,
                infiniteLoop: false,
                itemWidth: 50,
                textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                selectedTextStyle: const TextStyle(fontSize: 18),
              ),
              DelayedNumberPicker(
                minuteController,
                minValue: 0,
                maxValue: 59,
                step: 1,
                infiniteLoop: true,
                itemWidth: 50,
                textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                selectedTextStyle: const TextStyle(fontSize: 18),
              ),
              /*IgnorePointer(child: */DelayedNumberPicker(
                secondController,
                minValue: 0,
                maxValue: 59,
                step: 1,
                infiniteLoop: true,
                itemWidth: 50,
                textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                selectedTextStyle: const TextStyle(fontSize: 18),
              )/*)*/,
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
                child: Icon(
                  notifyType == NotificationType.off    ? Icons.notifications_off_rounded :
                  notifyType == NotificationType.silent ? Icons.notifications_paused_rounded :
                  notifyType == NotificationType.normal ? Icons.notifications_rounded :
                  notifyType == NotificationType.fullscreen ? Icons.fullscreen_rounded :
                  Icons.notifications_active_rounded,
                  color: color,
                ),
                onTap: () => setState(() {
                  notifyType = notifyType == NotificationType.alarm? NotificationType.normal: NotificationType.alarm;
                  resetAlarm(); //no need to wait
                })
            ),
            ElevatedButton(onPressed: () {
              lock.synchronized(() {
                timeLeft = [0, 0, 0];
                hourController.setValue(timeLeft[H]);
                minuteController.setValue(timeLeft[M]);
                secondController.setValue(timeLeft[S]);
              });
            }, child: Text("Cancel Timer", style: TextStyle(color: color),)),
          ],
        )
      ],
    );
  }

}


class DelayedNumberPickerController {
  var lock = Lock();
  int _currentValue = 0;
  void setValue(int newValue) {
    lock.synchronized(() {
      if(setState != null && _currentValue != newValue) setState!(() {_currentValue = newValue;});
    });
  }
  Function(VoidCallback)? setState;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeDone;
  DelayedNumberPickerController({this.onChanged, this.onChangeDone});
}
class DelayedNumberPicker extends StatefulWidget {
  final DelayedNumberPickerController controller;

  final int minValue;
  final int maxValue;
  final int itemCount;
  final int step;
  final double itemHeight;
  final double itemWidth;
  final Axis axis;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle;
  final bool infiniteLoop;
  const DelayedNumberPicker(
    this.controller, {
    super.key,
    this.minValue = 0,
    this.maxValue = 3,
    this.itemCount = 3,
    this.step = 1,
    this.itemHeight = 50,
    this.itemWidth = 100,
    this.axis = Axis.vertical,
    this.textStyle,
    this.selectedTextStyle,
    this.infiniteLoop = false,
  });

  @override State<DelayedNumberPicker> createState() => _DelayedNumberPickerState();
}

class _DelayedNumberPickerState extends State<DelayedNumberPicker> {
  @override void initState() {
    super.initState();
    widget.controller.setState = setState;
  }
  @override void dispose() {
    widget.controller.setState = null;
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (event) {
        widget.controller.lock.synchronized(() {
          if(widget.controller.onChangeDone != null) widget.controller.onChangeDone!(widget.controller._currentValue);
        });
      },
      child: NumberPicker(
        value: widget.controller._currentValue,
        minValue: widget.minValue,
        maxValue: widget.maxValue,
        onChanged: (value) {
          widget.controller.lock.synchronized(() {
            widget.controller._currentValue = value;
            setState(() {});
            if(widget.controller.onChanged != null) widget.controller.onChanged!(value);
          });
        },
        itemCount: widget.itemCount,
        step: widget.step,
        itemHeight: widget.itemHeight,
        itemWidth: widget.itemWidth,
        axis: widget.axis,
        textStyle: widget.textStyle,
        selectedTextStyle: widget.selectedTextStyle,
        infiniteLoop: widget.infiniteLoop,
        zeroPad: true,
        haptics: true,
      ),
    );
  }
}