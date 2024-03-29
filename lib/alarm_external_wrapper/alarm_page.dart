import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:just_audio/just_audio.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:vibration/vibration.dart';

class AlarmNotificationScreen extends StatefulWidget {
  final Map<String, dynamic> notifyPayload;
  final bool wasInForeground;
  const AlarmNotificationScreen({super.key, required this.notifyPayload, required this.wasInForeground});

  @override State<AlarmNotificationScreen> createState() => _AlarmNotificationScreenState();
}

class _AlarmNotificationScreenState extends State<AlarmNotificationScreen> {
  late AudioPlayer audioPlayer;
  late Timer timeoutTimer;
  @override void initState() {
    super.initState();

    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        var pattern = [0, 1000, 500, 250, 250, 250, 1000];
        Vibration.vibrate(repeat: 1, pattern: pattern);
      }
    });

    audioPlayer = AudioPlayer();
    AudioSession.instance.then((session) async {
      session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          usage: AndroidAudioUsage.alarm,
        ),
      ));
      await audioPlayer.setAudioSource(AudioSource.asset("assets/ringtone_example.mp3"));
      await audioPlayer.setLoopMode(LoopMode.all);

      // //required, because overlay starts, because on-notification-displayed is called (and after on-notification-action), but before this (usually...)
      // await FlutterOverlayWindow.shareData("stop-music").then((_) { //does not stop vibrator
      //   FlutterOverlayWindow.closeOverlay(); //does not always seem to return when overlay not opened for some reason?
      // });

      audioPlayer.play(); //only returns when music is stopped...
    });

    timeoutTimer = Timer(const Duration(minutes: 5), () {
      audioPlayer.stop();
      Vibration.cancel();
    },);
  }

  @override void dispose() {
    Vibration.cancel();
    audioPlayer.stop();
    audioPlayer.dispose();
    timeoutTimer.cancel();

    super.dispose();
  }

  bool wasFinished = false;

  void snooze() {
    if(wasFinished) return;
    wasFinished = true;
    Vibration.cancel();
    audioPlayer.stop();

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
              const Icon(Icons.alarm, size: 100, color: const Color(0xFFF94144),),
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
                      audioPlayer.stop();

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