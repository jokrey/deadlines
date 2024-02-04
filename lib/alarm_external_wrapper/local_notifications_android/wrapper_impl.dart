// import 'dart:typed_data';
//
// import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
//
// import '../model.dart';
//
//
// @pragma('vm:entry-point')
// void forBackgroundNotifies(NotificationResponse details) {
//   (staticNotify as LocalNotificationsWrapper).onActionReceivedMethod(details);
// }
//
// class LocalNotificationsWrapper extends NotifyWrapper {
//   static const String _SILENT_CHANNEL_NAME = "silent";
//   static const String _NORMAL_CHANNEL_NAME = "normal";
//   static const String _FULLSCREEN_CHANNEL_NAME = "fullscreen";
//   static const String _ALARM_CHANNEL_NAME = "alarm";
//   static const String _SNOOZE_CHANNEL_NAME = "snooze";
//
//   late FlutterLocalNotificationsPlugin plugin;
//   bool isInForeground = false;
//
//   @override Future<void> init() async {
//     super.init();
//
//     tz.initializeTimeZones();
//     tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
//
//     plugin = FlutterLocalNotificationsPlugin();
//     await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
//
//     const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notify_icon');
//     final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
//       //onDidReceiveLocalNotification: (id, title, body, payload) => onDidReceiveLocalNotificationIOS(context, id, title, body, payload),
//       requestAlertPermission: true,
//       requestSoundPermission: true,
//     );
//     const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(
//         defaultActionName: 'Open notification');
//     final InitializationSettings initializationSettings = InitializationSettings(
//         android: initializationSettingsAndroid,
//         iOS: initializationSettingsDarwin,
//         macOS: initializationSettingsDarwin,
//         linux: initializationSettingsLinux);
//     var result = await plugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (details) {
//         print("onDidReceiveNotificationResponse: $details");
//         onActionReceivedMethod(details);
//       },
//       onDidReceiveBackgroundNotificationResponse: forBackgroundNotifies,
//     );
//
//
//     if (result == true) {
//       plugin.getNotificationAppLaunchDetails().then((details) {
//         if (details != null && details.notificationResponse != null) {
//           onActionReceivedMethod(details.notificationResponse!);
//         }
//       });
//     }
//   }
//
//
//
//   @override Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at) async {
//     var atConcrete = at.buildNextNotificationTime(DateTime.now());
//     if(at.notifyType == NotificationType.off || atConcrete == null) {
//       await cancel(notifyId);
//     } else {
//       NotificationDetails? details;
//       if(at.notifyType == NotificationType.silent) {
//         details = NotificationDetails(
//             android: AndroidNotificationDetails(
//               _SILENT_CHANNEL_NAME, _SILENT_CHANNEL_NAME,
//               channelDescription: _SILENT_CHANNEL_NAME,
//               importance: Importance.high,
//               priority: Priority.defaultPriority,
//               ongoing: false,
//               fullScreenIntent: false,
//               onlyAlertOnce: false,
//               enableVibration: false,
//               color: color,
//               ledColor: color,
//               actions: [
//                 AndroidNotificationAction("SNOOZE", 'Snooze 5m',),
//                 AndroidNotificationAction("DISMISS", 'Dismiss',),
//               ]
//             ),
//             iOS: null, linux: null, macOS: null
//         );
//       }
//       if(at.notifyType == NotificationType.normal) {
//         details = NotificationDetails(
//             android: AndroidNotificationDetails(
//               _NORMAL_CHANNEL_NAME, _NORMAL_CHANNEL_NAME,
//               channelDescription: _NORMAL_CHANNEL_NAME,
//               importance: Importance.high,
//               priority: Priority.defaultPriority,
//               ongoing: false,
//               fullScreenIntent: false,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList(
//                   [0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               ledColor: color,
//               actions: [
//                 AndroidNotificationAction("SNOOZE", 'Snooze 5m',),
//                 AndroidNotificationAction("DISMISS", 'Dismiss',),
//               ]
//             ),
//             iOS: null, linux: null, macOS: null
//         );
//       }
//       if(at.notifyType == NotificationType.fullscreen) {
//         details = NotificationDetails(
//             android: AndroidNotificationDetails(
//               _FULLSCREEN_CHANNEL_NAME, _FULLSCREEN_CHANNEL_NAME,
//               channelDescription: _FULLSCREEN_CHANNEL_NAME,
//               importance: Importance.high,
//               priority: Priority.high,
//               ongoing: true,
//               fullScreenIntent: true,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList(
//                   [0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               ledColor: color,
//               actions: [
//                 AndroidNotificationAction("SNOOZE", 'Snooze 5m',),
//                 AndroidNotificationAction("DISMISS", 'Dismiss',),
//               ]
//             ),
//             iOS: null, linux: null, macOS: null
//         );
//       }
//       if(at.notifyType == NotificationType.alarm) {
//         details = NotificationDetails(
//             android: AndroidNotificationDetails(
//               _ALARM_CHANNEL_NAME, _ALARM_CHANNEL_NAME,
//               channelDescription: _ALARM_CHANNEL_NAME,
//               importance: Importance.high,
//               priority: Priority.high,
//               ongoing: true,
//               fullScreenIntent: true,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               ledColor: color,
//               actions: [
//                 AndroidNotificationAction("SNOOZE", 'Snooze 5m',),
//                 AndroidNotificationAction("DISMISS", 'Dismiss',),
//               ]
//             ),
//             iOS: null, linux: null, macOS: null
//         );
//       }
//
//       plugin.zonedSchedule(
//         notifyId, title, description, tz.TZDateTime.from(atConcrete, tz.local), details!,
//         uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime
//       );
//     }
//   }
//
//   @override Future<void> cancel(int notifyId) async {
//     await plugin.cancel(notifyId);
//   }
//
//   @override Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, String?> originalPayload) async {
//     // TODO: implement snooze
//   }
//
//
//
//   @override Future<Duration> getDurationTo(int notifyId) async {
//     var notifyWithId = (await plugin.pendingNotificationRequests()).where((e) => e.id == notifyId).firstOrNull;
//     AndroidFlutterLocalNotificationsPlugin? androidPlugin = plugin.resolvePlatformSpecificImplementation();
//     var c = await androidPlugin?.getNotificationChannels();
//
//     return Duration.zero;
//     // // print("notifyWithId: $notifyWithId");
//     // if(notifyWithId == null || notifyWithId.schedule == null) return Duration.zero;
//     // var now = DateTime.now();
//     // notifyWithId.schedule!.timeZone = currentTimeZone;
//     // notifyWithId.schedule!.timeZone = "UTC"; //bug in getNextDate?
//     // var notifyAt = await AwesomeNotifications().getNextDate(notifyWithId.schedule!, fixedDate: now);
//     // return notifyAt == null? Duration.zero : notifyAt.difference(now);
//   }
//
//   @override Future<(int, Duration)?> getDurationToNextAlarm() async {
//     return (0, Duration.zero);
//     // var all = await AwesomeNotifications().listScheduledNotifications();
//     // var now = DateTime.now();
//     // (int, DateTime)? min;
//     // for(var a in all) {
//     //   int? id;
//     //   DateTime? next;
//     //   if(a.schedule is NotificationCalendar && a.content != null && a.content!.id != null && a.content!.payload != null && a.content!.payload!["type"] == "${NotificationType.alarm.index}") {
//     //     id = a.content!.id!;
//     //     a.schedule!.timeZone = "UTC"; //bug in getNextDate?
//     //     next = await AwesomeNotifications().getNextDate(a.schedule!, fixedDate: now);
//     //   }
//     //   if(id != null && next != null && (min == null || next.isBefore(min.$2))) {
//     //     min = (id, next);
//     //   }
//     // }
//     // return min == null? null : (min.$1, min.$2.difference(now));
//   }
//
//
//
//
//   // Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
//   //   debugPrint("========================================= onNotificationDisplayedMethod: $receivedNotification");
//   //
//   //   //problem: this is usually called after on-action when screen is off
//   //   //         -> requires specialized, deeply coupled and hacky handling
//   //   //  also: it sometimes is not... It is a fairly classic race condition in which both versions must be accounted for
//   //
//   //   if(receivedNotification.payload != null && receivedNotification.payload!.containsKey("ongoing-is-snoozed-notification-id")) {
//   //     int ongoingId = int.parse(receivedNotification.payload!["ongoing-is-snoozed-notification-id"]!);
//   //     AwesomeNotifications().cancel(ongoingId);
//   //   }
//   //
//   //   bool wasInForeground = receivedNotification.displayedLifeCycle == NotificationLifeCycle.Foreground;
//   //
//   //   int id = receivedNotification.id!;
//   //   var notifyType = NotificationType.values[int.parse(receivedNotification.payload!["type"]!)];
//   //
//   //   if(wasInForeground) {
//   //     if(notifyType == NotificationType.fullscreen) {
//   //       plugin.cancel(id);
//   //       MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//   //           '/fullscreen',
//   //               (route) => (route.settings.name != '/fullscreen') || route.isFirst,
//   //           arguments: (receivedNotification.payload, wasInForeground)
//   //       );
//   //     } else if(notifyType == NotificationType.alarm) {
//   //       plugin.cancel(id);
//   //       MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//   //           '/alarm',
//   //               (route) => (route.settings.name != '/alarm') || route.isFirst,
//   //           arguments: (receivedNotification.payload, wasInForeground)
//   //       );
//   //     }
//   //   } else {
//   //     if (notifyType == NotificationType.alarm) {
//   //       plugin.cancel(id);
//   //       await FlutterOverlayWindow.showOverlay(
//   //           alignment: OverlayAlignment.center,
//   //           height: 333,
//   //           width: 888,
//   //           overlayTitle: "deadlines alarm running",
//   //           overlayContent: "check out the notification"
//   //       );
//   //       await FlutterOverlayWindow.shareData(receivedNotification.payload);
//   //     }
//   //   }
//   // }
//   //
//   // Future<void> onActionReceivedMethod(NotificationResponse receivedAction) async {
//   //   debugPrint("========================================= onActionReceivedMethod: $receivedAction");
//   //
//   //   if (receivedAction.actionId == "SNOOZE") {
//   //     snooze(const Duration(minutes: 5), receivedAction.backgroundColor!, receivedAction.title!, receivedAction.body!, receivedAction.payload!);
//   //   } else if(receivedAction.actionId == "CANCEL-SNOOZE") {
//   //     int idOfScheduledSnooze = int.parse(receivedAction.payload!["snooze-id"]!);
//   //     plugin.cancel(idOfScheduledSnooze);
//   //   }
//   //
//   //
//   //   int id = receivedAction.id!;
//   //   var notifyType = NotificationType.values[int.parse(receivedAction.payload!["type"])];
//   //
//   //   if (notifyType == NotificationType.fullscreen) {
//   //     plugin.cancel(id);
//   //     MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//   //         '/fullscreen',
//   //             (route) => (route.settings.name != '/fullscreen') || route.isFirst,
//   //         arguments: (receivedAction.payload, isInForeground)
//   //     );
//   //   } else if (notifyType == NotificationType.alarm) {
//   //     plugin.cancel(id);
//   //     MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//   //         '/alarm',
//   //             (route) => (route.settings.name != '/alarm') || route.isFirst,
//   //         arguments: (receivedAction.payload, isInForeground)
//   //     );
//   //   }
//   // }
//   //
//   //
//   //
//   //
//   // /// additionalPayload overrides existing "id" or "type" if present
//   // static Future<void> showNotification(int id, Color color, String title, String body, NotifyableRepeatableDateTime? at, {(DateTime, NotificationType)? override, Map<String, String?>? additionalPayload}) async {
//   //   NotificationSchedule? schedule;
//   //   NotificationType notifyType;
//   //   if(override != null) {
//   //     var (date, type) = override;
//   //     notifyType = type;
//   //     if(!date.isAfter(DateTime.now())) {
//   //       schedule = null; //show right away
//   //     } else {
//   //       schedule = NotificationCalendar(
//   //         timeZone: date.timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         year: date.year, month: date.month, day: date.day,
//   //         hour: date.hour, minute: date.minute, second: date.second,
//   //       );
//   //     }
//   //   } else if(at != null) {
//   //     notifyType = at.notifyType;
//   //     if(!at.date.isRepeating()) {
//   //       schedule = NotificationCalendar(
//   //         timeZone: DateTime.now().timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         year: at.date.year, month: at.date.month, day: at.date.day,
//   //         hour: at.time.hour, minute: at.time.minute,
//   //         second: 0, millisecond: 0,
//   //       );
//   //     } else if(at.date.isYearly()) {
//   //       schedule = NotificationCalendar(
//   //         timeZone: DateTime.now().timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         repeats: true,
//   //         month: at.date.month, day: at.date.day,
//   //         hour: at.time.hour, minute: at.time.minute,
//   //         second: 0, millisecond: 0,
//   //       );
//   //     } else if(at.date.isMonthly()) {
//   //       schedule = NotificationCalendar(
//   //         timeZone: DateTime.now().timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         repeats: true,
//   //         day: at.date.day,
//   //         hour: at.time.hour, minute: at.time.minute,
//   //         second: 0, millisecond: 0,
//   //       );
//   //     } else if(at.date.isWeekly()) {
//   //       schedule = NotificationCalendar(
//   //         timeZone: DateTime.now().timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         repeats: true,
//   //         weekday: at.date.toDateTime().weekday,
//   //         hour: at.time.hour, minute: at.time.minute,
//   //         second: 0, millisecond: 0,
//   //       );
//   //     } else if(at.date.isDaily()) {
//   //       schedule = NotificationCalendar(
//   //         timeZone: DateTime.now().timeZoneName,
//   //         allowWhileIdle: true, preciseAlarm: true,
//   //
//   //         repeats: true,
//   //         hour: at.time.hour, minute: at.time.minute,
//   //         second: 0, millisecond: 0,
//   //       );
//   //     }
//   //   } else {
//   //     throw ArgumentError("at and it's override cannot both be null");
//   //   }
//   //
//   //
//   //   Map<String, String?> payload = {"id":id.toString(), "type": "${notifyType.index}", "color":"${color.value}", "title": title, "body":body};
//   //   if(additionalPayload != null) payload.addAll(additionalPayload);//overrides
//   //   if(notifyType == NotificationType.silent) {
//   //     await AwesomeNotifications().createNotification(
//   //       schedule: schedule,
//   //       content: NotificationContent(
//   //         channelKey: _SILENT_CHANNEL_NAME,
//   //         id: id, title: title, body: body,
//   //         payload: payload, backgroundColor: color,
//   //         category: NotificationCategory.Reminder,
//   //
//   //         criticalAlert: true, wakeUpScreen: true,
//   //       ),
//   //       actionButtons: [
//   //         NotificationActionButton(
//   //           key: 'SNOOZE', label: 'Snooze 5m',
//   //           actionType: ActionType.DismissAction,
//   //         ),
//   //         NotificationActionButton(
//   //             key: 'DISMISS', label: 'Dismiss',
//   //             actionType: ActionType.DismissAction
//   //         )
//   //       ],
//   //     );
//   //   } else if(notifyType == NotificationType.normal) {
//   //     await AwesomeNotifications().createNotification(
//   //       schedule: schedule,
//   //       content: NotificationContent(
//   //         channelKey: _NORMAL_CHANNEL_NAME,
//   //         id: id, title: title, body: body,
//   //         payload: payload, backgroundColor: color,
//   //         category: NotificationCategory.Reminder,
//   //
//   //         criticalAlert: true, wakeUpScreen: true,
//   //       ),
//   //       actionButtons: [
//   //         NotificationActionButton(
//   //           key: 'SNOOZE', label: 'Snooze 5m',
//   //           actionType: ActionType.DismissAction,
//   //         ),
//   //         NotificationActionButton(
//   //             key: 'DISMISS', label: 'Dismiss',
//   //             actionType: ActionType.DismissAction
//   //         )
//   //       ],
//   //     );
//   //   } else if(notifyType == NotificationType.fullscreen) {
//   //     await AwesomeNotifications().createNotification(
//   //       schedule: schedule,
//   //       content: NotificationContent(
//   //         channelKey: _FULLSCREEN_CHANNEL_NAME,
//   //         id: id, title: title, body: body,
//   //         payload: payload, backgroundColor: color,
//   //         category: NotificationCategory.Reminder,
//   //         fullScreenIntent: true,
//   //
//   //         criticalAlert: true, wakeUpScreen: true,
//   //       ),
//   //       actionButtons: [
//   //         NotificationActionButton(
//   //           key: 'SNOOZE', label: 'Snooze 5m',
//   //           actionType: ActionType.DismissAction,
//   //         ),
//   //         NotificationActionButton(
//   //             key: 'DISMISS', label: 'Dismiss',
//   //             actionType: ActionType.DismissAction
//   //         )
//   //       ],
//   //     );
//   //   } else if(notifyType == NotificationType.alarm) {
//   //     await AwesomeNotifications().createNotification(
//   //       schedule: schedule,
//   //       content: NotificationContent(
//   //         channelKey: _ALARM_CHANNEL_NAME,
//   //         id: id, title: title, body: body,
//   //         payload: payload, backgroundColor: color,
//   //         category: NotificationCategory.Alarm,
//   //         fullScreenIntent: true,
//   //
//   //         criticalAlert: true, wakeUpScreen: true,
//   //       ),
//   //       actionButtons: [
//   //         NotificationActionButton(
//   //           key: 'SNOOZE', label: 'Snooze 5m',
//   //           actionType: ActionType.DismissAction,
//   //         ),
//   //         NotificationActionButton(
//   //             key: 'STOP', label: 'Stop',
//   //             actionType: ActionType.DismissAction
//   //         )
//   //       ],
//   //     );
//   //   }
//   // }
//
//
//
//
//
//   // static void snooze(Duration snoozeDuration, Color color, String title, String body, Map<String, String?> originalPayload) {
//   //   if(snoozeDuration.inHours > 2) throw ArgumentError("You snooze you loose");
//   //
//   //   Fluttertoast.showToast(msg: "Snoozed for ${snoozeDuration.inMinutes}m", toastLength: Toast.LENGTH_SHORT);
//   //
//   //   //rescheduled notification (with different id, to not reset the actual schedule), will
//   //   int rescheduledId = Random().nextInt(5000000) + 5000000; //todo be better
//   //   int ongoingId = rescheduledId + 1;
//   //   Map<String, String?> newPayload = originalPayload;
//   //   newPayload["ongoing-is-snoozed-notification-id"] = "$ongoingId";
//   //   showNotification(
//   //       rescheduledId, color, title, body,
//   //       null, override: (DateTime.now().add(snoozeDuration), NotificationType.values[int.parse(originalPayload["type"]!)]),
//   //       additionalPayload: originalPayload
//   //   );
//   //
//   //   //ongoing notification to stop the snooze
//   //   AwesomeNotifications().createNotification(
//   //     content: NotificationContent(
//   //         channelKey: _SNOOZE_CHANNEL_NAME,
//   //         id: ongoingId, title: "Snoozed: $title",
//   //         payload: {"snooze-id":"$rescheduledId"},
//   //         category: NotificationCategory.Status,
//   //
//   //         criticalAlert: false, wakeUpScreen: false,
//   //         locked: true, actionType: ActionType.KeepOnTop,
//   //         backgroundColor: color
//   //     ),
//   //     actionButtons: [
//   //       NotificationActionButton(
//   //           key: 'CANCEL-SNOOZE', label: 'Cancel Notification',
//   //           actionType: ActionType.DismissAction
//   //       )
//   //     ],
//   //   );
//   // }
// }
//
//
//
//
//
//
//
//
// // import 'package:flutter/cupertino.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/widgets.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// // import 'package:timezone/data/latest_all.dart' as tz;
// // import 'package:timezone/timezone.dart' as tz;
// //
// // @pragma('vm:entry-point')
// // void forBackgroundNotifies(NotificationResponse details) {
// //   print("onDidReceiveBackgroundNotificationResponse: ${details.id}");
// // }
// //
// // class Notify {
// //   static FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
// //   static bool isInitialized() => flutterLocalNotificationsPlugin != null;
// //
// //   static Future<bool?> initAll(Function(int, bool) notificationClicked) async{
// //     tz.initializeTimeZones();
// //     tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
// //
// //     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// //     await flutterLocalNotificationsPlugin!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
// //
// //     const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notify_icon');
// //     final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
// //       //onDidReceiveLocalNotification: (id, title, body, payload) => onDidReceiveLocalNotificationIOS(context, id, title, body, payload),
// //       requestAlertPermission: true,
// //       requestSoundPermission: true,
// //     );
// //     const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open notification');
// //     final InitializationSettings initializationSettings = InitializationSettings(
// //         android: initializationSettingsAndroid,
// //         iOS: initializationSettingsDarwin,
// //         macOS: initializationSettingsDarwin,
// //         linux: initializationSettingsLinux);
// //     var result = await flutterLocalNotificationsPlugin!.initialize(
// //       initializationSettings,
// //       onDidReceiveNotificationResponse: (details) {
// //         print("onDidReceiveNotificationResponse: $details");
// //         notificationClicked(details.id!, false);
// //       },
// //       onDidReceiveBackgroundNotificationResponse: forBackgroundNotifies,
// //     );
// //     if(result == true) {
// //       Notify.flutterLocalNotificationsPlugin!.getNotificationAppLaunchDetails().then((details) {
// //         print("app launch details: ${details?.notificationResponse?.id}");
// //         if(details != null && details.didNotificationLaunchApp) {
// //           notificationClicked(details.notificationResponse!.id!, true);
// //         }
// //       });
// //     }
// //     return result;
// //   }
// //
// //   static const _silentDetails = NotificationDetails(
// //       android: AndroidNotificationDetails(
// //         'silent', 'silent',
// //         channelDescription: 'show silent notifications',
// //         importance: Importance.high,
// //         priority: Priority.high,
// //         fullScreenIntent: false,
// //         onlyAlertOnce: false,
// //         enableVibration: false,
// //       ),
// //       iOS: null,
// //       linux: null,
// //       macOS: null
// //   );
// //
// //   static Future<void> cancel(int id) async {
// //     print("notify.cancel $id");
// //     flutterLocalNotificationsPlugin!.cancel(id);
// //   }
// //
// //   static Future<void> notify(int id, String title, String body, [NotificationDetails? details]) async {
// //     print("notify.notify $id");
// //     await flutterLocalNotificationsPlugin!.show(
// //       id, title, body, details?? _silentDetails
// //     );
// //   }
// //
// //   static Future<void> notifyLater(int id, String title, String body, DateTime at, [NotificationDetails? details]) {
// //     print("notify.notifyLater $id");
// //     return flutterLocalNotificationsPlugin!.zonedSchedule(
// //         id, title, body,
// //         tz.TZDateTime.from(at, tz.local),
// //         details?? _silentDetails,
// //         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
// //         uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime
// //     );
// //   }
// //   static Future<void> notifyPeriodically(int id, String title, String body, RepeatInterval interval, [NotificationDetails? details]) {
// //     print("notify.notifyPeriodically $id");
// //     return flutterLocalNotificationsPlugin!.periodicallyShow(
// //       id, title, body, interval, details?? _silentDetails,
// //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
// //     );
// //   }
// //
// //   //iOS only (untested):
// //   static void onDidReceiveLocalNotificationIOS(BuildContext context, int id, String? title, String? body, String? payload) async {
// //     print("onDidReceiveLocalNotification");
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) => CupertinoAlertDialog(
// //         title: Text(title!),
// //         content: Text(body!),
// //         actions: [
// //           CupertinoDialogAction(
// //             isDefaultAction: true,
// //             child: const Text('Ok'),
// //             onPressed: () async {
// //               Navigator.of(context, rootNavigator: true).pop();
// //               print("do something");
// //             },
// //           )
// //         ],
// //       ),
// //     );
// //   }
// // }
