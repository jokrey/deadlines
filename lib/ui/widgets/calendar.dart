import 'dart:math';

import 'package:deadlines/ui/deadlines_display.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:extended_wrap/extended_wrap.dart';

class DeadlinesCalendarController extends ChildController {
  final ParentController parent;
  DeadlinesDatabase get db => parent.db;
  DeadlinesCalendarController(this.parent);

  final List<Deadline> deadlinesDbCache = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final List<((DateTime, DateTime), List<Deadline>)> shownBelow = [];

  double scrollOffset = 0;
  Function(VoidCallback)? setState;

  bool showDaily = false;

  List<Deadline> getDailyEvents(DateTime day) {
    var today = stripTime(DateTime.now());
    var l = deadlinesDbCache.where((d) {
      return !d.isTimeless() && d.isOnThisDay(day) &&
          (d.active || parent.showWhat == ShownType.showAll) &&
          (!d.deadlineAt!.date.isDaily() || showDaily) &&
          (parent.showWhat == ShownType.showAll || !d.isRepeating() || !day.isBefore(today)) ;
    }).toList();
    l.sort((a, b) => nullableCompare(a.startsAt?.time ?? a.deadlineAt?.time, b.startsAt?.time ?? b.deadlineAt?.time));
    return l;
  }
  Future updatePotentiallyVisibleDeadlinesFromDb() async {
    int m = _focusedDay.month;
    int y = _focusedDay.year;
    List<Future<List<Deadline>>> queries = [
      db.queryDeadlinesInMonth(m==1?y-1:y, m==1?12:m-1),
      db.queryDeadlinesInMonth(_focusedDay.year, _focusedDay.month),
      db.queryDeadlinesInMonth(m==12?y+1:y, m==12?1:m+1),
    ];
    return Future.wait(queries).then((r) {
      deadlinesDbCache.clear();
      deadlinesDbCache.addAll(r.expand((e) => e).toSet());
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
    if(setState == null) return;
    setState!(() {
      shownBelow.clear();
      if (_selectedDay != null) {
        shownBelow.add(((_selectedDay!, _selectedDay!), getDailyEvents(_selectedDay!)));
      } else {
        //todo: improve readability and maintainability of this insanity:
        var now = DateTime.now();
        var firstDayInMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);

        var occurrencesInMonth = <Deadline, List<DateTime>>{};
        DateTime i = firstDayInMonth;
        while(i.month == firstDayInMonth.month) {
          var ds = getDailyEvents(i);
          for(var d in ds) {
            occurrencesInMonth.update(d, (v) => v + [i], ifAbsent: () => [i]);
          }
          i = DateTime(i.year, i.month, i.day+1);
        }
        var combined = <(DateTime, DateTime), List<Deadline>>{};
        for(var e in occurrencesInMonth.entries) {
          var actualStart = (e.key.startsAt??e.key.deadlineAt!).date.isOnThisDay(e.value.first)? e.value.first : (e.key.startsAt??e.key.deadlineAt!).lastOccurrenceBefore(e.value.first) ?? e.value.first;
          DateTime i = DateTime(actualStart.year, actualStart.month, actualStart.day);
          var numSkip = isSameDay(e.value.first, i) ? 1 : 0;
          var rangeStart = i;
          var last = rangeStart;
          for(var dt in e.value.skip(numSkip)) {
            i = DateTime(i.year, i.month, i.day+1);
            if(i.isBefore(firstDayInMonth)) i = firstDayInMonth;
            if(!isSameDay(dt, i) || e.key.deadlineAt!.date.isDaily()) {
              combined.update((rangeStart, last), (v) => v + [e.key], ifAbsent: () => [e.key]);
              rangeStart = dt;
            }
            last = dt;
            i = dt;
          }
          var actualEnd = e.key.deadlineAt!.nextOccurrenceAfter(rangeStart)?? last;
          combined.update((rangeStart, DateTime(actualEnd.year, actualEnd.month, actualEnd.day)), (v) => v + [e.key], ifAbsent: () => [e.key]);
        }
        shownBelow.addAll(sorted(
          combined.entries.map((e) => (e.key, sort(e.value, (a, b) {
            if(a.startsAt != null && a.startsAt!.isOverdue()) {
              return a.deadlineAt!.compareTo(b.deadlineAt!);
            }
            return a.compareTo(b);
          },))),
          (a, b) {
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
            var compare = a.$1.$1.compareTo(b.$1.$1);
            if(compare == 0) {
              var diffA = a.$1.$1.difference(a.$1.$2).inDays;
              var diffB = b.$1.$1.difference(b.$1.$2).inDays;
              return diffB - diffA;
            }
            return compare;
          },)
        );
      }
    });
  }
}



class DeadlinesCalendar extends StatefulWidget {
  final DeadlinesCalendarController controller;
  const DeadlinesCalendar(this.controller, {super.key});

  @override DeadlinesCalendarState createState() => DeadlinesCalendarState();
}

class DeadlinesCalendarState extends State<DeadlinesCalendar> {
  DeadlinesCalendarController get c => widget.controller;

  late ScrollController listController;
  @override void initState() {
    c.setState = setState;
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    super.initState();
    c.updatePotentiallyVisibleDeadlinesFromDb().then((_) => setState(() {
      c.updateShownList();
    }));
  }
  @override void dispose() {
    listController.dispose();
    if(c.setState == setState) c.setState = null;
    super.dispose();
  }

  @override Widget build(BuildContext ogContext) {
    return Scaffold(
      floatingActionButton: c._selectedDay == null? null : FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await c.parent.newDeadlineWithoutReload(c, ogContext, c._selectedDay==null?c._focusedDay:c._selectedDay!);
        },
      ),
      body: SafeArea(child: Column(
        children: [
          DeadlineTableCalendar(c),
          const SizedBox(height: 4.0),
          Expanded(
            child: GestureDetector(
              child: ListView.builder(
                controller: listController,
                itemCount: c.shownBelow.length,
                itemBuilder: (context, index) {
                  var ((dtr1, dtr2), ds) = c.shownBelow[index];
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: ds.isEmpty?0:1+ds.length,
                    padding: const EdgeInsets.all(5),
                    itemBuilder: (context, index) {
                      if(index == 0) return Text(isSameDay(dtr1, dtr2)? "${pad0(dtr1.day)}.${pad0(dtr1.month)}.${dtr1.year}" : "${pad0(dtr1.day)}.${pad0(dtr1.month)}.${dtr1.year} - ${pad0(dtr2.day)}.${pad0(dtr2.month)}.${dtr2.year}");
                      var d = ds[index-1];
                      return DeadlineCard(
                        d,
                        (d) => c.parent.editDeadlineWithoutReload(c, ogContext, d.id!),
                        (d) => c.parent.deleteDeadlineWithoutReload(c, ogContext, d, dtr1),
                        (d) => c.parent.toggleDeadlineActiveWithoutReload(c, ogContext, d),
                        (d, nrdt) => c.parent.toggleDeadlineNotificationTypeWithoutReload(c, d, nrdt),
                      );
                    }
                  );
                },
              ),
              onTap: () {
                setState(() {
                  c._selectedDay = null;
                  c.updateShownList();
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 10,),
              GestureDetector(
                  child: const Icon(Icons.settings,),
                  onTap: () async {
                    showDialog(context: context, builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Are these settings?"),
                        alignment: Alignment.center,
                        titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        actionsAlignment: MainAxisAlignment.center,
                        actionsOverflowAlignment: OverflowBarAlignment.center,
                        actions: [
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                            String builder = "";
                            for (Deadline d in await c.db.selectAll()) {
                              if (!d.active) builder += "(\n  ";
                              builder += "${d.title}\n";
                              if(d.description.isNotEmpty) {
                                builder += "    ${d.description}\n";
                              }
                              if (d.isTimeless()) {
                                builder += "    ${d.importance.name}\n";
                              } else {
                                if (d.hasRange()) {
                                  builder += "    ${d.startsAt?.date}-${d.startsAt?.time} -> ${d.deadlineAt?.date}-${d.deadlineAt?.time}\n";
                                } else {
                                  builder += "    ${d.deadlineAt?.date}-${d.deadlineAt?.time}\n";
                                }
                                builder += "    repeats ${d.deadlineAt?.date.repetitionType.name}\n";
                                if(d.removals.isNotEmpty) {
                                  builder += "    removals ${d.removals.where((r) => !r.allFuture).map((r) => "${r.day}")}\n";
                                  if(d.removals.where((r) => r.allFuture).isNotEmpty) {
                                    builder += "    until ${d.removals.where((r) => r.allFuture).firstOrNull?.day}\n";
                                  }
                                }
                              }
                              if (!d.active) builder += ")\n";
                              builder += "\n\n";
                            }
                            await showDialog(context: context, builder: (context) {
                              return SimpleDialog(
                                title: const Text("Calendar as Text: "),
                                children: [
                                  TextField(
                                    controller: TextEditingController(text: builder),
                                    minLines: 10,
                                    maxLines: 10,
                                  )
                                ],
                              );
                            },);

                            Navigator.of(context).pop();
                          }, child: const Text("save backup"))),
                        ]
                        // content: Text("Saved successfully"),
                      );
                    });
                  }
              ),
              const SizedBox(width: 20,),
              DropdownButton<String>(
                alignment: Alignment.centerRight,
                items: ["Show Active", "Show Month"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newlySelected) => setState(() {
                  c.parent.showWhat = ShownType.values[["Show Active", "Show Month"].indexOf(newlySelected!)];
                  c.updateShownList();
                }),
                value: ["Show Active", "Show Month"][c.parent.showWhat.index],
              ),
              const SizedBox(width: 20,),
              DropdownButton<String>(
                alignment: Alignment.centerRight,
                items: ["Hide Daily", "Show Daily"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newlySelected) => setState(() {
                  c.showDaily = newlySelected == "Show Daily";
                  c.updateShownList();
                }),
                value: c.showDaily ? "Show Daily":"Hide Daily",
              ),
            ],
          ),
        ],
      )),
    );
  }
}


class DeadlineTableCalendar extends StatefulWidget {
  final DeadlinesCalendarController c;
  const DeadlineTableCalendar(this.c, {super.key});

  @override State<DeadlineTableCalendar> createState() => _DeadlineTableCalendarState();
}

class _DeadlineTableCalendarState extends State<DeadlineTableCalendar> {
  DeadlinesCalendarController get c => widget.c;

  //calendar widget builder very rarely not called in order of days... but this fucks up the lastDrawnAtIndex...
  //so a map is required...
  Map<(int, int, int), Widget?> widgetPerDayCache = {};
  void buildWidgetsForDays() {
    widgetPerDayCache.clear();

    List<Deadline?> lastDrawnAtIndex = [];
    DateTime t = c._focusedDay;
    DateTime firstDay = DateTime(t.month==1?t.year-1:t.year, t.month==1?12:t.month-1, 1);
    DateTime lastDay = DateTime(t.month>=11?t.year+1:t.year, t.month==11?1:t.month==12?2:t.month+2, 1).subtract(const Duration(days: 1));

    DateTime co = firstDay;
    while(!co.isAfter(lastDay)) {
      widgetPerDayCache[(co.year, co.month, co.day)] = buildWidgetForDay(co, lastDrawnAtIndex);
      co = DateTime(co.year, co.month, co.day+1);
    }
  }
  Widget? buildWidgetForDay(DateTime day, List<Deadline?> lastDrawnAtIndex) {
    var events = c.getDailyEvents(day);

    const double rowHeight = 6;
    double assumedBoxWidth = MediaQuery.of(context).size.width / 8;

    List<Widget> children = [];

    ShapeDecoration? decoration;
    if(isSameDay(c._selectedDay, day)) {
      decoration = const ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))), color: Color(0xFF5C6BC0));
    } else if(isSameDay(DateTime.now(), day)) {
      decoration = const ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))), color: Color(0x5F5C6BC0));
    }
    children.add(Text("${day.day}", style: TextStyle(fontSize: 14, color: day.weekday >= 6? Theme.of(context).hintColor: null),));


    if(events.isNotEmpty) {

      List<Deadline> oneDayNormalEvents = sorted(events.where((d) => (d.isOneDay() && d.importance == Importance.normal)));
      List<Deadline> oneDayImportantEvents = sorted(events.where((d) => (d.isOneDay() && d.importance == Importance.important)));

      List<Deadline> criticalEvents = sorted(events.where((d) => d.importance == Importance.critical));
      List<Deadline> multiDayNormalEvents = sorted(events.where((d) => (!d.isOneDay() && d.importance == Importance.normal)));
      List<Deadline> multiDayImportantEvents = sorted(events.where((d) => (!d.isOneDay() && d.importance == Importance.important)));

      List<Deadline> shortEventsSorted = oneDayImportantEvents + oneDayNormalEvents;
      List<Deadline> wideEventsSorted = criticalEvents + multiDayImportantEvents + multiDayNormalEvents;

      for(Deadline d in wideEventsSorted) {
        if(d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) {
          bool found = false;
          for(var (i, lastAt) in lastDrawnAtIndex.indexed) {
            if(lastAt == null) {
              lastDrawnAtIndex[i] = d;
              found = true;
              break;
            }
          }
          if(!found) {
            lastDrawnAtIndex.add(d);
          }
        } else {
          for(var (i, lastAt) in lastDrawnAtIndex.indexed) {
            if(d.id == lastAt?.id) {
              lastDrawnAtIndex[i] = d;
              break;
            }
          }
        }
      }

      List<Deadline?> multiDayEventsDraw = [];
      multiDayEventsDraw.addAll(lastDrawnAtIndex);

      for(Deadline d in wideEventsSorted) {
        if(d.deadlineAt != null && d.deadlineAt!.date.isOnThisDay(day)) {
          var i = lastDrawnAtIndex.indexOf(d);
          if(i != -1) lastDrawnAtIndex[lastDrawnAtIndex.indexOf(d)] = null;
        }
      }
      while(lastDrawnAtIndex.isNotEmpty && lastDrawnAtIndex.last == null) {
        lastDrawnAtIndex.removeLast();
      }

      shortEventContainerFor(Deadline d) {
        return d.importance == Importance.important ?
        Container(
          margin: const EdgeInsets.only(left: 0.4, right: 0.4, bottom: 1),
          width: rowHeight * 2,
          height: rowHeight,
          decoration: ShapeDecoration(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight/2))), color: Color(d.color)),
          child: FittedBox(
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.hardEdge,
              child: Text(" ${d.title} ", style: TextStyle(color: getForegroundForColor(Color(d.color)),))
          ),
        )
            :
        Container(
          margin: const EdgeInsets.only(left: 0.4, right: 0.4, bottom: 1),
          width: rowHeight,
          height: rowHeight,
          decoration: ShapeDecoration(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight/2))), color: Color(d.color)),
        );
      }

      for (Deadline? d in multiDayEventsDraw.take(2)) {
        if(d != null) {
          FittedBox? child;
          if ((d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) || day.day == 1 || day.weekday == 1) {
            child = FittedBox(
              fit: BoxFit.fitHeight,
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerLeft,
              child: Text("${(!(d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) && (day.day == 1 || day.weekday == 1)) ? "..." : " "}${d.title} ", style: TextStyle(color: getForegroundForColor(Color(d.color)),))
            );
          }
          var radius = BorderRadius.zero;
          if ((d.startsAt?.date.isOnThisDay(day) ?? true) && (d.deadlineAt?.date.isOnThisDay(day) ?? true)) {
            radius = const BorderRadius.all(Radius.circular(rowHeight/2));
          } else if (d.startsAt?.date.isOnThisDay(day) ?? false) {
            radius = const BorderRadius.only(topLeft: Radius.circular(rowHeight/2), bottomLeft: Radius.circular(rowHeight/2));
          } else if (d.deadlineAt?.date.isOnThisDay(day) ?? false) {
            radius = const BorderRadius.only(topRight: Radius.circular(rowHeight/2), bottomRight: Radius.circular(rowHeight/2));
          }
          children.add(Container(
            margin: const EdgeInsets.only(bottom: 1),
            width: double.maxFinite,
            height: rowHeight,
            decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: radius), color: Color(d.color)),
            child: child,
          ));
        } else {
          List<Container> rowChildren = [];
          double occupiedWidth = 0;
          while(occupiedWidth + rowHeight*2 < assumedBoxWidth && shortEventsSorted.isNotEmpty) {
            var container = shortEventContainerFor(shortEventsSorted.removeAt(0));
            occupiedWidth += container.constraints!.minWidth;
            rowChildren.add(container);
          }
          if(rowChildren.isNotEmpty) {
            children.add(Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowChildren,
            ));
          } else {
            children.add(Container(
              margin: const EdgeInsets.only(bottom: 1),
              width: double.maxFinite,
              height: rowHeight,
            ));
          }
        }
      }
      for (Deadline? d in multiDayEventsDraw.skip(2)) {
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 1),
          width: double.maxFinite,
          height: 1,
          decoration: d==null?null:BoxDecoration(shape: BoxShape.rectangle, color: Color(d.color)),
        ));
      }

      while(shortEventsSorted.isNotEmpty) {
        List<Container> rowChildren = [];
        double occupiedWidth = 0;
        while(occupiedWidth + rowHeight * 2 < assumedBoxWidth && shortEventsSorted.isNotEmpty) {
          var container = shortEventContainerFor(shortEventsSorted.removeAt(0));
          occupiedWidth += container.constraints!.minWidth;
          rowChildren.add(container);
        }
        if(rowChildren.isNotEmpty) {
          children.add(Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: rowChildren,
          ));
        }
      }
    }


    var container = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: decoration,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(bottom: rowHeight/1.8),
      child: Wrap(
        alignment: WrapAlignment.center,
        clipBehavior: Clip.hardEdge,
        children: children,
      ),
    );
    if(!isSameMonth(c._focusedDay, day)) {
      return Opacity(opacity: 0.2, child: container);
    } else {
      return container;
    }
  }

  @override Widget build(BuildContext context) {
    buildWidgetsForDays();

    return TableCalendar<Deadline>(
      headerStyle: const HeaderStyle(
        formatButtonVisible : false,
      ),
      onHeaderTapped: (_) {
        c._selectedDay = null;
        c.updateShownList();
      },
      calendarFormat: CalendarFormat.month,
      firstDay: DateTime(1990),
      lastDay: DateTime(2100),
      focusedDay: c._focusedDay,
      selectedDayPredicate: (day) => isSameDay(c._selectedDay, day),
      rangeSelectionMode: RangeSelectionMode.disabled,
      eventLoader: (day) {return const [];},
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        cellAlignment: Alignment.topCenter,
        cellMargin: EdgeInsets.only(top: 3),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (isSameDay(c._selectedDay, selectedDay)) return;
        if(isSameMonth(selectedDay, focusedDay)) {
          c._selectedDay = selectedDay;
        } else {
          c._selectedDay = null;
        }
        c._focusedDay = focusedDay;
        c.updateShownList();
      },
      onPageChanged: (focusedDay) {
        c._focusedDay = focusedDay;
        c._selectedDay = null;
        c.updatePotentiallyVisibleDeadlinesFromDb().then((_) => setState(() {
          c.updateShownList();
        }));
      },
      calendarBuilders: CalendarBuilders(
        prioritizedBuilder: (context, day, events) => widgetPerDayCache[(day.year, day.month, day.day)],
      ),
    );
  }
}