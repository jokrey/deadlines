import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:deadlines/alarm_external_wrapper/alarm_page.dart';
import 'package:deadlines/alarm_external_wrapper/fullscreen_page.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import '../model.dart';
import 'wrapper_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';




class TestAlarmsScreen extends StatefulWidget {
  const TestAlarmsScreen({super.key});

  @override State<TestAlarmsScreen> createState() => _TestAlarmsScreenState();
}

class _TestAlarmsScreenState extends State<TestAlarmsScreen> {
  var audioPlayer = AudioPlayer();

  @override void dispose() {
    Vibration.cancel();
    audioPlayer.dispose();

    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AlarmNotificationScreen(notifyPayload: {}, wasInForeground: true)));
                  },
                  child: const Text("alarm screen")
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FullscreenNotificationScreen(notifyPayload: {"body": "VERY LONG TEXT, WHICH SHALL BE WRAPPED AFTER A WHILE, NO?"}, wasInForeground: true)));
                  },
                  child: const Text("fullscreen screen")
                ),
                TextButton(
                  onPressed: () async {
                    await FlutterOverlayWindow.showOverlay(
                        alignment: OverlayAlignment.center,
                        height: 333,
                        width: 888,
                        overlayTitle: "deadlines alarm running",
                        overlayContent: "check out the notification"
                    );
                    await FlutterOverlayWindow.shareData({
                      "color": "${Colors.deepPurple.value}"
                    });

                    // /// broadcast data to and from overlay app
                    // await FlutterOverlayWindow.shareData("Hello from the other side");
                    //
                    // /// streams message shared between overlay and main app
                    // FlutterOverlayWindow.overlayListener.listen((event) {
                    //   log("Current Event: $event");
                    // });
                  },
                  child: const Text("alarm overlay")
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (DateTime.now(), NotificationType.silent),
                    );
                  },
                  child: const Text("silent now")
                ),
                TextButton(
                  onPressed: () {
                    var now = DateTime.now();
                    var in10Seconds = now.add(const Duration(seconds: 10));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in10Seconds, NotificationType.silent),
                    );
                  },
                  child: const Text("silent in 10 seconds")
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (DateTime.now(), NotificationType.normal),
                    );
                  },
                  child: const Text("normal now")
                ),
                TextButton(
                  onPressed: () {
                    var now = DateTime.now();
                    var in10Seconds = now.add(const Duration(seconds: 10));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in10Seconds, NotificationType.normal),
                    );
                  },
                  child: const Text("normal in 10 seconds")
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (DateTime.now(), NotificationType.fullscreen),
                    );
                  },
                  child: const Text("fullscreen now")
                ),
                TextButton(
                  onPressed: () {
                    var now = DateTime.now();
                    var in10Seconds = now.add(const Duration(seconds: 10));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                        null, null, null, override: (in10Seconds, NotificationType.fullscreen),
                    );
                  },
                  child: const Text("fullscreen in 10 seconds")
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (DateTime.now(), NotificationType.alarm),
                    );
                  },
                  child: const Text("alarm now")
                ),
                TextButton(
                  onPressed: () {
                    var now = DateTime.now();
                    var in10Seconds = now.add(const Duration(seconds: 10));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in10Seconds, NotificationType.alarm),
                    );
                  },
                  child: const Text("alarm in 10 seconds")
                ),
              ],
            ),



            TextButton(
                onPressed: () async {
                  final session = await AudioSession.instance;
                  await session.configure(const AudioSessionConfiguration(
                    androidAudioAttributes: AndroidAudioAttributes(
                      usage: AndroidAudioUsage.alarm,//!!!!!!!!!!!!!
                    ),
                  ));

                  await audioPlayer.setAudioSource(AudioSource.asset("assets/ringtone_example.mp3"));
                  await audioPlayer.setLoopMode(LoopMode.all);
                  audioPlayer.play();
                },
                child: const Text("Test Alarm Sound")
            ),
            TextButton(
                onPressed: () {
                  Vibration.hasVibrator().then((hasVibrator) {
                    if (hasVibrator == true) {
                      var pattern = [0, 1000, 500, 250, 250, 250, 1000];
                      Vibration.vibrate(repeat: 1, pattern: pattern);
                    }
                  });
                },
                child: const Text("Test Vibrator")
            ),
            TextButton(
              onPressed: () {
                Vibration.hasVibrator().then((hasVibrator) {
                  if (hasVibrator == true) {
                    Vibration.cancel();
                  }
                });
                audioPlayer.stop();
                FlutterOverlayWindow.shareData("stop");
                FlutterOverlayWindow.closeOverlay();
                staticNotify.cancel(1);
              },
              child: const Text("Cancel All")
            ),
          ],
        ),
      ),
    );
  }
}

