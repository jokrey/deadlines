import 'dart:async';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/notifications/deadline_alarm_manager.dart';
import 'package:deadlines/utils/not_dumb_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import '../defaults.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: NotDumbGridView(
            xCount: 2, yCount: 3,
            builder: (index) => TimerWidget(DeadlineAlarms.timerOffset + index),
          ),
        ),
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
  final H = 0;
  final M = 1;
  final S = 2;
  var timeLeft = [0, 0, 0];
  bool isTimerSet = false;
  bool wasCanceled = false;
  var notifyType = NotificationType.alarm;

  late Color color;

  late Timer _repeatUpdate;
  @override void initState() {
    super.initState();

    color = colors[widget.notifyId % DeadlineAlarms.timerOffset];

    updateFunction(_) async {
      var (d, t) = await staticNotify.getDurationTo(widget.notifyId);
      setState(() {
        if((t == NotificationType.normal || t == NotificationType.alarm) && notifyType != t) {
          notifyType = t;
        }
        if(d == Duration.zero) {
          isTimerSet = false;

          if(wasCanceled) {
            timeLeft = [0, 0, 0];
            wasCanceled = false;
          }
        } else {
          timeLeft[H] = d.inHours;
          timeLeft[M] = d.inMinutes % 60;
          timeLeft[S] = d.inSeconds % 60;
          isTimerSet = true;
        }
      });
    }
    updateFunction(null);
    _repeatUpdate = Timer.periodic(const Duration(milliseconds: 1000), updateFunction);
  }
  @override void dispose() {
    _repeatUpdate.cancel();
    super.dispose();
  }

  Future<void> setAlarm() async {
    await staticNotify.set(
      widget.notifyId, color, "Timer is Up", "",
      fromDateTime(
        DateTime.now().add(Duration(hours: timeLeft[H], minutes: timeLeft[M], seconds: timeLeft[S])),
        notify: notifyType
      ),
      null, null
    );
  }

  @override Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IgnorePointer(
                ignoring: isTimerSet,
                child: NumberPicker(
                  value: timeLeft[H],
                  onChanged: (value) => setState(() {
                    timeLeft[H] = value;
                  }),
                  minValue: 0,
                  maxValue: 23,
                  step: 1,
                  zeroPad: true,
                  infiniteLoop: false,
                  itemWidth: 50,
                  textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  selectedTextStyle: const TextStyle(fontSize: 18),
                ),
              ),
              IgnorePointer(
                ignoring: isTimerSet,
                child: NumberPicker(
                  value: timeLeft[M],
                  onChanged: (value) => setState(() {
                    timeLeft[M] = value;
                  }),
                  minValue: 0,
                  maxValue: 59,
                  step: 1,
                  zeroPad: true,
                  infiniteLoop: true,
                  itemWidth: 50,
                  textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  selectedTextStyle: const TextStyle(fontSize: 18),
                ),
              ),
              IgnorePointer(
                ignoring: isTimerSet,
                child: NumberPicker(
                  value: timeLeft[S],
                  onChanged: (value) => setState(() {
                    timeLeft[S] = value;
                  }),
                  minValue: 0,
                  maxValue: 59,
                  step: 1,
                  zeroPad: true,
                  infiniteLoop: true,
                  itemWidth: 50,
                  textStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  selectedTextStyle: const TextStyle(fontSize: 18),
                ),
              ),
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
              onTap: ()  {
                notifyType = notifyType == NotificationType.alarm? NotificationType.normal: NotificationType.alarm;
                setAlarm().then((_) => setState(() {}));
              },
            ),
            TextButton(onPressed: () {
              if(isTimerSet) {
                staticNotify.cancel(widget.notifyId).then((_) => setState(() {}));
              } else {
                setAlarm().then((_) => setState(() {}));
              }
            }, child: Text(!isTimerSet?"Start":"Pause", style: TextStyle(color: color),)),
            TextButton(onPressed: () {
              wasCanceled = true;
              staticNotify.cancel(widget.notifyId).then((_) => setState(() {}));
            }, child: Text("Cancel", style: TextStyle(color: color),)),
          ],
        )
      ],
    );
  }
}