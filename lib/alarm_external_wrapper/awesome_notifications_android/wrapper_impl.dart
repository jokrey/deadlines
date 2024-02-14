import 'dart:typed_data';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/main.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/deadline_alarm_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../model.dart';

class AwesomeNotificationsWrapper extends NotifyWrapper {
  static const String _SILENT_CHANNEL_NAME = "silent - 99999";
  static const String _NORMAL_CHANNEL_NAME = "normal - 99999";
  static const String _FULLSCREEN_CHANNEL_NAME = "fullscreen - 99999";
  static const String _ALARM_CHANNEL_NAME = "alarm - 99999";
  static const String _SNOOZE_CHANNEL_NAME = "snooze - 99999";

  static String currentTimeZone = "CET";

  @override Future<void> init() async {
    super.init();
    await AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
        'resource://drawable/notify_icon',
        [
          NotificationChannel(
            channelGroupKey: 'deadlines',
            channelKey: _SILENT_CHANNEL_NAME,
            channelName: _SILENT_CHANNEL_NAME,
            channelDescription: _SILENT_CHANNEL_NAME,

            importance: NotificationImportance.Max,
            criticalAlerts: true,

            enableVibration: false,
            playSound: false,
            locked: true, //only required, because dismiss must reschedule (but dismiss action callback will not return when terminated)

            ledColor: Colors.blue,
            onlyAlertOnce: false,
          ),
          NotificationChannel(
            channelGroupKey: 'deadlines',
            channelKey: _NORMAL_CHANNEL_NAME,
            channelName: _NORMAL_CHANNEL_NAME,
            channelDescription: _NORMAL_CHANNEL_NAME,

            importance: NotificationImportance.Max,
            criticalAlerts: true,

            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200, 200]),
            locked: true, //only required, because dismiss must reschedule (but dismiss action callback will not return when terminated)

            ledColor: Colors.blue,
            onlyAlertOnce: false,
          ),
          NotificationChannel(
            channelGroupKey: 'deadlines',
            channelKey: _FULLSCREEN_CHANNEL_NAME,
            channelName: _FULLSCREEN_CHANNEL_NAME,
            channelDescription: _FULLSCREEN_CHANNEL_NAME,

            importance: NotificationImportance.Max,
            criticalAlerts: true,

            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200, 200]),
            locked: true,

            ledColor: Colors.blue,
            onlyAlertOnce: false,
          ),
          NotificationChannel(
            channelGroupKey: 'deadlines',
            channelKey: _ALARM_CHANNEL_NAME,
            channelName: _ALARM_CHANNEL_NAME,
            channelDescription: _ALARM_CHANNEL_NAME,

            importance: NotificationImportance.Max, //uses fullscreen intent or system alert screen anyway (but, no pop up)
            criticalAlerts: true,

            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Alarm,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200, 200]),
            locked: true,

            ledColor: Colors.blue,
            onlyAlertOnce: false,
          ),
          NotificationChannel(
            channelGroupKey: 'deadlines',
            channelKey: _SNOOZE_CHANNEL_NAME,
            channelName: _SNOOZE_CHANNEL_NAME,
            channelDescription: _SNOOZE_CHANNEL_NAME,

            importance: NotificationImportance.High,
            criticalAlerts: false,
            channelShowBadge: false,
            locked: true,

            playSound: false,
            enableVibration: false,

            ledColor: Colors.blue,
            onlyAlertOnce: false,
          )
        ],
        // Channel groups are only visual and are not required
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: 'deadlines',
            channelGroupName: 'deadlines'
          )
        ],
        debug: true
    );

    currentTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        const permissions = [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
          NotificationPermission.CriticalAlert,
          NotificationPermission.FullScreenIntent,
          NotificationPermission.PreciseAlarms,
          NotificationPermission.OverrideDnD,
          NotificationPermission.Provisional,
          NotificationPermission.Badge,
          NotificationPermission.Car,
        ];
        await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: _SILENT_CHANNEL_NAME, permissions: permissions
        );
        await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: _NORMAL_CHANNEL_NAME, permissions: permissions
        );
        await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: _FULLSCREEN_CHANNEL_NAME, permissions: permissions
        );
        await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: _ALARM_CHANNEL_NAME, permissions: permissions
        );
        await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: _SNOOZE_CHANNEL_NAME, permissions: permissions
        );
      }
    });

    await AwesomeNotifications().setListeners(
        onActionReceivedMethod:         AwesomeNotificationsWrapper.onActionReceivedMethod,
        onNotificationCreatedMethod:    AwesomeNotificationsWrapper.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:  AwesomeNotificationsWrapper.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod:  AwesomeNotificationsWrapper.onDismissActionReceivedMethod
    );


    // ReceivedAction? receivedAction = await AwesomeNotifications().getInitialNotificationAction(
    //   removeFromActionEvents: true
    // );
    // if(receivedAction != null) {
    //   await onActionReceivedMethod(receivedAction);
    // }
  }

  @override Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop) async {
    if(at.notifyType == NotificationType.off) {
      await cancel(notifyId);
    } else {
      bool success = await createNotification(notifyId, color, title, description, at, shouldSkip, shouldStop);
      if(!success) {
        print("cancel");
        await cancel(notifyId);
      }
    }
  }

  @override Future<void> cancel(int notifyId) async {
    await AwesomeNotifications().cancel(notifyId);
  }

  @override Future<Duration> getDurationTo(int notifyId) async {
    var notifyWithId = (await AwesomeNotifications().listScheduledNotifications()).where((e) => e.content != null && e.content!.id == notifyId).firstOrNull;

    // print("notifyWithId: $notifyWithId");
    if(notifyWithId == null || notifyWithId.schedule == null) return Duration.zero;
    var now = DateTime.now();
    notifyWithId.schedule!.timeZone = currentTimeZone;
    notifyWithId.schedule!.timeZone = "UTC"; //bug in getNextDate?
    var notifyAt = await AwesomeNotifications().getNextDate(notifyWithId.schedule!, fixedDate: now);
    return notifyAt == null? Duration.zero : notifyAt.difference(now);
  }

  @override Future<(int, Duration)?> getDurationToNextAlarm() async {
    var all = await AwesomeNotifications().listScheduledNotifications();
    var now = DateTime.now();
    (int, DateTime)? min;
    for(var a in all) {
      int? id;
      DateTime? next;
      if(a.schedule is NotificationCalendar && a.content != null && a.content!.id != null && a.content!.payload != null/* && a.content!.payload!["type"] == "${NotificationType.alarm.index}"*/) {
        id = a.content!.id!;
        a.schedule!.timeZone = "UTC"; //bug in getNextDate?
        next = await AwesomeNotifications().getNextDate(a.schedule!, fixedDate: now);
      }
      if(id != null && next != null && (min == null || next.isBefore(min.$2))) {
        min = (id, next);
      }
    }
    return min == null? null : (min.$1, min.$2.difference(now));
  }


  @override Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, String?> originalPayload) async {
    if(snoozeDuration.inHours > 2) throw ArgumentError("You snooze you loose");

    Fluttertoast.showToast(msg: "Snoozed for ${snoozeDuration.inMinutes}m", toastLength: Toast.LENGTH_SHORT);

    //rescheduled notification (with different id, to not reset the actual schedule), will
    int rescheduledId = DeadlineAlarms.SNOOZE_OFFSET + DeadlineAlarms.toDeadlineId(originalId); //breaks coupling rule
    int ongoingId = DeadlineAlarms.SNOOZE_ONGOING_OFFSET + DeadlineAlarms.toDeadlineId(originalId); //breaks coupling rule
    Map<String, String?> newPayload = originalPayload;
    newPayload["ongoing-is-snoozed-notification-id"] = "$ongoingId";
    createNotification(
      rescheduledId, color, title, body,
      null, null, null, override: (DateTime.now().add(snoozeDuration), NotificationType.values[int.parse(originalPayload["type"]!)]),
      additionalPayload: originalPayload
    );

    //ongoing notification to stop the snooze
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        channelKey: _SNOOZE_CHANNEL_NAME,
        id: ongoingId, title: "Snoozed: $title",
        payload: {"snooze-id":"$rescheduledId"},
        category: NotificationCategory.Status,

        autoDismissible: false,
        criticalAlert: false, wakeUpScreen: false,
        locked: true, actionType: ActionType.KeepOnTop,
        backgroundColor: color,
        chronometer: Duration.zero,
        timeoutAfter: snoozeDuration,
      ),
      actionButtons: [
        NotificationActionButton(
            key: 'CANCEL-SNOOZE', label: 'Cancel Notification',
            actionType: ActionType.SilentBackgroundAction
        )
      ],
    );
  }



  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    debugPrint("========================================= onNotificationCreatedMethod: $receivedNotification");
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint("========================================= onDismissActionReceivedMethod: $receivedAction");
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    debugPrint("========================================= onNotificationDisplayedMethod: $receivedNotification");

    //problem: this is usually called after on-action when screen is off
    //         -> requires specialized, deeply coupled and hacky handling
    //  also: it sometimes is not... It is a fairly classic race condition in which both versions must be accounted for

    if(receivedNotification.payload != null && receivedNotification.payload!.containsKey("ongoing-is-snoozed-notification-id")) {
      int ongoingId = int.parse(receivedNotification.payload!["ongoing-is-snoozed-notification-id"]!);
      AwesomeNotifications().cancel(ongoingId);
    }

    bool wasInForeground = receivedNotification.displayedLifeCycle == NotificationLifeCycle.Foreground;

    int id = receivedNotification.id!;
    var notifyType = NotificationType.values[int.parse(receivedNotification.payload!["type"]!)];

    //todo, this should neither be done here nor like this probably... breaks coupling rule
    int dlId = DeadlineAlarms.toDeadlineId(id);
    if(dlId != -1 && id < DeadlineAlarms.SNOOZE_OFFSET && (notifyType == NotificationType.fullscreen || notifyType == NotificationType.alarm)) {
      var d = await DeadlinesDatabase().loadById(dlId);
      if (d != null) await DeadlineAlarms.updateAlarmsFor(d);
    }

    if(wasInForeground) {
      if(notifyType == NotificationType.fullscreen) {
        AwesomeNotifications().dismiss(id);
        MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/fullscreen',
          (route) => (route.settings.name != '/fullscreen') || route.isFirst,
          arguments: (receivedNotification.payload, wasInForeground)
        );
      } else if(notifyType == NotificationType.alarm) {
        AwesomeNotifications().dismiss(id);
        MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/alarm',
          (route) => (route.settings.name != '/alarm') || route.isFirst,
          arguments: (receivedNotification.payload, wasInForeground)
        );
      }
    } else {
      if (notifyType == NotificationType.alarm) {
        // if(! await AwesomeNotifications().isNotificationActiveOnStatusBar(id: id)) return;
        AwesomeNotifications().dismiss(id);
        await FlutterOverlayWindow.showOverlay(
          alignment: OverlayAlignment.center,
          height: 333,
          width: 888,
          overlayTitle: "deadlines alarm running",
          overlayContent: "check out the notification"
        );
        await FlutterOverlayWindow.shareData(receivedNotification.payload);
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint("========================================= onActionReceivedMethod: $receivedAction");

    int id = receivedAction.id!;

    //todo, this should neither be done here nor like this probably... breaks coupling rule
    int dlId = DeadlineAlarms.toDeadlineId(id);
    if(dlId != -1 && id < DeadlineAlarms.SNOOZE_OFFSET) {
      var d = await DeadlinesDatabase().loadById(dlId);
      if (d != null) await DeadlineAlarms.updateAlarmsFor(d);
    }

    if (receivedAction.buttonKeyPressed == "SNOOZE") {
      staticNotify.snooze(id, const Duration(minutes: 5), receivedAction.backgroundColor!, receivedAction.title!, receivedAction.body!, receivedAction.payload!);
    } else if(receivedAction.buttonKeyPressed == "CANCEL-SNOOZE") {
      int idOfScheduledSnooze = int.parse(receivedAction.payload!["snooze-id"]!);
      AwesomeNotifications().cancel(idOfScheduledSnooze);
    } else {
      var notifyType = NotificationType.values[int.parse(receivedAction.payload!["type"]!)];

      bool wasInForeground = receivedAction.actionLifeCycle == NotificationLifeCycle.Foreground;

      if (notifyType == NotificationType.fullscreen) {
        AwesomeNotifications().dismiss(id);
        MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/fullscreen',
          (route) => (route.settings.name != '/fullscreen') || route.isFirst,
          arguments: (receivedAction.payload, wasInForeground)
        );
      } else if (notifyType == NotificationType.alarm) {
        AwesomeNotifications().dismiss(id);
        MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/alarm',
          (route) => (route.settings.name != '/alarm') || route.isFirst,
          arguments: (receivedAction.payload, wasInForeground)
        );
      }
    }
  }




  /// additionalPayload overrides existing "id" or "type" if present
  static Future<bool> createNotification(int id, Color color, String title, String body, NotifyableRepeatableDateTime? at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop, {(DateTime, NotificationType)? override, Map<String, String?>? additionalPayload}) async {
    NotificationSchedule? schedule;
    NotificationType notifyType;
    if(override != null) {
      var (date, type) = override;
      notifyType = type;
      if(!date.isAfter(DateTime.now())) {
        schedule = null; //show right away
      } else {
        schedule = NotificationCalendar(
          timeZone: currentTimeZone,
          allowWhileIdle: true, preciseAlarm: true,

          year: date.year, month: date.month, day: date.day,
          hour: date.hour, minute: date.minute, second: date.second,
        );
      }
    } else if(at != null) {
      notifyType = at.notifyType;
      if(!at.date.isRepeating()) {
        schedule = NotificationCalendar(
          timeZone: currentTimeZone,
          allowWhileIdle: true, preciseAlarm: true,

          year: at.date.year, month: at.date.month, day: at.date.day,
          hour: at.time.hour, minute: at.time.minute,
          second: at.time.second, millisecond: 0,
        );
      } else {
        var now = DateTime.now();
        DateTime? atConcrete = at.nextOccurrenceAfter(now);
        while(atConcrete != null && (atConcrete.isBefore(now) || (shouldSkip != null && shouldSkip(atConcrete)))) {
          var n = at.nextOccurrenceAfter(atConcrete.add(const Duration(days: 1)));
          if(n != null && shouldStop != null && shouldStop(n)) {
            return false;
          }
          if(n == atConcrete) {
            print("bug here");
            atConcrete = null;
          } else {
            atConcrete = n;
          }
          print("atConcrete: $atConcrete");
        }
        if(atConcrete == null) return false;

        schedule = NotificationCalendar(
          timeZone: currentTimeZone,
          allowWhileIdle: true, preciseAlarm: true,

          year: atConcrete.year, month: atConcrete.month, day: atConcrete.day,
          hour: atConcrete.hour, minute: atConcrete.minute, second: atConcrete.second,
        );

        if (at.date.isYearly()) {
          // schedule = NotificationAndroidCrontab(
          //   allowWhileIdle: true, preciseAlarm: true, timeZone: currentTimeZone,
          //
          //   initialDateTime: atConcrete,
          //   repeats: true,
          //   crontabExpression: CronHelper().yearly(referenceDateTime: atConcrete),
          // );
          // schedule = NotificationCalendar(
          //   timeZone: currentTimeZone,
          //   allowWhileIdle: true,
          //   preciseAlarm: true,
          //
          //   repeats: true,
          //   month: atConcrete.month, day: atConcrete.day,
          //   hour: atConcrete.hour, minute: atConcrete.minute,
          //   second: atConcrete.second, millisecond: 0,
          // );
        } else if (at.date.isMonthly()) {
          // schedule = NotificationAndroidCrontab(
          //   allowWhileIdle: true, preciseAlarm: true, timeZone: currentTimeZone,
          //
          //   initialDateTime: atConcrete,
          //   repeats: true,
          //   crontabExpression: CronHelper().monthly(referenceDateTime: atConcrete),
          // );
          // schedule = NotificationCalendar(
          //   timeZone: currentTimeZone,
          //   allowWhileIdle: true,
          //   preciseAlarm: true,
          //
          //   repeats: true,
          //   day: atConcrete.day,
          //   hour: atConcrete.hour, minute: atConcrete.minute,
          //   second: atConcrete.second, millisecond: 0,
          // );
        } else if (at.date.isWeekly()) {
          // schedule = NotificationAndroidCrontab(
          //   allowWhileIdle: true, preciseAlarm: true, timeZone: currentTimeZone,
          //
          //   initialDateTime: atConcrete,
          //   repeats: true,
          //   crontabExpression: CronHelper().weekly(referenceDateTime: atConcrete),
          // );
          // schedule = NotificationCalendar(
          //   timeZone: currentTimeZone,
          //   allowWhileIdle: true,
          //   preciseAlarm: true,
          //
          //   repeats: true,
          //   weekday: atConcrete.weekday,
          //   hour: atConcrete.hour, minute: atConcrete.minute,
          //   second: atConcrete.second, millisecond: 0,
          // );
        } else if (at.date.isDaily()) {
          // schedule = NotificationAndroidCrontab(
          //   allowWhileIdle: true, preciseAlarm: true, timeZone: currentTimeZone,
          //
          //   initialDateTime: atConcrete,
          //   repeats: true,
          //   crontabExpression: CronHelper().daily(referenceDateTime: atConcrete),
          // );
          // schedule = NotificationCalendar(
          //   timeZone: currentTimeZone,
          //   allowWhileIdle: true,
          //   preciseAlarm: true,
          //
          //   repeats: true,
          //   hour: atConcrete.hour, minute: atConcrete.minute,
          //   second: atConcrete.second, millisecond: 0,
          // );
        }
      }
    } else {
      throw ArgumentError("at and it's override cannot both be null");
    }

    List<NotificationActionButton> actionButtons = [
      NotificationActionButton(
        key: 'SNOOZE', label: 'Snooze 5m',
        actionType: ActionType.SilentBackgroundAction,
      ),
      NotificationActionButton(
        key: 'DISMISS', label: 'Dismiss',
        actionType: at != null && at.date.isRepeating()? ActionType.SilentBackgroundAction : ActionType.DismissAction
      )
    ];

    Map<String, String?> payload = {"id":id.toString(), "type": "${notifyType.index}", "color":"${color.value}", "title": title, "body":body};
    if(additionalPayload != null) payload.addAll(additionalPayload);//overrides
    if(notifyType == NotificationType.silent) {
      await AwesomeNotifications().createNotification(
        schedule: schedule,
        content: NotificationContent(
          channelKey: _SILENT_CHANNEL_NAME,
          id: id, title: title, body: body,
          payload: payload, backgroundColor: color,
          category: NotificationCategory.Reminder,

          autoDismissible: false,
          criticalAlert: true, wakeUpScreen: true, locked: false,
        ),
        actionButtons: actionButtons,
      );
      return true;
    } else if(notifyType == NotificationType.normal) {
      await AwesomeNotifications().createNotification(
        schedule: schedule,
        content: NotificationContent(
          channelKey: _NORMAL_CHANNEL_NAME,
          id: id, title: title, body: body,
          payload: payload, backgroundColor: color,
          category: NotificationCategory.Reminder,

          autoDismissible: false,
          criticalAlert: true, wakeUpScreen: true, locked: false,
        ),
        actionButtons: actionButtons,
      );
      return true;
    } else if(notifyType == NotificationType.fullscreen) {
      await AwesomeNotifications().createNotification(
        schedule: schedule,
        content: NotificationContent(
          channelKey: _FULLSCREEN_CHANNEL_NAME,
          id: id, title: title, body: body,
          payload: payload, backgroundColor: color,
          category: NotificationCategory.Reminder,
          fullScreenIntent: true,

          autoDismissible: false,
          criticalAlert: true, wakeUpScreen: true, locked: true,
        ),
        actionButtons: actionButtons,
      );
      return true;
    } else if(notifyType == NotificationType.alarm) {
      await AwesomeNotifications().createNotification(
        schedule: schedule,
        content: NotificationContent(
          channelKey: _ALARM_CHANNEL_NAME,
          id: id, title: title, body: body,
          payload: payload, backgroundColor: color,
          category: NotificationCategory.Alarm,
          fullScreenIntent: true,

          autoDismissible: false,
          criticalAlert: true, wakeUpScreen: true, locked: true,
        ),
        actionButtons: actionButtons,
      );
      return true;
    }
    return false;
  }
}