import 'dart:ui';

import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:flutter/cupertino.dart';

class DeadlineAlarms {
  static const DEADLINE_OFFSET = 100000; //uses range [100000, 200000]
  static const SNOOZE_OFFSET = DEADLINE_OFFSET * 3; //uses range [300000, 400000]
  static const SNOOZE_ONGOING_OFFSET = DEADLINE_OFFSET * 4; //uses range [400000, 500000]
  static const TIMER_OFFSET = DEADLINE_OFFSET * 10; //uses range [1000000, 1000006]
  static int toDeadlineId(int notifyId) => notifyId > TIMER_OFFSET ? -1 : (notifyId % DEADLINE_OFFSET) - 1;
  static int toNotificationId(int deadlineId, bool isForStartsAt) {
    if(deadlineId >= DEADLINE_OFFSET) throw ArgumentError("cannot have deadlineId > $DEADLINE_OFFSET");
    if(deadlineId < 0) throw ArgumentError("cannot have deadlineId < 0");
    return (isForStartsAt ? deadlineId : deadlineId + DEADLINE_OFFSET) + 1;
  }

  static Future<void> updateAlarmsFor(Deadline d) async {
    if(d.startsAt == null) {
      await staticNotify.cancel(toNotificationId(d.id!, true));
    } else {
      await _updateAlarmsFor(d, d.startsAt!);
    }
    if(d.deadlineAt == null) {
      await staticNotify.cancel(toNotificationId(d.id!, false));
    } else {
      await _updateAlarmsFor(d, d.deadlineAt!);
    }
  }

  static Future<void> cancelAlarmsFor(Deadline d) async {
    await staticNotify.cancel(toNotificationId(d.id!, true));
    await staticNotify.cancel(toNotificationId(d.id!, false));
  }

  static Future<void> _updateAlarmsFor(Deadline d, NotifyableRepeatableDateTime nrdt) async {
    int notifyId = 0;
    if(d.startsAt == nrdt) {
      notifyId = toNotificationId(d.id!, true);
    } else if(d.deadlineAt == nrdt) {
      notifyId = toNotificationId(d.id!, false);
    } else {
      throw ArgumentError("nrdt not part of d");
    }

    if(!d.active) {
      await staticNotify.cancel(notifyId);
    } else if(nrdt.notifyType == NotificationType.off) {
      await staticNotify.cancel(notifyId);
    } else {
      var next = nrdt.nextOccurrenceAfter(DateTime.now());
      if(next == null) {
        await staticNotify.cancel(notifyId);
      } else {
        await staticNotify.set(
          notifyId, Color(d.color), d.title, d.description,
          nrdt, (dt) => !d.isOnThisDay(dt), (dt) => !d.willRepeatAfter(dt)//if returns is on this day, then it has not been removed
        );
      }
    }
  }
}