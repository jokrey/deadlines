import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:confetti/confetti.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:deadlines/utils/size_conditional_text.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:slidable_button/slidable_button.dart';
import 'package:vibration/vibration.dart';

class AlarmNotificationScreen extends StatefulWidget {
  final Map<String, dynamic> notifyPayload;
  final bool wasInForeground;
  final bool withAudio;
  final bool repeatVibration;
  final List<int> vibrationPattern;
  const AlarmNotificationScreen({super.key, required this.notifyPayload, required this.wasInForeground, required this.withAudio, required this.repeatVibration, required this.vibrationPattern});

  @override State<AlarmNotificationScreen> createState() => _AlarmNotificationScreenState();
}

class _AlarmNotificationScreenState extends State<AlarmNotificationScreen> {
  AudioPlayer? audioPlayer;
  Timer? timeoutTimer;
  late ConfettiController _confettiController;
  late FixedExtentScrollController _snoozeDurationScrollController;

  int snoozeForMinutes = 5;
  int lastValue = 5;
  @override void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 10));
    _confettiController.play();

    _snoozeDurationScrollController = FixedExtentScrollController(initialItem: snoozeForMinutes);
    _snoozeDurationScrollController.addListener(() {
      setState(() {
        var newValue = _snoozeDurationScrollController.selectedItem;
        int delta = newValue - lastValue;
        lastValue = newValue;
        if(delta != 0) {
          snoozeForMinutes = min(60, max(1, snoozeForMinutes + delta));
        }
      });
    });

    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(repeat: widget.repeatVibration? 1 : -1, pattern: widget.vibrationPattern);
      }
    });

    if(widget.withAudio) {
      audioPlayer = AudioPlayer();
      AudioSession.instance.then((session) async {
        session.configure(const AudioSessionConfiguration(
          androidAudioAttributes: AndroidAudioAttributes(
            usage: AndroidAudioUsage.alarm,
          ),
        ));
        await audioPlayer!.setAudioSource(AudioSource.asset("assets/alarm.mp3"));
        await audioPlayer!.setLoopMode(LoopMode.all);

        await audioPlayer!.seek(const Duration(seconds: 4));
        await audioPlayer!.play(); //only returns when music is stopped...
      });
    }

    if(widget.withAudio || widget.repeatVibration) {
      timeoutTimer = Timer(const Duration(minutes: 5), () {
        audioPlayer?.stop();
        Vibration.cancel();
      },);
    }
  }

  @override void dispose() {
    Vibration.cancel();
    audioPlayer?.stop();
    audioPlayer?.dispose();
    timeoutTimer?.cancel();
    _confettiController.dispose();

    super.dispose();
  }

  bool wasFinished = false;

  Future<void> snooze() async {
    if(wasFinished) return;
    wasFinished = true;
    await Vibration.cancel();
    await audioPlayer?.stop();

    int id = int.parse(widget.notifyPayload["id"]!);
    Color color = widget.notifyPayload["color"] != null ? Color(int.parse(widget.notifyPayload["color"]!)) : Colors.black45;
    String title = widget.notifyPayload["title"] != null ? widget.notifyPayload["title"]! : "ALARM";
    String body = widget.notifyPayload["body"] != null ? widget.notifyPayload["body"]! : "NONE";
    await staticNotify.snooze(id, Duration(minutes: snoozeForMinutes), color, title, body, widget.notifyPayload);
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
          minimum: EdgeInsets.only(top: maxHeight / 9),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  colors: colors,
                  shouldLoop: true,

                  maxBlastForce: 33,
                  minBlastForce: 11,
                  emissionFrequency: widget.repeatVibration ? 0.04 : 0.03,
                  numberOfParticles: widget.withAudio ? 22 : 11,
                  gravity: 0.1,
                ),
              ),

              Center(child: Icon(widget.withAudio? Icons.alarm_rounded : Icons.event_available_rounded, size: maxHeight / 4, color: const Color(0xFFF94144),)),

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
                child: Container(
                  height: maxHeight / 9 / 2,
                  padding: EdgeInsets.only(bottom: maxHeight / 9 / 2 / 8),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: ListWheelScrollView.useDelegate(
                      perspective: 0.01,
                      squeeze: 1,
                      controller: _snoozeDurationScrollController,
                      physics: const FixedExtentScrollPhysics(),
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: <Widget>[
                          const RotatedBox(quarterTurns: 1, child: Text("|", textAlign: TextAlign.center),),
                        ]
                      ),
                      useMagnifier: true,
                      magnification: 1,
                      itemExtent: maxHeight / 9 / 2 / 2,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: maxHeight / 9 / 2),
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
                        audioPlayer?.stop();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.keyboard_double_arrow_left_rounded,
                            size: maxHeight / 9 / 3,
                            color: getForegroundForColor(color),
                          ),
                        ]+(widget.withAudio || widget.repeatVibration?[
                          Icon(
                            Icons.snooze_rounded,
                            size: maxHeight / 9 / 3 / 2,
                            color: getForegroundForColor(color),
                          ),
                        ]:[])+[
                          Icon(
                            Icons.keyboard_double_arrow_right_rounded,
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
                          WidthConditionalText(
                            text: 'snooze for ${convert0To99ToText(snoozeForMinutes)}',
                            otherText: 'snooze for\n    ${convert0To99ToText(snoozeForMinutes)}',
                            switchWidth: maxWidth / 3 - 13,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color,),
                          ),
                          Text(
                            'dismiss forever',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
                          ),
                        ],
                      ),
                    ),
                    onChanged: (position) async {
                      if(position == SlidableButtonPosition.start) {
                        await snooze();

                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } else if(position == SlidableButtonPosition.end) {
                        wasFinished = true;
                        Vibration.cancel();
                        await audioPlayer?.stop();

                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}