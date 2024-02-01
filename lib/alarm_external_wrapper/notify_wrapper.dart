import 'awesome_notifications_android/wrapper_impl.dart';
import 'model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

NotifyWrapper staticNotify = AwesomeNotificationsWrapper();


abstract class NotifyWrapper {
  Future<void> init();
  Future<void> cancel(int notifyId);
  Future<void> set(int notifyId, Color color, String title, String description, NotifyableRepeatableDateTime at);
  Future<(int, Duration)?> getDurationToNextAlarm();
  Future<Duration> getDurationTo(int notifyId);
  Route<dynamic>? handleRoute(String? name, Object? arguments);
}