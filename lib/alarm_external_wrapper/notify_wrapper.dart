import 'package:deadlines/alarm_external_wrapper/awesome_notifications_android/wrapper_impl.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:move_to_background/move_to_background.dart';

import 'alarm_page.dart';
import 'fullscreen_page.dart';
import 'local_notifications_android/wrapper_impl.dart';

import 'model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

// NotifyWrapper staticNotify = LocalNotificationsWrapper();
NotifyWrapper staticNotify = AwesomeNotificationsWrapper();


abstract class NotifyWrapper {
  Future<void> init() async {
    //must be before app lifecycle listener
    await FlutterOverlayWindow.isPermissionGranted().then((isPermissionGranted) async {
      if(!isPermissionGranted) {
        await FlutterOverlayWindow.requestPermission();
      }
    });

    AppLifecycleListener(
        onStateChange: (newState) {
          debugPrint("newState: $newState");
          // MoveToBackground.moveTaskToBack();
        },
        //enforce not shown on lock screen, by putting it to the back
        //   -> problem: gone when unlocked, but fml what can you do
        onPause: MoveToBackground.moveTaskToBack
    );

    FlutterOverlayWindow.closeOverlay();
  }

  Route<dynamic>? handleRoute(String? name, Object? arguments) {
    switch (name) {
      case '/fullscreen':
        return MaterialPageRoute(builder: (context) {
          final (notifyPayload, wasInForeground) = arguments as (Map<String, String?>, bool);
          return FullscreenNotificationScreen(notifyPayload: notifyPayload, wasInForeground: wasInForeground);
        });

      case '/alarm':
        return MaterialPageRoute(builder: (context) {
          final (notifyPayload, wasInForeground) = arguments as (Map<String, String?>, bool);
          return AlarmNotificationScreen(notifyPayload: notifyPayload, wasInForeground: wasInForeground);
        });
    }
    return null;
  }

  Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop);
  Future<void> cancel(int notifyId);
  Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, String?> originalPayload);


  Future<(int, Duration)?> getDurationToNextAlarm();
  Future<Duration> getDurationTo(int notifyId);
}