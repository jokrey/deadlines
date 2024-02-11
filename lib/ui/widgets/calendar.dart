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
  final List<(DateTime, List<Deadline>)> shownBelow = [];

  double scrollOffset = 0;
  Function(VoidCallback)? setState;

  bool showDaily = false;

  List<Deadline> getDailyEvents(DateTime day) {
    var l = deadlinesDbCache.where((d) {
      return !d.isTimeless() && d.isOnThisDay(day) && (d.active || parent.showWhat == ShownType.showAll) /*&& (parent.showWhat != ShownType.showFuture || d.active || (d.isRepeating()/* && !day.isBefore(now)*/) || d.deadlineAt!.toDateTime().isAfter(now))*/ && (!d.deadlineAt!.date.isDaily() || showDaily);
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
        shownBelow.add((_selectedDay!, getDailyEvents(_selectedDay!)));
      } else {
        DateTime i = DateTime(_focusedDay.year, _focusedDay.month);
        while(i.month == _focusedDay.month) {
          var ds = getDailyEvents(i);
          if(ds.isNotEmpty) shownBelow.add((i, ds));
          i = i.add(const Duration(days: 1));
        }
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
                  var (dt, ds) = c.shownBelow[index];
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: ds.isEmpty?0:1+ds.length,
                    padding: const EdgeInsets.all(5),
                    itemBuilder: (context, index) {
                      if(index == 0) return Text("${dt.day}.${dt.month}.${dt.year}");
                      var d = ds[index-1];
                      return DeadlineCard(
                        d,
                        (d) => c.parent.editDeadlineWithoutReload(c, ogContext, d.id!),
                        (d) => c.parent.deleteDeadlineWithoutReload(c, ogContext, d, dt),
                        (d) => c.parent.toggleDeadlineActiveWithoutReload(c, ogContext, d),
                        (d, nrdt, ov) => c.parent.toggleDeadlineNotificationTypeWithoutReload(c, d, nrdt, ov),
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
                                if (d.isOneFullDay()) {
                                  builder += "    ${d.startsAt?.date} (all day)\n";
                                } else if (d.hasRange()) {
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
                                title: Text("Calendar as Text: "),
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
      co = co.add(const Duration(days: 1));
    }
  }
  Widget? buildWidgetForDay(DateTime day, List<Deadline?> lastDrawnAtIndex) {
    var events = c.getDailyEvents(day);

    if(events.isNotEmpty) {
      Iterable<Deadline> oneDayEvents = events.where((d) => (d.isOneDay() && !d.isOneFullDay()));
      List<Deadline> multiDayEvents = events.where((d) => (!d.isOneDay() || d.isOneFullDay())).toList(growable: false);

      List<Widget> children = [];

      for(Deadline d in multiDayEvents) {
        if(d.startsAt?.date.isOnThisDay(day) ?? false) {
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

      for(Deadline d in multiDayEvents) {
        if(d.deadlineAt != null && d.deadlineAt!.date.isOnThisDay(day)) {
          var i = lastDrawnAtIndex.indexOf(d);
          if(i != -1) lastDrawnAtIndex[lastDrawnAtIndex.indexOf(d)] = null;
        }
      }

      for (Deadline? d in multiDayEventsDraw.take(2)) {
        if(d != null) {
          FittedBox? child;
          if (d.startsAt!.date.isOnThisDay(day) || day.day == 1 || day.weekday == 1) {
            child = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text("${(!d.startsAt!.date.isOnThisDay(day) && (day.day == 1 || day.weekday == 1)) ? "..." : "  "}${d.title}", style: TextStyle(color: Color(d.color).computeLuminance() > 0.5 ? Colors.black : Colors.white),)
            );
          }
          var radius = BorderRadius.zero;
          if (d.isOneFullDay()) {
            radius = const BorderRadius.all(Radius.circular(5));
          } else if (d.startsAt!.date.isOnThisDay(day)) {
            radius = const BorderRadius.only(topLeft: Radius.circular(5), bottomLeft: Radius.circular(5));
          } else if (d.deadlineAt!.date.isOnThisDay(day)) {
            radius = const BorderRadius.only(topRight: Radius.circular(5), bottomRight: Radius.circular(5));
          }
          children.add(Container(
            margin: const EdgeInsets.only(bottom: 1),
            width: double.maxFinite,
            height: 7,
            decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: radius), color: Color(d.color)),
            child: child,
          ));
        } else {
          children.add(Container(
            margin: const EdgeInsets.only(bottom: 1),
            width: double.maxFinite,
            height: 7,
          ));
        }
      }
      for (Deadline? d in multiDayEventsDraw.skip(2).take(2)) {
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 1),
          width: double.maxFinite,
          height: 1,
          decoration: d==null?null:BoxDecoration(shape: BoxShape.rectangle, color: Color(d.color)),
        ));
      }

      children.add(ExtendedWrap(
        alignment: WrapAlignment.center,
        maxLines: 4 - min(2, multiDayEvents.length),
        children: oneDayEvents.take(30).map((d) =>
          Container(
            margin: const EdgeInsets.all(1),
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(d.color)),
          )
        ).toList(),
      ));

      return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 22),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: children
        )
      );
    } else {
      return null;
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
        outsideDaysVisible: false,
        cellAlignment: Alignment.topCenter,
        cellMargin: EdgeInsets.only(top: 3),
        selectedDecoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))), color: Color(0xFF5C6BC0)),
        todayDecoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))), color: Color(0xFF9FA8DA)),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (isSameDay(c._selectedDay, selectedDay)) return;
        c._selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, DateTime.now().hour, DateTime.now().minute);
        c._focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day, DateTime.now().hour, DateTime.now().minute);
        c.updateShownList();
      },
      onPageChanged: (focusedDay) {
        c._focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day, DateTime.now().hour, DateTime.now().minute);
        c._selectedDay = null;
        c.updatePotentiallyVisibleDeadlinesFromDb().then((_) => setState(() {
          c.updateShownList();
        }));
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) => widgetPerDayCache[(day.year, day.month, day.day)],
      ),
    );
  }
}