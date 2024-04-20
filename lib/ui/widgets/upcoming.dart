import 'dart:async';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/controller/upcoming_controller.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/widgets/deadline_list.dart';
import 'package:deadlines/ui/widgets/timers.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../notifications/deadline_alarm_manager.dart';
import '../controller/parent_controller.dart';

/// Upcoming View, shows list of all relevant deadlines (timeless, active and future)
class UpcomingView extends StatefulWidget {
  /// Appropriate UpcomingController (should exist only once per app instance, but only set in one active ui instance)
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
          Expanded(child: _UpcomingListView(c)),
          _UpcomingViewFooter(c),
        ],
      )),
    );
  }
}


class _UpcomingListView extends StatefulWidget {
  final UpcomingController controller;
  const _UpcomingListView(this.controller);

  @override State<_UpcomingListView> createState() => _UpcomingListViewState();
}

class _UpcomingListViewState extends State<_UpcomingListView> {
  UpcomingController get c => widget.controller;

  late ScrollController _listController;
  @override void initState() {
    super.initState();
    _listController = ScrollController(initialScrollOffset: c.scrollOffset);
    _listController.addListener(() {c.scrollOffset = _listController.offset;});
    c.addContentListener(_reload);
  }
  @override void dispose() {
    super.dispose();
    _listController.dispose();
    c.removeContentListener(_reload);
  }
  void _reload() => setState(() {});

  @override Widget build(BuildContext context) {
    return ListOfGroupedDeadlinesWidget(c.parent, listFuture: _buildUpcomingList(), scrollController: _listController);
  }

  Future<List<Group>> _buildUpcomingList() async {
    var deadlines = await c.queryRelevantDeadlines();
    var now = DateTime.now();

    final List<Group> upcoming = [];

    upcoming.add(Group.fromTimeless(
      Importance.critical,
      deadlines.where(
        (d) => d.isTimeless() && d.importance == Importance.critical && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      )
    ));
    if (upcoming.last.content.isNotEmpty) upcoming.add(Group.emptySpace());


    Map<(DateTime, DateTime), List<Deadline>> eventsOnEachDay = {};

    var oneTimeEvents = deadlines.where((d) => !d.isTimeless() && !d.isRepeating());
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

    var potentiallyOverdueRepeating = deadlines.where((d) => d.isRepeating() && d.activeAfter != null && d.activeAfter!.isBefore(now));
    for (var d in potentiallyOverdueRepeating) {
      var dayCounter = d.activeAfter;
      while (dayCounter != null && dayCounter.isBefore(now)) {
        var cutOff = (d.startsAt ?? d.deadlineAt!).nextOccurrenceAfter(dayCounter);
        if(cutOff == null || !cutOff.isBefore(now)) break;
        var c1 = stripTimeNullable(cutOff);
        var c2 = c1;
        if (d.startsAt != null && !d.startsAt!.date.isSameDay(d.deadlineAt!.date)) {
          c2 = stripTimeNullable(d.deadlineAt!.date.nextOccurrenceAfter(dayCounter));
        }
        if (c1 != null && c2 != null && d.isActiveOn(c1) && d.isOnThisDay(c1)) {
          eventsOnEachDay.update((c1, c2), (v) => v + [d], ifAbsent: () => [d]);
        }
        dayCounter = cutOff != dayCounter? cutOff : dayCounter.add(const Duration(days: 1));
      }
    }
    eventsOnEachDay.putIfAbsent((stripTime(now), stripTime(now)), () => []); //ensure today exists in list

    var eventsOnEachDaySorted = sortedGroupList(eventsOnEachDay.entries.map((e) => Group.fromRange(e.key.$1, e.key.$2, e.value,)));
    (DateTime, bool, bool)? last;
    upcoming.addAll(eventsOnEachDaySorted.map((e) {
      var list = e.content;
      var newList = <Deadline?>[];
      if(last!=null && last!.$3 && isSameDay(last!.$1, now)) {
        newList.add(null);
      }
      if(isSameDay(e.startDay!, now)) {
        newList.add(null);
        newList.add(null);
        if(list.isEmpty) {
          last = (e.startDay!, false, true);
        }
      }
      for (Deadline? d in list) {
        bool isOverdue = d != null && (d.isRepeating() || d.isOverdue(now));
        if (last != null && last!.$2 != isOverdue) {
          newList.add(null);
        }
        if (last != null && last!.$1.month != e.startDay!.month) {
          newList.add(null);
        }
        newList.add(d);
        last = (e.startDay!, isOverdue, false);
      }
      return e.copyWithList(newList);
    }));
    if (upcoming.last.content.isNotEmpty) upcoming.add(Group.emptySpace());


    upcoming.add(Group.fromTimeless(
      Importance.important,
      deadlines.where(
        (d) => d.isTimeless() && d.importance == Importance.important && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      )
    ));
    if (upcoming.last.content.isNotEmpty) upcoming.add(Group.emptySpace());

    List<Deadline> repeating = deadlines.where((d) => d.isRepeating()).toList();
    Map<RepetitionType, List<Deadline>> repeatingByType = {};
    for (var d in repeating) {
      if (!d.activeAtAll && c.parent.showWhat != ShownType.showAll) continue;
      repeatingByType.update(d.deadlineAt!.date.repetitionType, (v) => v + [d], ifAbsent: () => [d]);
    }
    var repeatingByTypeSorted = sorted(repeatingByType.entries, (a, b) => b.key.index - a.key.index,);
    upcoming.addAll(repeatingByTypeSorted.map((e) => Group(camel(e.key.name), null, null, e.value)));
    if (upcoming.last.content.isNotEmpty) upcoming.add(Group.emptySpace());

    upcoming.add(Group.fromTimeless(
      Importance.normal,
      deadlines.where((d) =>
        d.isTimeless() && d.importance == Importance.normal && (d.activeAtAll || c.parent.showWhat == ShownType.showAll)
      )
    ));
    if (upcoming.last.content.isNotEmpty) upcoming.add(Group.emptySpace());

    return upcoming;
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