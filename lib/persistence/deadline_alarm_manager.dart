import 'dart:ui';

import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/persistence/model.dart';

class DeadlineAlarms {
  static const DEADLINE_OFFSET = 100000; //uses range [100000, 200000]
  static const SNOOZE_OFFSET = DEADLINE_OFFSET * 3; //uses range [300000, 400000]
  static const SNOOZE_ONGOING_OFFSET = DEADLINE_OFFSET * 4; //uses range [400000, 500000]
  static const TIMER_OFFSET = DEADLINE_OFFSET * 10; //uses range [300000, 300006]
  static int toDeadlineId(int notifyId) => notifyId > TIMER_OFFSET ? -1 : notifyId % DEADLINE_OFFSET - 1;
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
      var next = nrdt.buildNextNotificationTime(DateTime.now());
      if(next == null) {
        await staticNotify.cancel(notifyId);
      } else {
        await staticNotify.set(
          notifyId, Color(d.color), d.title, d.description,
          nrdt, (dt) => !d.isOnThisDay(dt), //if returns is on this day, then it has not been removed
        );
      }
    }
  }
}















// import 'dart:typed_data';
//
// import 'package:deadlines/persistence/model.dart';
// import 'package:flutter/material.dart';
//
// class DeadlineAlarms {
//   static int toDeadlineId(int id) => id.abs();
//
//   static Future<bool> updateAlarmsFor(Deadline d) async {
//     if(d.hasRange()) {
//       var sUpdated = await _updateAlarmsFor(d, d.startsAt!);
//       var dUpdated = await _updateAlarmsFor(d, d.deadlineAt);
//       return sUpdated && dUpdated;
//     } else {
//       await Notify.cancel(d.id!);
//       return await _updateAlarmsFor(d, d.deadlineAt);
//     }
//   }
//
//   static Future<void> cancelAlarmsFor(Deadline d) async {
//     await Notify.cancel(d.id!);
//     await Notify.cancel(-d.id!);
//   }
//
//   static Future<bool> _updateAlarmsFor(Deadline d, NotifyableRepeatableDateTime nrdt) async {
//     int notifyId = 0;
//     if(d.startsAt == nrdt) {
//       notifyId = d.id!;
//     } else if(d.deadlineAt == nrdt) {
//       notifyId = -d.id!;
//     } else {
//       throw ArgumentError("nrdt not part of d");
//     }
//
//     if(!d.active) nrdt.notifyType = NotificationType.off;
//
//     print("update: ${nrdt.notifyType}");
//     if(nrdt.notifyType == NotificationType.off) {
//       await Notify.cancel(notifyId);
//     } else {
//       var next = nrdt.buildNextNotificationTime(DateTime.now());
//       if(next == null) {
//         nrdt.notifyType = NotificationType.off;
//         return false;
//       }
//
//       print("next: $next");
//       await Notify.notifyLater(notifyId, d.title, d.description, next, nrdt.notifyType == NotificationType.alarm ? _alarmDetails : _simpleDetails);
//     }
//     return true;
//   }
// }
//
//
// final _simpleDetails = NotificationDetails(
//     android: AndroidNotificationDetails(
//       'deadlines-simple', 'deadlines-simple',
//       channelDescription: 'show simple non-alarm notifications',
//       category: AndroidNotificationCategory.event,
//       importance: Importance.high,
//       priority: Priority.high,
//       fullScreenIntent: false,
//       onlyAlertOnce: false,
//       enableVibration: true,
//       vibrationPattern: Int64List.fromList([300, 100, 100]),
//       visibility: NotificationVisibility.public,
//     ),
//     iOS: null, //cannot test or publish
//     linux: null, //not supposed to run on linux
//     macOS: null //cannot test or publish
// );
// final _alarmDetails = NotificationDetails(
//     android: AndroidNotificationDetails(
//       'deadlines-alarm 1000', 'deadlines-alarm 1000',
//       channelDescription: 'show alarm notifications',
//       category: AndroidNotificationCategory.alarm,
//       importance: Importance.high, // DO NOT SET TO MAX, "unused" according to android docs
//       priority: Priority.max,
//       fullScreenIntent: true,
//       enableVibration: true,
//       playSound: true,
//       ongoing: false,
//       largeIcon: const DrawableResourceAndroidBitmap("@drawable/notify_icon"),
//       styleInformation: const MediaStyleInformation(),
//       subText: "sub text test",
//       usesChronometer: true,
//       chronometerCountDown: false,
//       silent: false,
//       sound: const RawResourceAndroidNotificationSound("sample"),
//       audioAttributesUsage: AudioAttributesUsage.alarm,
//       color: Colors.deepPurple,
//
//       vibrationPattern: Int64List.fromList([3000, 1000, 1000]),
//       visibility: NotificationVisibility.public,
//       onlyAlertOnce: false,
//     ),
//     iOS: null, //cannot test or publish
//     linux: null, //not supposed to run on linux
//     macOS: null //cannot test or publish
// );