import 'package:move_to_background/move_to_background.dart';

import 'alarm_page.dart';
import 'awesome_notifications_android/wrapper_impl.dart';
import 'model.dart';
import 'package:flutter/material.dart';

// NotifyWrapper staticNotify = LocalNotificationsWrapper();
NotifyWrapper staticNotify = AwesomeNotificationsWrapper();


abstract class NotifyWrapper {
  static const int userNotificationMaxId = 200000000; //so that *10 is still < 2^31
  static const int snoozeOffset = userNotificationMaxId *2; //uses range [300000, 400000]
  static const int snoozeOngoingOffset = userNotificationMaxId * 4; //uses range [400000, 500000]
  static const int timerOffset = userNotificationMaxId * 10; //uses range [1000000, 1000006]

  Future<bool> init() async {
    AppLifecycleListener(
        onStateChange: (newState) {
          debugPrint("newState: $newState");
        },
        //enforce not shown on lock screen, by putting it to the back
        //   -> problem: gone when unlocked, but fml what can you do
        onPause: MoveToBackground.moveTaskToBack
    );

    return true;
  }

  final List<Function(int)> _notificationOccurredCallbacks = [];
  void registerNotificationOccurredCallback(Function(int) callback) {
    _notificationOccurredCallbacks.add(callback);
  }
  void notifyNotificationOccurred(int notifyId) {
    for (var callback in _notificationOccurredCallbacks) {callback(notifyId);}
  }

  Route<dynamic>? handleRoute(String? name, Object? arguments) {
    switch (name) {
      case '/fullscreen':
        return MaterialPageRoute(builder: (context) {
          final (notifyPayload, wasInForeground) = arguments as (Map<String, dynamic>, bool);
          return AlarmNotificationScreen(
            notifyPayload: notifyPayload, wasInForeground: wasInForeground,
            withAudio: false,
            repeatVibration: false,
            vibrationPattern: const [0, 200, 200, 200, 200, 400, 200]
          );
        });

      case '/alarm':
        return MaterialPageRoute(builder: (context) {
          final (notifyPayload, wasInForeground) = arguments as (Map<String, dynamic>, bool);
          return AlarmNotificationScreen(
            notifyPayload: notifyPayload, wasInForeground: wasInForeground,
            withAudio: true,
            repeatVibration: true,
            vibrationPattern: const [0, 1000, 500, 250, 250, 250, 1000],
          );
        });
    }
    return null;
  }

  Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop);
  Future<void> cancel(int notifyId);
  Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, dynamic> originalPayload);


  Future<(int, Duration)?> getDurationToNextAlarm();
  Future<(Duration, NotificationType)> getDurationTo(int notifyId);
}