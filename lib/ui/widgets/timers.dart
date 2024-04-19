import 'dart:async';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/utils/ui/not_dumb_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import '../defaults.dart';

/// Timers View, shows six timers that create a normal or an alarm notification upon completion
/// Can be used for cooking
class TimersView extends StatefulWidget {
  const TimersView({super.key});

  @override State<TimersView> createState() => _TimersViewState();
}

class _TimersViewState extends State<TimersView> {
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: NotDumbGridView(
        xCount: 2, yCount: 3,
        builder: (index) => _TimerWidget(NotifyWrapper.timerOffset + index),
      ),
    ),),);
  }
}


class _TimerWidget extends StatefulWidget {
  final int notifyId;
  const _TimerWidget(this.notifyId);

  @override State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  static const H = 0;
  static const M = 1;
  static const S = 2;
  var _timeLeft = [0, 0, 0];
  bool _isTimerSet = false;
  bool _wasCanceled = false;
  var _notifyType = NotificationType.alarm;

  late Color _color;

  late Timer _repeatUpdate;
  @override void initState() {
    super.initState();

    _color = colors[widget.notifyId % NotifyWrapper.timerOffset];

    updateFunction(_) async {
      var (d, t) = await staticNotify.getDurationTo(widget.notifyId);
      setState(() {
        if((t == NotificationType.normal || t == NotificationType.alarm) && _notifyType != t) {
          _notifyType = t;
        }
        if(d == Duration.zero) {
          _isTimerSet = false;

          if(_wasCanceled) {
            _timeLeft = [0, 0, 0];
            _wasCanceled = false;
          }
        } else {
          _timeLeft[H] = d.inHours;
          _timeLeft[M] = d.inMinutes % 60;
          _timeLeft[S] = d.inSeconds % 60;
          _isTimerSet = true;
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
      widget.notifyId, _color, "Timer is Up", "",
      fromDateTime(
        DateTime.now().add(Duration(hours: _timeLeft[H], minutes: _timeLeft[M], seconds: _timeLeft[S])),
        notify: _notifyType
      ),
      null, null
    );
  }

  @override Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IgnorePointer(
              ignoring: _isTimerSet,
              child: NumberPicker(
                value: _timeLeft[H],
                onChanged: (value) => setState(() {
                  _timeLeft[H] = value;
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
              ignoring: _isTimerSet,
              child: NumberPicker(
                value: _timeLeft[M],
                onChanged: (value) => setState(() {
                  _timeLeft[M] = value;
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
              ignoring: _isTimerSet,
              child: NumberPicker(
                value: _timeLeft[S],
                onChanged: (value) => setState(() {
                  _timeLeft[S] = value;
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
        ),),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: ()  {
                _notifyType = _notifyType == NotificationType.alarm? NotificationType.normal: NotificationType.alarm;
                setAlarm().then((_) => setState(() {}));
              },
              child: Icon(
                _notifyType == NotificationType.off    ? Icons.notifications_off_rounded :
                _notifyType == NotificationType.silent ? Icons.notifications_paused_rounded :
                _notifyType == NotificationType.normal ? Icons.notifications_rounded :
                _notifyType == NotificationType.fullscreen ? Icons.fullscreen_rounded :
                Icons.notifications_active_rounded,
                color: _color,
              ),
            ),
            TextButton(onPressed: () {
              if(_isTimerSet) {
                staticNotify.cancel(widget.notifyId).then((_) => setState(() {}));
              } else {
                setAlarm().then((_) => setState(() {}));
              }
            }, child: Text(!_isTimerSet?"Start":"Pause", style: TextStyle(color: _color),)),
            TextButton(onPressed: () {
              _wasCanceled = true;
              staticNotify.cancel(widget.notifyId).then((_) => setState(() {}));
            }, child: Text("Cancel", style: TextStyle(color: _color),)),
          ],
        )
      ],
    );
  }
}