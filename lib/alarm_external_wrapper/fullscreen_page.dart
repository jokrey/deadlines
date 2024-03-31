
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:flutter/material.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:slidable_button/slidable_button.dart';
import 'package:vibration/vibration.dart';

class FullscreenNotificationScreen extends StatefulWidget {
  final Map<String, dynamic> notifyPayload;
  final bool wasInForeground;
  const FullscreenNotificationScreen({super.key, required this.notifyPayload, required this.wasInForeground});

  @override State<FullscreenNotificationScreen> createState() => _FullscreenNotificationScreenState();
}

class _FullscreenNotificationScreenState extends State<FullscreenNotificationScreen> {
  @override void initState() {
    super.initState();

    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        var pattern = [0, 200, 200, 200, 200, 400, 200];
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

    var maxWidth = MediaQuery.of(context).size.width;
    var maxHeight = MediaQuery.of(context).size.height;
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        snooze();

        if (!widget.wasInForeground) MoveToBackground.moveTaskToBack();
      },
      child: Scaffold(
        backgroundColor: color,
        body: SafeArea(
          minimum: EdgeInsets.only(top: maxHeight / 9, bottom: maxHeight / 9 / 2),
          child: Stack(
            children: [
              Center(child: Icon(Icons.event_available_rounded, size: maxHeight / 4, color: const Color(0xFFF94144),)),

              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: getForegroundForColor(color)),
                      softWrap: true,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                    SizedBox(height: maxHeight / 9 / 2,),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: getForegroundForColor(color)?.withAlpha(180)),
                      softWrap: true,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: HorizontalSlidableButton(
                  width: double.maxFinite,
                  height: maxHeight / 9,
                  buttonWidth: maxWidth / 3,
                  color: getForegroundForColor(color),
                  buttonColor: color,
                  dismissible: false,
                  centerPoint: true,
                  autoSlide: true,
                  initialPosition: SlidableButtonPosition.center,
                  label:  GestureDetector(
                    onTap: () {
                      Vibration.cancel();
                    },
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.flip(
                              flipX: true,
                              child:Icon(
                                Icons.double_arrow_rounded,
                                size: maxHeight / 9 / 3,
                                color: getForegroundForColor(color),
                              )
                          ),
                          Icon(
                            Icons.snooze_rounded,
                            size: maxHeight / 9 / 3 / 2,
                            color: getForegroundForColor(color),
                          ),
                          Icon(
                            Icons.double_arrow_rounded,
                            size: maxHeight / 9 / 3,
                            color: getForegroundForColor(color),
                          ),
                        ]
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'snooze for five',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
                        ),
                        Text(
                          'dismiss forever',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (position) {
                    setState(() {
                      if(position == SlidableButtonPosition.start) {
                        snooze();

                        Navigator.pop(context);
                      } else if(position == SlidableButtonPosition.end) {
                        wasFinished = true;
                        Vibration.cancel();

                        Navigator.pop(context);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}