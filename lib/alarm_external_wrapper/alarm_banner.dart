// import 'dart:async';
// import 'package:audio_session/audio_session.dart';
// import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
// import 'package:deadlines/ui/widgets/card_in_list.dart';
// import 'package:deadlines/utils/utils.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:vibration/vibration.dart';
//
// class AlarmBanner extends StatefulWidget {
//   const AlarmBanner({super.key});
//   @override State<AlarmBanner> createState() => _AlarmBannerState();
// }
//
// class _AlarmBannerState extends State<AlarmBanner> {
//   late AudioPlayer audioPlayer;
//   Map<String, String?>? notifyPayload;
//   StreamSubscription? currentStreamSubscription;
//   @override void initState() {
//     super.initState();
//
//     audioPlayer = AudioPlayer();
//     AudioSession.instance.then((session) async {
//       session.configure(const AudioSessionConfiguration(
//         androidAudioAttributes: AndroidAudioAttributes(
//           usage: AndroidAudioUsage.alarm,
//         ),
//       ));
//       await audioPlayer.setAudioSource(AudioSource.asset("assets/alarm.mp3"));
//       await audioPlayer.setLoopMode(LoopMode.all);
//     });
//
//     currentStreamSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
//       print("FlutterOverlayWindow.overlayListener.event: $event");
//
//       setState(() {
//         if(event is Map<String, dynamic>) {
//           notifyPayload = event.map((key, value) => MapEntry(key, value?.toString()));
//           audioPlayer.play(); // do not wait, waits until audioPlayer is stopped...
//           Vibration.hasVibrator().then((hasVibrator) {
//             if (hasVibrator == true) {
//               var pattern = [0, 1000, 500, 250, 250, 250, 1000];
//               Vibration.vibrate(repeat: 1, pattern: pattern);
//             }
//           });
//         } else if(event.toString() == "stop-music") {
//           audioPlayer.stop();
//           notifyPayload = null;
//         } else {
//           Vibration.cancel();
//           audioPlayer.stop();
//           notifyPayload = null;
//         }
//       });
//     });
//   }
//
//   void snooze() {
//     if(notifyPayload == null) return;
//     Vibration.cancel();
//     audioPlayer.stop();
//     FlutterOverlayWindow.closeOverlay();
//
//     if(notifyPayload != null) {
//       int id = int.parse(notifyPayload!["id"]!);
//       Color color = notifyPayload!["color"] != null ? Color(int.parse(notifyPayload!["color"]!)) : Colors.black45;
//       String title = notifyPayload!["title"] != null ? notifyPayload!["title"]! : "ALARM";
//       String body = notifyPayload!["body"] != null ? notifyPayload!["body"]! : "NONE";
//       staticNotify.snooze(id, const Duration(minutes: 5), color, title, body, notifyPayload!);
//       notifyPayload = null;
//     }
//   }
//
//   @override void dispose() {
//     Vibration.cancel();
//     audioPlayer.stop();
//     audioPlayer.dispose();
//     currentStreamSubscription?.cancel();
//     currentStreamSubscription=null;
//     notifyPayload = null;
//
//     super.dispose();
//   }
//
//   @override Widget build(BuildContext context) {
//     Color color = notifyPayload != null && notifyPayload!["color"] != null ? Color(int.parse(notifyPayload!["color"]!)) : Colors.redAccent;
//     String title = notifyPayload != null && notifyPayload!["title"] != null ? notifyPayload!["title"]! : "ALARM";
//     String body = notifyPayload != null && notifyPayload!["body"] != null ? notifyPayload!["body"]! : "NONE";
//     return Stack(
//       children: [
//         Container(
//           alignment: Alignment.center,
//           decoration: ShapeDecoration(
//               color: Colors.black45.withOpacity(0.9),
//             shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   color: Colors.white,
//                   decoration: TextDecoration.none
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               CountingUpWidget(DateTime.now()),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     style: ButtonStyle(
//                       backgroundColor: MaterialStateColor.resolveWith((states) => darken(color, 20))
//                     ),
//                     onPressed: () {
//                       snooze();
//                     },
//                     child: const Text(
//                       "Snooze (5m)",
//                       style: TextStyle(color: Colors.white),
//                     )
//                   ),
//                   ElevatedButton(
//                     style: ButtonStyle(
//                       backgroundColor: MaterialStateColor.resolveWith((states) => darken(color, 20))
//                     ),
//                     onPressed: () {
//                       FlutterOverlayWindow.shareData("stop");
//                       FlutterOverlayWindow.closeOverlay();
//                     },
//                     child: const Text(
//                       "Stop",
//                       style: TextStyle(color: Colors.white),
//                     )
//                   ),
//                 ],
//               ),
//             ]
//           ),
//         ),
//         Positioned(
//           left: 44,
//           top: 11,
//           child: Icon(Icons.alarm, size: 44, color: color),
//         ),
//       ],
//     );
//   }
// }
//
//
//
// class CountingUpWidget extends StatefulWidget {
//   final DateTime startedAt;
//   const CountingUpWidget(this.startedAt, {super.key});
//
//   @override State<CountingUpWidget> createState() => _CountingUpWidgetState();
// }
//
// class _CountingUpWidgetState extends State<CountingUpWidget> {
//   late Timer timer;
//
//   @override void initState() {
//     super.initState();
//     timer = Timer.periodic(const Duration(milliseconds: 490), (_) {
//       setState(() {});
//     });
//   }
//
//   @override void dispose() {
//     timer.cancel();
//
//     super.dispose();
//   }
//
//   @override Widget build(BuildContext context) {
//     var diff = DateTime.now().difference(widget.startedAt);
//     var formated = "${pad0(diff.inHours)}:${pad0(diff.inMinutes.remainder(60))}:${pad0(diff.inSeconds.remainder(60))}";
//     return Text(
//       formated,
//       style: const TextStyle(
//         fontSize: 14,
//         color: Colors.white,
//         decoration: TextDecoration.none
//       ),
//       textAlign: TextAlign.center,
//     );
//   }
// }