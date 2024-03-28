import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:vibration/vibration.dart';

class FullscreenNotificationScreen extends StatefulWidget {
  final Map<String, String?> notifyPayload;
  final bool wasInForeground;
  const FullscreenNotificationScreen({super.key, required this.notifyPayload, required this.wasInForeground});

  @override State<FullscreenNotificationScreen> createState() => _FullscreenNotificationScreenState();
}

class _FullscreenNotificationScreenState extends State<FullscreenNotificationScreen> {
  @override void initState() {
    super.initState();

    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        var pattern = [0, 200, 200, 200, 200, 200, 200];
        Vibration.vibrate(pattern: pattern);
      }
    });
  }

  @override void dispose() {
    Vibration.cancel();

    super.dispose();
  }

  bool wasFinished = false;

  void snooze() {
    if(wasFinished) return;
    wasFinished = true;
    Vibration.cancel();

    int id = int.parse(widget.notifyPayload["id"]!);
    Color color = widget.notifyPayload["color"] != null ? Color(int.parse(widget.notifyPayload["color"]!)) : Colors.black45;
    String title = widget.notifyPayload["title"] != null ? widget.notifyPayload["title"]! : "ALARM";
    String body = widget.notifyPayload["body"] != null ? widget.notifyPayload["body"]! : "NONE";
    staticNotify.snooze(id, const Duration(minutes: 5), color, title, body, widget.notifyPayload);
  }

  @override Widget build(BuildContext context) {
    Color color = widget.notifyPayload["color"] != null ? Color(int.parse(widget.notifyPayload["color"]!)) : Colors.black45;
    String title = widget.notifyPayload["title"] != null ? widget.notifyPayload["title"]! : "ALARM";
    String body = widget.notifyPayload["body"] != null ? widget.notifyPayload["body"]! : "NONE";
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        snooze();

        if (!widget.wasInForeground) MoveToBackground.moveTaskToBack();
      },
      child: Scaffold(
        backgroundColor: color,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
              Text(
                body,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
              const Icon(Icons.alarm, size: 100),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  RawMaterialButton(
                    onPressed: () {
                      snooze();

                      Navigator.pop(context);
                    },
                    child: Text(
                      "Snooze (5m)",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  RawMaterialButton(
                    onPressed: () {
                      wasFinished = true;
                      Vibration.cancel();

                      Navigator.pop(context);
                    },
                    child: Text(
                      "Stop",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}