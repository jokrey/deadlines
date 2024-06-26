import 'dart:ui';

import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/cupertino.dart';

import 'alarm_external_wrapper/model.dart';
import 'alarm_external_wrapper/notify_wrapper.dart';

/// amends the NotifyWrapper class with deadline app specified functionality
class DeadlineAlarms {
  static final int deadlineOffset = (NotifyWrapper.userNotificationMaxId / 2).floor();
  /// builds a deadline id from a notify id which can be used with the deadlines database
  static int toDeadlineId(int notifyId) => notifyId > NotifyWrapper.timerOffset ? -1 : (notifyId % deadlineOffset) - 1;
  /// Returns a notification id for a deadlines database id (e.g. a specific deadline)
  static int toNotificationId(int deadlineId, bool isForStartsAt) {
    if(deadlineId >= deadlineOffset) throw ArgumentError("cannot have deadlineId > $deadlineOffset");
    if(deadlineId < 0) throw ArgumentError("cannot have deadlineId < 0");
    return (isForStartsAt ? deadlineId : deadlineId + deadlineOffset) + 1;
  }

  /// reset the specified alarms for the given deadline with the static notify wrapper
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

  /// Cancel all alarms for the given deadline
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

    if(notifyId > NotifyWrapper.userNotificationMaxId) throw StateError("too many notifications");

    if(nrdt.notifyType == NotificationType.off) {
      await staticNotify.cancel(notifyId);
    } else {
      var next = nrdt.nextOccurrenceAfter(DateTime.now());
      if(next == null || !d.activeAtAll) {
        await staticNotify.cancel(notifyId);
      } else {
        await staticNotify.set(
          notifyId, Color(d.color), d.title, d.description,
          nrdt, (dt) => !d.isActiveOn(stripTime(dt)) || !d.isOnThisDay(dt), (dt) => !d.willRepeatAfter(dt)//if returns is on this day, then it has not been removed
        );
      }
    }
  }
}