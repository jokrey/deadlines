import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:deadlines/ui/defaults.dart';
import '../alarm_page.dart';
import '../model.dart';
import '../notify_wrapper.dart';
import 'wrapper_impl.dart';
import 'package:flutter/material.dart';
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmNotificationScreen(
                        notifyPayload: {"title":"Test Title", "body": "Bla Bla Bla\nwhats up?\nI have absolutely not idea what you are talking about", "color": "${colors[3].value}"}, wasInForeground: true, withAudio: true, repeatVibration: true, vibrationPattern: [0, 1000, 1000, 1000, 1000],)));
                  },
                  child: const Text("alarm screen")
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmNotificationScreen(notifyPayload: {"title":"Test Title", "body": "", "color": "${colors[0].value}"}, wasInForeground: true, withAudio: false, repeatVibration: false, vibrationPattern: [0, 1000, 1000, 1000, 1000])));
                  },
                  child: const Text("fullscreen screen")
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
                    var in5Seconds = now.add(const Duration(seconds: 5));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in5Seconds, NotificationType.silent),
                    );
                  },
                  child: const Text("silent in 5 seconds")
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
                    var in5Seconds = now.add(const Duration(seconds: 5));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in5Seconds, NotificationType.normal),
                    );
                  },
                  child: const Text("normal in 5 seconds")
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
                    var in5Seconds = now.add(const Duration(seconds: 5));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                        null, null, null, override: (in5Seconds, NotificationType.fullscreen),
                    );
                  },
                  child: const Text("fullscreen in 5 seconds")
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
                    var in5Seconds = now.add(const Duration(seconds: 5));

                    AwesomeNotificationsWrapper.createNotification(
                      Random().nextInt(100000), Colors.blue, "title", "body",
                      null, null, null, override: (in5Seconds, NotificationType.alarm),
                    );
                  },
                  child: const Text("alarm in 5 seconds")
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

                  await audioPlayer.setAudioSource(AudioSource.asset("assets/alarm.mp3"));
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

