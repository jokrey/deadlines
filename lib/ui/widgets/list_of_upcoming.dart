import 'dart:async';

import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/widgets/timer_page.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../persistence/deadline_alarm_manager.dart';


class UpcomingDeadlinesListController extends ChildController {
  final ParentController parent;
  DeadlinesDatabase get db => parent.db;
  UpcomingDeadlinesListController(this.parent);

  final List<Deadline> deadlinesDbCache = [];
  final List<(String, List<Deadline>)> shownBelow = [];

  double scrollOffset = -1;
  Function(VoidCallback)? setState;
  (Deadline?, Duration)? toNextAlarm;

  Future<void> updatePotentiallyVisibleDeadlinesFromDb() {
    return db.queryDeadlinesActiveOrAfter(DateTime.now()).then((r) {
      deadlinesDbCache.clear();
      deadlinesDbCache.addAll(r);
    });
  }

  @override void addToCache(Deadline d) {
    deadlinesDbCache.add(d);
  }
  @override bool removeFromCache(Deadline d) {
    return deadlinesDbCache.remove(d);
  }

  @override void updateShownList() {
    if(setState == null) return;
    setState!(() {
      var now = DateTime.now();
      shownBelow.clear();
      shownBelow.add((camel(Importance.critical.name), deadlinesDbCache.where((d) => d.isTimeless() && d.importance == Importance.critical).toList(growable: false)));
      List<Deadline> oneTimeEvents = deadlinesDbCache.where((d) => !d.isTimeless() && !d.isRepeating()).toList();
      Map<DateTime, List<Deadline>> nonRepeatingOnEachDay = {};
      for (var d in oneTimeEvents) {
        if (!(d.active || parent.showWhat == ShownType.showAll)) continue;
        var c = (d.startsAt ?? d.deadlineAt!).toDateTime();
        do {
          if(d.active || (parent.showWhat == ShownType.showAll && c.isAfter(now))) {
            nonRepeatingOnEachDay.update(c, (v) => v + [d], ifAbsent: () => [d]);
          }
          c = c.add(const Duration(days: 1));
        } while(!c.isAfter(d.deadlineAt!.date.toDateTime()));
      }
      var nonRepeatingOnEachDaySorted = nonRepeatingOnEachDay.entries.map(
        (e) => (e.key, sort(e.value))
      ).toList();
      nonRepeatingOnEachDaySorted.sort((a, b) => a.$1.compareTo(b.$1),);
      shownBelow.addAll(nonRepeatingOnEachDaySorted.map(
        (e) => ("${e.$1.day}.${e.$1.month}.${e.$1.year}", e.$2))
      );
      shownBelow.add((camel(Importance.important.name), deadlinesDbCache.where((d) => d.isTimeless() && d.importance == Importance.important).toList(growable: false)));

      List<Deadline> repeating = deadlinesDbCache.where((d) => d.isRepeating()).toList();
      Map<RepetitionType, List<Deadline>> repeatingByType = {};
      for (var d in repeating) {
        if (!d.active && parent.showWhat != ShownType.showAll) continue;
        repeatingByType.update(d.deadlineAt!.date.repetitionType, (v) => v + [d], ifAbsent: () => [d]);
      }
      var repeatingByTypeSorted = repeatingByType.entries.map((e) => (e.key, sort(e.value))).toList();
      repeatingByTypeSorted.sort((a, b) => b.$1.index - a.$1.index,);
      shownBelow.addAll(repeatingByTypeSorted.map((e) => (camel(e.$1.name), e.$2)));
      shownBelow.add((camel(Importance.normal.name), deadlinesDbCache.where((d) => d.isTimeless() && (d.importance == Importance.normal)).toList(growable: false)));
    });

    //wait required, because createNotification does not wait until notification actually registered to return future...
    Timer(const Duration(milliseconds: 300), () {
      updateNextAlarm().then((value) {
        if(setState!=null) setState!(() {});
      });
    },);
  }

  Future<void> updateNextAlarm() async {
    var r = await staticNotify.getDurationToNextAlarm();
    if(r == null) {
      toNextAlarm = null;
    } else {
      var (notifyId, duration) = r;
      var deadlineId = DeadlineAlarms.toDeadlineId(notifyId);
      var d = deadlineId == -1? null : await db.loadById(deadlineId);
      //d can be null, if it is a timer
      toNextAlarm = (d, duration);
    }
  }
}


class UpcomingDeadlinesList extends StatefulWidget {
  final UpcomingDeadlinesListController controller;
  const UpcomingDeadlinesList(this.controller, {super.key});

  @override UpcomingDeadlinesListState createState() => UpcomingDeadlinesListState();
}

class UpcomingDeadlinesListState extends State<UpcomingDeadlinesList> {
  UpcomingDeadlinesListController get c => widget.controller;

  late ScrollController listController;
  @override void initState() {
    c.setState = setState;
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    super.initState();
    c.updatePotentiallyVisibleDeadlinesFromDb().then((value) => setState(() {
      c.updateShownList();

      // if(c.scrollOffset == -1) {
      // listController.animateTo(WHAT ?!??!?!?!, duration: const Duration(milliseconds: 300), curve: Curves.decelerate);
      // }
    }));
  }
  @override void dispose() {
    super.dispose();
    if(c.setState == setState) c.setState = null;
    listController.dispose();
  }

  @override Widget build(BuildContext ogContext) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => c.parent.newDeadlineWithoutReload(c, ogContext, null),
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: listController,
              itemCount: c.shownBelow.length,
              itemBuilder: (context, index) {
                var (label, ds) = c.shownBelow[index];
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: ds.isEmpty?0:1+ds.length,
                  padding: const EdgeInsets.all(5),
                  itemBuilder: (context, index) {
                    if(index == 0) return Text(label);
                    var d = ds[index-1];
                    return DeadlineCard(
                      d,
                      (d) => c.parent.editDeadlineWithoutReload(c, ogContext, d.id!),
                      (d) => c.parent.deleteDeadlineWithoutReload(c, ogContext, d, null),
                      (d) => c.parent.toggleDeadlineActiveWithoutReload(c, ogContext, d),
                      (d, nrdt, ov) => c.parent.toggleDeadlineNotificationTypeWithoutReload(c, d, nrdt, ov),
                    );
                  }
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 15,),
              DropdownButton<String>(
                alignment: Alignment.centerRight,
                items: ["Show Active", "Show Future"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newlySelected) => setState(() {
                  if(newlySelected == "Show Future") {
                    c.parent.showWhat = ShownType.showAll;
                  } else {
                    c.parent.showWhat = ShownType.showActive;
                  }
                  c.updateShownList();
                }),
                value: c.parent.showWhat != ShownType.showActive ? "Show Future":"Show Active",
              ),
              const SizedBox(width: 15,),
              GestureDetector(
                child: const Icon(Icons.alarm, size: 44),
                onTap: () async {
                  await Navigator.push(
                    ogContext,
                    MaterialPageRoute(builder: (context) => const TimerPage()),
                  );
                  c.updateNextAlarm().then((value) => setState(() {}));
                },
              ),
              const SizedBox(width: 5,),
              NextInDisplay(c),
            ],
          ),
        ],
      )),
    );
  }
}

class NextInDisplay extends StatefulWidget {
  final UpcomingDeadlinesListController controller;
  const NextInDisplay(this.controller, {super.key});

  @override State<NextInDisplay> createState() => _NextInDisplayState();
}

class _NextInDisplayState extends State<NextInDisplay> {
  UpcomingDeadlinesListController get c => widget.controller;

  late Timer timer;
  @override void initState() {
    super.initState();

    c.updateNextAlarm().then((value) => setState(() {}));
    // var minuteBefore = -1;
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // var minuteAfter = DateTime.now().minute;
      // if(minuteBefore == minuteAfter) return;
      // minuteBefore = minuteAfter;

      c.updateNextAlarm().then((value) => setState(() {}));
    },);
  }
  @override void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    var text = "in: ";
    if(c.toNextAlarm==null) {
      text += "never";
    } else {
      var inDays = c.toNextAlarm!.$2.inDays;
      var inHours = c.toNextAlarm!.$2.inHours.remainder(60);
      var inMinutes = c.toNextAlarm!.$2.inMinutes.remainder(60);
      if (inHours == 0 && inMinutes == 0) {
        var inSeconds = c.toNextAlarm!.$2.inSeconds.remainder(60);
        if(inSeconds < 3) {
          text += "seconds";
        } else {
          text += "${inSeconds}s";
        }
      } else if(inDays == 0) {
        text += "${pad0(inHours)}:${pad0(inMinutes)}";
      } else {
        text += "${inDays}d ${pad0(inHours)}:${pad0(inMinutes)}";
      }
    }
    return GestureDetector(
      child: Text(text, style: const TextStyle(fontSize: 16),),
      onTap: () async {
        if(c.toNextAlarm != null && c.toNextAlarm!.$1 != null) {
          await c.parent.editDeadlineWithoutReload(c, context, c.toNextAlarm!.$1!.id!);
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TimerPage()),
          );
        }
        c.updateNextAlarm().then((value) => setState(() {}));
      },
    );
  }
}