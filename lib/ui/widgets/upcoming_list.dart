import 'dart:async';

import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/widgets/timers.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../persistence/deadline_alarm_manager.dart';


class UpcomingDeadlinesListController extends ChildController {
  final ParentController parent;
  DeadlinesDatabase get db => parent.db;
  UpcomingDeadlinesListController(this.parent);

  final List<Deadline> deadlinesDbCache = [];
  final List<(String, List<Deadline?>)> shownBelow = [];

  double scrollOffset = -1;
  (Deadline?, Duration)? toNextAlarm;
  Set<VoidCallback> shownUpdated = {};

  @override Future<void> init() async {}

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
    deadlinesDbCache.removeWhere((e) => e.id == d.id,);
    return true;
  }

  @override void updateShownList() {
    if(shownUpdated.isEmpty) return;

    var now = DateTime.now();
    shownBelow.clear();
    shownBelow.add(("ToDo(${camel(Importance.critical.name)})", deadlinesDbCache.where((d) => d.isTimeless() && d.importance == Importance.critical && (d.active || parent.showWhat == ShownType.showAll)).toList(growable: false)));
    if(shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

    //todo: improve readability and maintainability of this insanity:
    List<Deadline> oneTimeEvents = deadlinesDbCache.where((d) => !d.isTimeless() && !d.isRepeating()).toList();
    Map<(DateTime, DateTime), List<Deadline>> nonRepeatingOnEachDay = {};
    for (var d in oneTimeEvents) {
      if (!(d.active || parent.showWhat == ShownType.showAll)) continue;
      var cutOff = (d.startsAt ?? d.deadlineAt!).toDateTime();
      var c1 = DateTime(cutOff.year, cutOff.month, cutOff.day);
      var c2 = c1;
      if(d.startsAt != null && !d.startsAt!.date.isSameDay(d.deadlineAt!.date)) {
        c2 = d.deadlineAt!.date.toDateTime();
      }
      if(d.active || (parent.showWhat == ShownType.showAll && cutOff.isAfter(now))) {
        nonRepeatingOnEachDay.update((c1, c2), (v) => v + [d], ifAbsent: () => [d]);
      }
    }
    var nonRepeatingOnEachDaySorted = nonRepeatingOnEachDay.entries.map(
      (e) => (e.key, sort(e.value, (a, b) {
        if(a.startsAt != null && a.startsAt!.isOverdue()) {
          return a.deadlineAt!.compareTo(b.deadlineAt!);
        }
        return a.compareTo(b);
      },))
    ).toList();
    nonRepeatingOnEachDaySorted.sort((a, b) {
      var compare = (a.$1.$1.isAfter(now)?1:0).compareTo((b.$1.$1.isAfter(now)?1:0));
      if(compare == 0) return a.$1.$2.compareTo(b.$1.$2);
      if(a.$1.$1.isAfter(now)) {
        var diffA = a.$1.$1.difference(a.$1.$2).inDays;
        var diffB = b.$1.$1.difference(b.$1.$2).inDays;
        if(diffA == diffB) {
          var compare = a.$1.$2.compareTo(b.$1.$2);
          if(compare != 0) return compare;
        }
        var compare = a.$1.$1.compareTo(b.$1.$1);
        if(compare == 0) return diffB - diffA;
        return compare;
      }
      compare = a.$1.$1.compareTo(b.$1.$1);
      if(compare == 0) {
        var diffA = a.$1.$1.difference(a.$1.$2).inDays;
        var diffB = b.$1.$1.difference(b.$1.$2).inDays;
        return diffB - diffA;
      }
      return compare;
    },);

    Deadline? lastDeadline;
    shownBelow.addAll(nonRepeatingOnEachDaySorted.map(
      (e) {
        var (r1, r2) = e.$1;
        var list = e.$2;
        var newList = <Deadline?>[];
        for(Deadline d in list) {
          if(lastDeadline != null && lastDeadline?.isOverdue() != d.isOverdue()) {
            newList.add(null);
            if((lastDeadline?.startsAt??lastDeadline?.deadlineAt)?.date.day != (d.startsAt??d.deadlineAt)?.date.day) {
              newList.add(null);
            }
          }
          if(lastDeadline != null && !d.isOverdue() && (lastDeadline?.startsAt??lastDeadline?.deadlineAt)?.date.month != (d.startsAt??d.deadlineAt)?.date.month) {
            newList.add(null);
          }
          newList.add(d);
          lastDeadline = d;
        }
        return (isSameDay(r1, r2)? "${pad0(r1.day)}.${pad0(r1.month)}.${r1.year}" : "${pad0(r1.day)}.${pad0(r1.month)}.${r1.year} - ${pad0(r2.day)}.${pad0(r2.month)}.${r2.year}", newList);
      })
    );
    if(shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

    shownBelow.add(("ToDo(${camel(Importance.important.name)})", deadlinesDbCache.where((d) => d.isTimeless() && d.importance == Importance.important && (d.active || parent.showWhat == ShownType.showAll)).toList(growable: false)));
    if(shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

    List<Deadline> repeating = deadlinesDbCache.where((d) => d.isRepeating()).toList();
    Map<RepetitionType, List<Deadline>> repeatingByType = {};
    for (var d in repeating) {
      if (!d.active && parent.showWhat != ShownType.showAll) continue;
      repeatingByType.update(d.deadlineAt!.date.repetitionType, (v) => v + [d], ifAbsent: () => [d]);
    }
    var repeatingByTypeSorted = repeatingByType.entries.map((e) => (e.key, sort(e.value))).toList();
    repeatingByTypeSorted.sort((a, b) => b.$1.index - a.$1.index,);
    shownBelow.addAll(repeatingByTypeSorted.map((e) => (camel(e.$1.name), e.$2)));
    if(shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

    shownBelow.add(("ToDo(${camel(Importance.normal.name)})", deadlinesDbCache.where((d) => d.isTimeless() && d.importance == Importance.normal && (d.active || parent.showWhat == ShownType.showAll)).toList(growable: false)));
    if(shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

    for (var c in shownUpdated) {c();}

    //wait required, because createNotification does not wait until notification actually registered to return future...
    Timer(const Duration(milliseconds: 300), () {
      updateNextAlarm().then((value) {
        for (var c in shownUpdated) {c();}
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
  reloadState() => setState(() {});
  @override void initState() {
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    super.initState();
    c.updatePotentiallyVisibleDeadlinesFromDb().then((value) => setState(() {
      c.updateShownList();

      // if(c.scrollOffset == -1) {
      // listController.animateTo(WHAT ?!??!?!?!, duration: const Duration(milliseconds: 300), curve: Curves.decelerate);
      // }
    }));
    c.shownUpdated.add(reloadState);
  }
  @override void dispose() {
    super.dispose();
    listController.dispose();
    c.shownUpdated.remove(reloadState);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => c.parent.newDeadlineWithoutReload(c, context, null),
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: listController,
              itemCount: c.shownBelow.length,
              itemBuilder: (context, index) {
                var (label, ds) = c.shownBelow[index];
                var firstNonNullIndex = ds.takeWhile((d) => d == null).length;
                if(label.isEmpty) {
                  return const SizedBox(height: 25,);
                } else {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: ds.isEmpty ? 0 : 1 + ds.length,
                    padding: const EdgeInsets.all(5),
                    itemBuilder: (context, index) {
                      if (index == firstNonNullIndex) return Text(label);
                      var d = ds[index < firstNonNullIndex? index:index - 1];
                      if(d == null) {
                        return const SizedBox(height: 25,);
                      } else {
                        return DeadlineCard(
                          d, 
                          (d) => c.parent.editDeadlineWithoutReload(c, context, d.id!),
                          (d) => c.parent.deleteDeadlineWithoutReload(c, context, d, null),
                          (d) => c.parent.toggleDeadlineActiveWithoutReload(c, context, d),
                          (d, nrdt) => c.parent.toggleDeadlineNotificationTypeWithoutReload(c, d, nrdt),
                        );
                      }
                    }
                  );
                }
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
                    context,
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
      var inHours = c.toNextAlarm!.$2.inHours.remainder(24);
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