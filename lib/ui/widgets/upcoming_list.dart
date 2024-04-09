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
import 'package:synchronized/synchronized.dart';
import '../../persistence/deadline_alarm_manager.dart';


class UpcomingDeadlinesListController extends ChildController {
  final ParentController parent;
  DeadlinesDatabase get db => parent.db;
  UpcomingDeadlinesListController(this.parent);

  //ui choices to be restored
  double scrollOffset = -1;



  Lock l = Lock();
  final List<Deadline> _cache = [];
  invalidateCache() => l.synchronized(() => _cache.clear());
  Future<Iterable<Deadline>> queryRelevantDeadlines() => l.synchronized(() async {
    if(_cache.isEmpty) {
      _cache.addAll(await db.queryDeadlinesActiveOrTimelessOrAfter(DateTime.now()));
    }
    return _cache;
  });


  final List<VoidCallback> _callbacks = [];
  void addListener(VoidCallback callback) => _callbacks.add(callback);
  void removeListener(VoidCallback callback) => _callbacks.remove(callback);
  @override void notifyContentsChanged() {
    invalidateCache().then((_) {
      for (var callback in _callbacks) {
        callback();
      }
    });
  }
}


class UpcomingDeadlinesList extends StatefulWidget {
  final UpcomingDeadlinesListController controller;
  const UpcomingDeadlinesList(this.controller, {super.key});

  @override UpcomingDeadlinesListState createState() => UpcomingDeadlinesListState();
}

class UpcomingDeadlinesListState extends State<UpcomingDeadlinesList> {
  UpcomingDeadlinesListController get c => widget.controller;

  @override Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => c.parent.newDeadline(c, context, null),
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(child: UpcomingListBelow(c)),
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
                  c.notifyContentsChanged();
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
                  setState(() {});
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


class UpcomingListBelow extends StatefulWidget {
  final UpcomingDeadlinesListController controller;
  const UpcomingListBelow(this.controller, {super.key});

  @override State<UpcomingListBelow> createState() => _UpcomingListBelowState();
}

class _UpcomingListBelowState extends State<UpcomingListBelow> {
  UpcomingDeadlinesListController get c => widget.controller;

  late ScrollController listController;
  @override void initState() {
    super.initState();
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    c.addListener(reloadShownBelow);
    reloadShownBelow();
  }
  @override void dispose() {
    super.dispose();
    listController.dispose();
    c.removeListener(reloadShownBelow);
  }

  final List<(String, List<Deadline?>)> shownBelow = [];
  void reloadShownBelow() {
    c.queryRelevantDeadlines().then((deadlines) {
      setState(() {
        var now = DateTime.now();
        shownBelow.clear();
        shownBelow.add(("ToDo(${camel(Importance.critical.name)})", deadlines.where((d) => d.isTimeless() &&
            d.importance == Importance.critical && (d.active || c.parent.showWhat == ShownType.showAll))
            .toList(growable: false)));
        if (shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

        //todo: improve readability and maintainability of this insanity:
        List<Deadline> oneTimeEvents = deadlines.where((d) => !d.isTimeless() && !d.isRepeating()).toList();
        Map<(DateTime, DateTime), List<Deadline>> nonRepeatingOnEachDay = {};
        for (var d in oneTimeEvents) {
          if (!(d.active || c.parent.showWhat == ShownType.showAll)) continue;
          var cutOff = (d.startsAt ?? d.deadlineAt!).toDateTime();
          var c1 = DateTime(cutOff.year, cutOff.month, cutOff.day);
          var c2 = c1;
          if (d.startsAt != null && !d.startsAt!.date.isSameDay(d.deadlineAt!.date)) {
            c2 = d.deadlineAt!.date.toDateTime();
          }
          if (d.active || (c.parent.showWhat == ShownType.showAll && cutOff.isAfter(now))) {
            nonRepeatingOnEachDay.update((c1, c2), (v) => v + [d], ifAbsent: () => [d]);
          }
        }
        var nonRepeatingOnEachDaySorted = nonRepeatingOnEachDay.entries.map((e) =>
            (e.key, sort(e.value, (a, b) {
              if (a.startsAt != null && a.startsAt!.isOverdue()) {
                return a.deadlineAt!.compareTo(b.deadlineAt!);
              }
              return a.compareTo(b);
            },))
        ).toList();
        nonRepeatingOnEachDaySorted.sort((a, b) {
          var compare = (a.$1.$1.isAfter(now) ? 1 : 0).compareTo((b.$1.$1.isAfter(now) ? 1 : 0));
          if (compare == 0) return a.$1.$2.compareTo(b.$1.$2);
          if (a.$1.$1.isAfter(now)) {
            var diffA = a.$1.$1.difference(a.$1.$2).inDays;
            var diffB = b.$1.$1.difference(b.$1.$2).inDays;
            if (diffA == diffB) {
              var compare = a.$1.$2.compareTo(b.$1.$2);
              if (compare != 0) return compare;
            }
            var compare = a.$1.$1.compareTo(b.$1.$1);
            if (compare == 0) return diffB - diffA;
            return compare;
          }
          compare = a.$1.$1.compareTo(b.$1.$1);
          if (compare == 0) {
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
              for (Deadline d in list) {
                if (lastDeadline != null && lastDeadline?.isOverdue() != d.isOverdue()) {
                  newList.add(null);
                  if ((lastDeadline?.startsAt ?? lastDeadline?.deadlineAt)?.date.day !=
                      (d.startsAt ?? d.deadlineAt)?.date.day) {
                    newList.add(null);
                  }
                }
                if (lastDeadline != null && !d.isOverdue() &&
                    (lastDeadline?.startsAt ?? lastDeadline?.deadlineAt)?.date.month !=
                        (d.startsAt ?? d.deadlineAt)?.date.month) {
                  newList.add(null);
                }
                newList.add(d);
                lastDeadline = d;
              }
              return (isSameDay(r1, r2) ? "${pad0(r1.day)}.${pad0(r1.month)}.${r1.year}" : "${pad0(r1.day)}.${pad0(
                  r1.month)}.${r1.year} - ${pad0(r2.day)}.${pad0(r2.month)}.${r2.year}", newList);
            })
        );
        if (shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

        shownBelow.add(("ToDo(${camel(Importance.important.name)})", deadlines.where((d) => d.isTimeless() &&
            d.importance == Importance.important && (d.active || c.parent.showWhat == ShownType.showAll))
            .toList(growable: false)));
        if (shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

        List<Deadline> repeating = deadlines.where((d) => d.isRepeating()).toList();
        Map<RepetitionType, List<Deadline>> repeatingByType = {};
        for (var d in repeating) {
          if (!d.active && c.parent.showWhat != ShownType.showAll) continue;
          repeatingByType.update(d.deadlineAt!.date.repetitionType, (v) => v + [d], ifAbsent: () => [d]);
        }
        var repeatingByTypeSorted = repeatingByType.entries.map((e) => (e.key, sort(e.value))).toList();
        repeatingByTypeSorted.sort((a, b) => b.$1.index - a.$1.index,);
        shownBelow.addAll(repeatingByTypeSorted.map((e) => (camel(e.$1.name), e.$2)));
        if (shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));

        shownBelow.add(("ToDo(${camel(Importance.normal.name)})", deadlines.where((d) => d.isTimeless() &&
            d.importance == Importance.normal && (d.active || c.parent.showWhat == ShownType.showAll))
            .toList(growable: false)));
        if (shownBelow.last.$2.isNotEmpty) shownBelow.add(("", []));
      });
    });
  }


  @override Widget build(BuildContext context) {
    return ListView.builder(
      controller: listController,
      itemCount: shownBelow.length,
      itemBuilder: (context, index) {
        var (label, ds) = shownBelow[index];
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
                        (d) => c.parent.editDeadline(c, context, d.id!),
                        (d) => c.parent.deleteDeadline(c, context, d, null),
                        (d) => c.parent.toggleDeadlineActive(c, context, d),
                        (d, nrdt) => c.parent.toggleDeadlineNotificationType(c, d, nrdt),
                  );
                }
              }
          );
        }
      },
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
  (Deadline?, Duration)? toNextAlarm;
  Future<void> updateNextAlarm() async {
    var r = await staticNotify.getDurationToNextAlarm();
    if(r == null) {
      toNextAlarm = null;
    } else {
      var (notifyId, duration) = r;
      var deadlineId = DeadlineAlarms.toDeadlineId(notifyId);
      Deadline? d;
      if(deadlineId == toNextAlarm?.$1?.id) {
        d = toNextAlarm!.$1!;
      } else {
        d = deadlineId == -1? null : await c.db.loadById(deadlineId);
      }
      //d can be null, if it is a timer
      toNextAlarm = (d, duration);
    }
  }
  @override void initState() {
    super.initState();

    updateNextAlarm().then((value) => setState(() {}));
    // var minuteBefore = -1;
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // var minuteAfter = DateTime.now().minute;
      // if(minuteBefore == minuteAfter) return;
      // minuteBefore = minuteAfter;

      updateNextAlarm().then((value) => setState(() {}));
    },);
  }
  @override void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    var text = "in: ";
    if(toNextAlarm==null) {
      text += "never";
    } else {
      var inDays = toNextAlarm!.$2.inDays;
      var inHours = toNextAlarm!.$2.inHours.remainder(24);
      var inMinutes = toNextAlarm!.$2.inMinutes.remainder(60);
      if (inHours == 0 && inMinutes == 0) {
        var inSeconds = toNextAlarm!.$2.inSeconds.remainder(60);
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
        if(toNextAlarm != null && toNextAlarm!.$1 != null) {
          await c.parent.editDeadline(c, context, toNextAlarm!.$1!.id!);
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TimerPage()),
          );
        }
        updateNextAlarm().then((value) => setState(() {}));
      },
    );
  }
}