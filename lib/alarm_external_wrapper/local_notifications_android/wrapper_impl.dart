// import 'dart:convert';
// import 'dart:typed_data';
//
// import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
// import 'package:deadlines/main.dart';
// import 'package:deadlines/persistence/database.dart';
// import 'package:deadlines/persistence/deadline_alarm_manager.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
//
// import '../model.dart';
//
//
// @pragma('vm:entry-point')
// void forBackgroundNotifies(NotificationResponse details) {
//   print("forBackgroundNotifies");
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
//   FlutterLocalNotificationsPlugin? plugin;
//   bool isInForeground = false;
//
//   @override Future<void> init() async {
//     super.init();
//
//     tz.initializeTimeZones();
//     // tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
//
//     plugin = FlutterLocalNotificationsPlugin();
//     try {
//       if (await plugin!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications() != true) {
//         await plugin!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
//       }
//     } catch (e) {
//       print(e);
//     }
//
//     const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notify_icon');
//     const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
//     var result = await plugin!.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (details) {
//         print("onDidReceiveNotificationResponse: $details");
//         onActionReceivedMethod(details);
//       },
//       onDidReceiveBackgroundNotificationResponse: forBackgroundNotifies,
//     );
//
//     if (result == true) {
//       plugin!.getNotificationAppLaunchDetails().then((details) {
//         if (details != null && details.notificationResponse != null) {
//           onActionReceivedMethod(details.notificationResponse!);
//         }
//       });
//     }
//   }
//
//
//
//   @override Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop) async {
//     var now = DateTime.now();
//     DateTime? atConcrete = at.nextOccurrenceAfter(now);
//     while(atConcrete != null && (atConcrete.isBefore(now) || (shouldSkip != null && shouldSkip(atConcrete)))) {
//       var n = at.nextOccurrenceAfter(atConcrete.add(const Duration(days: 1)));
//       if(n != null && shouldStop != null && shouldStop(n)) {
//         await cancel(notifyId);
//         return;
//       }
//       if(n == atConcrete) {
//         print("bug here");
//         atConcrete = null;
//       } else {
//         atConcrete = n;
//       }
//       print("atConcrete: $atConcrete");
//     }
//
//     if(at.notifyType == NotificationType.off || atConcrete == null) {
//       await cancel(notifyId);
//     } else {
//       createNotification(notifyId, color, title, description, at, shouldSkip, shouldStop);
//     }
//   }
//
//   @override Future<void> cancel(int notifyId) async {
//     await plugin!.cancel(notifyId);
//   }
//
//
//
//   @override Future<Duration> getDurationTo(int notifyId) async {
//     var notifyWithId = (await plugin!.pendingNotificationRequests()).where((e) => e.id == notifyId).firstOrNull;
//     AndroidFlutterLocalNotificationsPlugin? androidPlugin = plugin!.resolvePlatformSpecificImplementation();
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
//   Future<bool> createNotification(int id, Color color, String title, String body, NotifyableRepeatableDateTime? at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop, {(DateTime, NotificationType)? override, Map<String, dynamic>? additionalPayload}) async {
//     NotificationType? notifyType;
//     DateTime? atConcrete;
//
//     if(override != null) {
//       var (date, type) = override;
//       notifyType = type;
//       if(!date.isAfter(DateTime.now())) {
//         atConcrete = null; //show right away
//       } else {
//         atConcrete = date;
//       }
//     } else if(at != null) {
//       notifyType = at.notifyType;
//       if(!at.date.isRepeating()) {
//         atConcrete = at.toDateTime();
//       } else {
//         var now = DateTime.now();
//         atConcrete = at.nextOccurrenceAfter(now);
//         while(atConcrete != null && (atConcrete.isBefore(now) || (shouldSkip != null && shouldSkip(atConcrete)))) {
//           var n = at.nextOccurrenceAfter(atConcrete.add(const Duration(days: 1)));
//           if(n != null && shouldStop != null && shouldStop(n)) {
//             return false;
//           }
//           if(n == atConcrete) {
//             print("bug here");
//             atConcrete = null;
//           } else {
//             atConcrete = n;
//           }
//           print("atConcrete: $atConcrete");
//         }
//         if(atConcrete == null) return false;
//       }
//     } else {
//       throw ArgumentError("at and it's override cannot both be null");
//     }
//
//
//     NotificationDetails? details;
//     if(notifyType == NotificationType.silent) {
//       details = NotificationDetails(
//           android: AndroidNotificationDetails(
//               _SILENT_CHANNEL_NAME, _SILENT_CHANNEL_NAME,
//               channelDescription: _SILENT_CHANNEL_NAME,
//               category: AndroidNotificationCategory.reminder,
//               importance: Importance.high,
//               priority: Priority.defaultPriority,
//               ongoing: true,
//               fullScreenIntent: false,
//               onlyAlertOnce: false,
//               enableVibration: false,
//               color: color,
//               actions: [
//                 const AndroidNotificationAction("SNOOZE", 'Snooze 5m'),
//                 const AndroidNotificationAction("DISMISS", 'Dismiss'),
//               ]
//           ),
//           iOS: null, linux: null, macOS: null
//       );
//     }
//     if(notifyType == NotificationType.normal) {
//       details = NotificationDetails(
//           android: AndroidNotificationDetails(
//               _NORMAL_CHANNEL_NAME, _NORMAL_CHANNEL_NAME,
//               channelDescription: _NORMAL_CHANNEL_NAME,
//               category: AndroidNotificationCategory.reminder,
//               importance: Importance.high,
//               priority: Priority.defaultPriority,
//               ongoing: true,
//               fullScreenIntent: false,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList(
//                   [0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               actions: [
//                 const AndroidNotificationAction("SNOOZE", 'Snooze 5m'),
//                 const AndroidNotificationAction("DISMISS", 'Dismiss'),
//               ]
//           ),
//           iOS: null, linux: null, macOS: null
//       );
//     }
//     if(notifyType == NotificationType.fullscreen) {
//       details = NotificationDetails(
//           android: AndroidNotificationDetails(
//               _FULLSCREEN_CHANNEL_NAME, _FULLSCREEN_CHANNEL_NAME,
//               channelDescription: _FULLSCREEN_CHANNEL_NAME,
//               category: AndroidNotificationCategory.reminder,
//               audioAttributesUsage: AudioAttributesUsage.alarm,
//               importance: Importance.max,
//               priority: Priority.high,
//               ongoing: true,
//               fullScreenIntent: true,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList(
//                   [0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               actions: [
//                 const AndroidNotificationAction("SNOOZE", 'Snooze 5m'),
//                 const AndroidNotificationAction("DISMISS", 'Dismiss'),
//               ]
//           ),
//           iOS: null, linux: null, macOS: null
//       );
//     }
//     if(notifyType == NotificationType.alarm) {
//       details = NotificationDetails(
//           android: AndroidNotificationDetails(
//               _ALARM_CHANNEL_NAME, _ALARM_CHANNEL_NAME,
//               channelDescription: _ALARM_CHANNEL_NAME,
//               category: AndroidNotificationCategory.alarm,
//               audioAttributesUsage: AudioAttributesUsage.alarm,
//               importance: Importance.high,
//               priority: Priority.max,
//               ongoing: true,
//               fullScreenIntent: true,
//               onlyAlertOnce: false,
//               enableVibration: true,
//               vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200, 200]),
//               playSound: true,
//               color: color,
//               actions: [
//                 const AndroidNotificationAction("SNOOZE", 'Snooze 5m'),
//                 const AndroidNotificationAction("DISMISS", 'Dismiss'),
//               ]
//           ),
//           iOS: null, linux: null, macOS: null
//       );
//     }
//
//     Map<String, dynamic> payload = {
//       "id": id.toString(),
//       "type": notifyType.index.toString(),
//       "color": color.value.toString(),
//       "title": title,
//       "body": body,
//     };
//     if(additionalPayload != null) payload.addAll(additionalPayload);//overrides
//
//     if(atConcrete == null) {
//       plugin!.show(
//         id, title, body, details!,
//         payload: jsonEncode(payload)
//       );
//     } else {
//       plugin!.zonedSchedule(
//         id, title, body, tz.TZDateTime.from(atConcrete, tz.local), details!,
//         androidAllowWhileIdle: true,
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//         uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
//         payload: jsonEncode(payload)
//       );
//     }
//     return false;
//   }
//
//
//
//   Future<void> onActionReceivedMethod(NotificationResponse receivedAction) async {
//     if(plugin == null) await init();
//
//     debugPrint("========================================= onActionReceivedMethod: $receivedAction");
//     int id = receivedAction.id!;
//
//     var payload = jsonDecode(receivedAction.payload!);
//
//
//     var notifyType = NotificationType.values[int.parse(payload!["type"]!)];
//
//     try {
//       //todo, this should neither be done here nor like this probably... breaks coupling rule
//       int dlId = DeadlineAlarms.toDeadlineId(id);
//       if (dlId != -1 && id < DeadlineAlarms.SNOOZE_OFFSET && (notifyType == NotificationType.fullscreen || notifyType == NotificationType.alarm)) {
//         var d = await DeadlinesDatabase().loadById(dlId);
//         if (d != null) await DeadlineAlarms.updateAlarmsFor(d);
//       }
//     } catch (e) {
//       print(e);
//     }
//
//     if (receivedAction.payload != null && payload!.containsKey("ongoing-is-snoozed-notification-id")) {
//       int ongoingId = int.parse(payload!["ongoing-is-snoozed-notification-id"]!);
//       cancel(ongoingId);
//     }
//
//     if (receivedAction.actionId == "SNOOZE") {
//       snooze(int.parse(payload["id"]), const Duration(minutes: 5),
//           Color(int.parse(payload["color"]!)), payload["title"]!,
//           payload["body"]!, payload!
//       );
//     } else if (receivedAction.actionId == "CANCEL-SNOOZE") {
//       int idOfScheduledSnooze = int.parse(payload!["snooze-id"]!);
//       cancel(idOfScheduledSnooze);
//     } else {
//       if(payload["is-rescheduled"] != null) return;
//
//       if (notifyType == NotificationType.fullscreen) {
//         cancel(id);
//         MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//           '/fullscreen',
//           (route) => (route.settings.name != '/fullscreen') || route.isFirst,
//           arguments: (jsonDecode(receivedAction.payload!), isInForeground)
//         );
//       } else if (notifyType == NotificationType.alarm) {
//         cancel(id);
//         MainApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
//           '/alarm',
//           (route) => (route.settings.name != '/alarm') || route.isFirst,
//           arguments: (jsonDecode(receivedAction.payload!), isInForeground)
//         );
//       }
//     }
//   }
//
//
//
//
//   @override Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, dynamic> originalPayload) async {
//     if(snoozeDuration.inHours > 2) throw ArgumentError("You snooze you loose");
//
//     Fluttertoast.showToast(msg: "Snoozed for ${snoozeDuration.inMinutes}m", toastLength: Toast.LENGTH_SHORT);
//
//     //rescheduled notification (with different id, to not reset the actual schedule), will
//     int rescheduledId = DeadlineAlarms.SNOOZE_OFFSET + DeadlineAlarms.toDeadlineId(originalId); //breaks coupling rule
//     int ongoingId = DeadlineAlarms.SNOOZE_ONGOING_OFFSET + DeadlineAlarms.toDeadlineId(originalId); //breaks coupling rule
//     Map<String, dynamic> newPayload = originalPayload;
//     newPayload["snooze-id"] = "$rescheduledId";
//     newPayload["ongoing-is-snoozed-notification-id"] = "$ongoingId";
//     originalPayload.addAll({"is-rescheduled": "true"});
//     await createNotification(
//       rescheduledId, color, title, body,
//       null, null, null, override: (DateTime.now().add(snoozeDuration), NotificationType.values[int.parse(originalPayload["type"]!)]),
//       additionalPayload: originalPayload
//     );
//
//     //ongoing notification to stop the snooze
//     plugin!.show(ongoingId, "Snoozed: $title", "", NotificationDetails(
//       android: AndroidNotificationDetails(
//         _SNOOZE_CHANNEL_NAME, _SNOOZE_CHANNEL_NAME,
//         category: AndroidNotificationCategory.status,
//         autoCancel: false,
//         color: color,
//         usesChronometer: true,
//
//         timeoutAfter: snoozeDuration.inMilliseconds,
//         actions: [
//           const AndroidNotificationAction('CANCEL-SNOOZE', 'Cancel Notification')
//         ]
//       )
//     ), payload: jsonEncode(originalPayload));
//   }
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
