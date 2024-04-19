import 'package:move_to_background/move_to_background.dart';

import 'alarm_page.dart';
import 'awesome_notifications_android/wrapper_impl.dart';
import 'model.dart';
import 'package:flutter/material.dart';

/// static instance to access notification wrapper
NotifyWrapper staticNotify = AwesomeNotificationsWrapper();
// NotifyWrapper staticNotify = LocalNotificationsWrapper();

/// Abstract wrapper of necessary Notification functionality (regardless of concrete backend implementation)
abstract class NotifyWrapper {
  static const int userNotificationMaxId = 200000000; //so that *10 is still < 2^31
  static const int snoozeOffset = userNotificationMaxId *2;
  static const int snoozeOngoingOffset = userNotificationMaxId * 4;
  static const int timerOffset = userNotificationMaxId * 10;

  /// initialise the notification functionality, called before app ui first shown
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
  /// register a callback for when a notification is called (shown or on action)
  /// Callback receives the raw notification id (passed to set)
  void registerNotificationOccurredCallback(Function(int) callback) {
    _notificationOccurredCallbacks.add(callback);
  }
  void notifyNotificationOccurred(int notifyId) {
    for (var callback in _notificationOccurredCallbacks) {callback(notifyId);}
  }

  /// called by main app route handler first, so can, but should not override other app routes
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

  /// will set an alarm with the specified id, color, title, description
  /// uses "at" to determine next occurrence, notify type and repetition
  /// implementing classes must ensure that the notification is shown repeatedly in the specified interval
  /// shouldSkip and shouldStop can be used to additionally skip repetition cycles or stop forever
  Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at, bool Function(DateTime)? shouldSkip, bool Function(DateTime)? shouldStop);
  /// implementing classes must ensure the notification with the specified id will never be shown
  Future<void> cancel(int notifyId);
  /// will set an alarm that shows the previous notification again after the specified snoozeDuration
  Future<void> snooze(int originalId, Duration snoozeDuration, Color color, String title, String body, Map<String, dynamic> originalPayload);

  /// Returns the id and duration to the next notification that will be displayed
  Future<(int, Duration)?> getDurationToNextAlarm();
  /// Return the duration and notification type of the notification with the specified id
  Future<(Duration, NotificationType)> getDurationTo(int notifyId);
}