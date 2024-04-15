import 'dart:async';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/controller/upcoming_controller.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/widgets/timers.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../notifications/deadline_alarm_manager.dart';
import '../controller/parent_controller.dart';


class UpcomingView extends StatefulWidget {
  final UpcomingController controller;
  const UpcomingView(this.controller, {super.key});

  @override State<UpcomingView> createState() => _UpcomingViewState();
}

class _UpcomingViewState extends State<UpcomingView> {
  UpcomingController get c => widget.controller;
  @override Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => c.parent.newDeadline(context, null),
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(child: UpcomingListView(c)),
          _UpcomingViewFooter(c),
        ],
      )),
    );
  }
}


class UpcomingListView extends StatefulWidget {
  final UpcomingController controller;
  const UpcomingListView(this.controller, {super.key});

  @override State<UpcomingListView> createState() => _UpcomingListViewState();
}

class _UpcomingListViewState extends State<UpcomingListView> {
  UpcomingController get c => widget.controller;

  late ScrollController listController;
  @override void initState() {
    super.initState();
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    c.addContentListener(reload);
  }
  @override void dispose() {
    super.dispose();
    listController.dispose();
    c.removeContentListener(reload);
  }
  void reload() => setState(() {});

  Future<List<(String, DateTime?, List<Deadline?>)>> buildUpcomingList() async {
    final List<(String, DateTime?, List<Deadline?>)> upcoming = [];
    var deadlines = await c.queryRelevantDeadlines();
    var now = DateTime.now();
    upcoming.clear();
    upcoming.add((
      "ToDo (${camel(Importance.critical.name)})", null,
      deadlines.where(
        (d) => d.isTimeless() && d.importance == Importance.critical && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      ).toList(growable: false)
    ));
    if (upcoming.last.$3.isNotEmpty) upcoming.add(("", null, []));

    //todo: improve readability and maintainability of this insanity:
    List<Deadline> oneTimeEvents = deadlines.where((d) => !d.isTimeless() && !d.isRepeating()).toList();
    Map<(DateTime, DateTime), List<Deadline>> eventsOnEachDay = {};
    for (var d in oneTimeEvents) {
      if (!(d.isActiveOn(now) || c.parent.showWhat == ShownType.showAll)) continue;
      var cutOff = (d.startsAt ?? d.deadlineAt!).toDateTime();
      var c1 = cutOff;
      var c2 = c1;
      if (d.startsAt != null && !d.startsAt!.date.isSameDay(d.deadlineAt!.date)) {
        c2 = d.deadlineAt!.date.toDateTime();
      }
      if (d.isActiveOn(stripTime(c1)) || (c.parent.showWhat == ShownType.showAll && cutOff.isAfter(now))) {
        eventsOnEachDay.update((stripTime(c1), stripTime(c2)), (v) => v + [d], ifAbsent: () => [d]);
      }
    }
    var potentiallyOverdueRepeating = deadlines.where(
      (d) => d.isRepeating() && d.activeAfter != null && d.activeAfter!.isBefore(DateTime.now())
    );
    for (var d in potentiallyOverdueRepeating) {
      var dayCounter = d.activeAfter;
      while (dayCounter != null && dayCounter.isBefore(DateTime.now())) {
        var cutOff = (d.startsAt ?? d.deadlineAt!).nextOccurrenceAfter(dayCounter);
        if(cutOff == null || !cutOff.isBefore(DateTime.now())) break;
        var c1 = stripTimeNullable(cutOff);
        var c2 = c1;
        if (d.startsAt != null && !d.startsAt!.date.isSameDay(d.deadlineAt!.date)) {
          c2 = stripTimeNullable(d.deadlineAt!.date.nextOccurrenceAfter(dayCounter));
        }
        if (c1 != null && c2 != null && d.isActiveOn(c1)) {
          eventsOnEachDay.update((c1, c2), (v) => v + [d], ifAbsent: () => [d]);
        }
        dayCounter = cutOff != dayCounter? cutOff : dayCounter.add(const Duration(days: 1));
      }
    }
    eventsOnEachDay.putIfAbsent((stripTime(now), stripTime(now)), () => []);
    var eventsOnEachDaySorted = eventsOnEachDay.entries.map((e) => (
    e.key,
    sort(e.value, (a, b) {
      if (a.startsAt != null && a.startsAt!.isOverdue(now)) {
        return a.deadlineAt!.compareTo(b.deadlineAt!);
      }
      return nullableCompare((a.startsAt??a.deadlineAt)?.time, (b.startsAt??b.deadlineAt)?.time);
    },)
    )).toList();
    eventsOnEachDaySorted.sort((a, b) {
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

    (DateTime, bool, bool)? last;
    upcoming.addAll(eventsOnEachDaySorted.map((e) {
      var (r1, r2) = e.$1;
      var list = e.$2;
      var newList = <Deadline?>[];
      if(last!=null && last!.$3 && isSameDay(last!.$1, now)) {
        newList.add(null);
      }
      if(isSameDay(r1, now)) {
        newList.add(null);
        newList.add(null);
        if(list.isEmpty) {
          last = (r1, false, true);
        }
      }
      for (Deadline d in list) {
        bool isOverdue = d.isRepeating() || d.isOverdue(now);
        if (last != null && last!.$2 != isOverdue) {
          newList.add(null);
        }
        if (last != null && last!.$1.month != r1.month) {
          newList.add(null);
        }
        newList.add(d);
        last = (r1, isOverdue, false);
      }
      return (
        isSameDay(r1, r2) ?
          "${pad0(r1.day)}.${pad0(r1.month)}.${r1.year} (${shortWeekdayString(r1)})"
            :
          "${pad0(r1.day)}.${pad0(r1.month)}.${r1.year} (${shortWeekdayString(r1)}) - ${pad0(r2.day)}.${pad0(r2.month)}.${r2.year} (${shortWeekdayString(r2)})",
        r1,
        newList
      );
    }));
    if (upcoming.last.$3.isNotEmpty) upcoming.add(("", null, []));

    upcoming.add((
      "ToDo (${camel(Importance.important.name)})",
      null,
      deadlines.where(
        (d) => d.isTimeless() && d.importance == Importance.important && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      ).toList(growable: false)
    ));
    if (upcoming.last.$3.isNotEmpty) upcoming.add(("", null, []));

    List<Deadline> repeating = deadlines.where((d) => d.isRepeating()).toList();
    Map<RepetitionType, List<Deadline>> repeatingByType = {};
    for (var d in repeating) {
      if (!d.activeAtAll && c.parent.showWhat != ShownType.showAll) continue;
      repeatingByType.update(d.deadlineAt!.date.repetitionType, (v) => v + [d], ifAbsent: () => [d]);
    }
    var repeatingByTypeSorted = repeatingByType.entries.map((e) => (e.key, sort(e.value))).toList();
    repeatingByTypeSorted.sort((a, b) => b.$1.index - a.$1.index,);
    upcoming.addAll(repeatingByTypeSorted.map((e) => (camel(e.$1.name), null, e.$2)));
    if (upcoming.last.$3.isNotEmpty) upcoming.add(("", null, []));

    upcoming.add((
      "ToDo (${camel(Importance.normal.name)})",
      null,
      deadlines.where((d) =>
        d.isTimeless() && d.importance == Importance.normal && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      ).toList(growable: false)
    ));
    if (upcoming.last.$3.isNotEmpty) upcoming.add(("", null, []));

    return upcoming;
  }

  @override Widget build(BuildContext context) {
    return FutureBuilder(
      future: buildUpcomingList(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return Container();
        return ListView.builder(
          controller: listController,
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var (label, refDt, ds) = snapshot.data![index];
            var firstNonNullIndex = ds.takeWhile((d) => d == null).length;
            if(label.isEmpty) {
              return const SizedBox(height: 25,);
            } else {
              return ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: 1 + ds.length,
                padding: const EdgeInsets.all(5),
                itemBuilder: (context, index) {
                  if (index == firstNonNullIndex) {
                    return Text(label, style: TextStyle(color: refDt != null && isSameDay(refDt, DateTime.now()) ? const Color(0xFFF94144) : null),);
                  }
                  var d = ds[index < firstNonNullIndex? index:index - 1];
                  if(d == null) {
                    return const SizedBox(height: 25,);
                  } else {
                    return DeadlineCard(
                      d,
                      refDt?? DateTime.now(),
                      (d) => c.parent.editDeadline(context, d.id!),
                      (d) => c.parent.deleteDeadline(context, d, null),
                      (d) => refDt==null?c.parent.toggleDeadlineActiveAtAll(context, d):c.parent.toggleDeadlineActiveOnOrAfter(context, d, refDt),
                      (d, nrdt) => c.parent.toggleDeadlineNotificationType(d, nrdt),
                    );
                  }
                }
              );
            }
          },
        );
      }
    );
  }
}


class _UpcomingViewFooter extends StatefulWidget {
  final UpcomingController controller;
  const _UpcomingViewFooter(this.controller);

  @override State<_UpcomingViewFooter> createState() => _UpcomingViewFooterState();
}

class _UpcomingViewFooterState extends State<_UpcomingViewFooter> {
  UpcomingController get c => widget.controller;

  @override Widget build(BuildContext context) {
    return Row(
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
            c.parent.invalidateAllCaches().then((_) => c.notifyContentsChanged());
          }),
          value: c.parent.showWhat != ShownType.showActive ? "Show Future":"Show Active",
        ),
        const SizedBox(width: 15,),
        GestureDetector(
          child: const Icon(Icons.alarm, size: 44),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TimersView()),
            );
            setState(() {});
          },
        ),
        const SizedBox(width: 5,),
        _DurationToNextNotificationDisplay(c),
      ],
    );
  }
}


class _DurationToNextNotificationDisplay extends StatefulWidget {
  final UpcomingController controller;
  const _DurationToNextNotificationDisplay(this.controller);

  @override State<_DurationToNextNotificationDisplay> createState() => _DurationToNextNotificationDisplayState();
}

class _DurationToNextNotificationDisplayState extends State<_DurationToNextNotificationDisplay> {
  UpcomingController get c => widget.controller;

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
        d = toNextAlarm!.$1!; //use cached deadline to avoid loading from disk
      } else {
        d = deadlineId == -1? null : await c.parent.db.loadById(deadlineId);
      }
      //d can be null, if and only if it is a timer
      toNextAlarm = (d, duration);
    }
  }
  @override void initState() {
    super.initState();

    updateNextAlarm().then((value) => setState(() {}));
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
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
          await c.parent.editDeadline(context, toNextAlarm!.$1!.id!);
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TimersView()),
          );
        }
        updateNextAlarm().then((value) => setState(() {}));
      },
    );
  }
}