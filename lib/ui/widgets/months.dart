import 'dart:math';

import 'package:deadlines/main.dart';
import 'package:deadlines/notifications/deadline_alarm_manager.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/defaults.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/utils/fitted_text.dart';
import 'package:deadlines/utils/not_dumb_grid_view.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controller.dart';

class DeadlinesCalendarController extends ChildController with Cache {
  DeadlinesCalendarController(super.parent);

  //ui choices to be restored
  var ratio = 0.6;
  double scrollOffset = 0;
  bool showDaily = false;

  @override Future<void> init() async {
    ratio = (await SharedPreferences.getInstance()).getDouble("ratio") ?? 0.6;
  }
  Future<void> safeRatio() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setDouble("ratio", ratio);
  }




  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDay;
  DateTime getSelectedMonth() => _selectedMonth;
  DateTime getFirstDayInSelectedMonth() => DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  DateTime? getSelectedDay() => _selectedDay;
  void setSelection(DateTime month, DateTime? day) {
    if(_selectedMonth != month || _selectedDay != day) {
      if(_selectedMonth != month) scrollOffset = 0;
      _selectedMonth = month;
      _selectedDay = day;
      notifyContentsChanged();
    }
  }
  void setSelectedMonth(DateTime month) {
    if(_selectedMonth != month) {
      scrollOffset = 0;
      _selectedMonth = month;
      notifyContentsChanged();
    }
  }
  void setSelectedDay(DateTime day) {
    if(_selectedDay != day) {
      _selectedDay = day;
      notifyContentsChanged();
    }
  }
  void setDayUnselected() {
    if(_selectedDay != null) {
      _selectedDay = null;
      notifyContentsChanged();
    }
  }


  final Map<(int, int), Map<int, Deadline>> _cache = {};
  @override invalidate() => l.synchronized(() => _cache.clear());
  @override Future<Deadline> add(Deadline d) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      if ((d.startsAt?.date.isInThisMonth(year, month) ?? false) || (d.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map[d.id!] = d;
      }
    });
    return d;
  });
  @override Future<void> remove(Deadline d) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      if ((d.startsAt?.date.isInThisMonth(year, month) ?? false) || (d.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map.remove(d.id!);
      }
    });
  });
  @override Future<void> update(Deadline dOld, Deadline dNew) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      bool wasRemoved;
      if ((dOld.startsAt?.date.isInThisMonth(year, month) ?? false) || (dOld.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        wasRemoved = map.remove(dOld.id!) != null;
      } else {
        wasRemoved = true;
      }
      if((dNew.startsAt?.date.isInThisMonth(year, month) ?? false) || (dNew.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        if(wasRemoved) map[dNew.id!] = dNew;
      }
    });
  });

  Future<Iterable<Deadline>> queryOrRetrieve(int year, int month) => l.synchronized(() async {
    Map<int, Deadline>? res = _cache[(year, month)];
    if(res == null) {
      res = {};
      for(var d in await parent.db.queryDeadlinesInMonth(year, month)) {
        res[d.id!] = d;
      }
      _cache[(year, month)] = res;
    }
    return res.values;
  });
  cleanCache() => l.synchronized(() {
    int year = getSelectedMonth().year;
    int month = getSelectedMonth().month;
    _cache.removeWhere((k, v) {
      var ky = k.$1;
      var km = k.$2;
      return (year == ky && (month - km).abs() > 1) ||
             (ky < year && month != 1) ||
             (ky > year && month != 12);
    });
  });
  Future<Iterable<Deadline>> queryRelevantDeadlines() async {
    int year = getSelectedMonth().year;
    int month = getSelectedMonth().month;
    Set<Deadline> deadlines = {};

    deadlines.addAll(await queryOrRetrieve(month==1?year-1:year, month==1?12:month-1));
    deadlines.addAll(await queryOrRetrieve(year, month));
    deadlines.addAll(await queryOrRetrieve(month==12?year+1:year, month==12?1:month+1));
    await cleanCache();

    return deadlines;
  }
}



class DeadlinesCalendar extends StatefulWidget {
  final DeadlinesCalendarController controller;
  const DeadlinesCalendar(this.controller, {super.key});

  @override DeadlinesCalendarState createState() => DeadlinesCalendarState();
}

class DeadlinesCalendarState extends State<DeadlinesCalendar> {
  DeadlinesCalendarController get c => widget.controller;

  late MultiSplitViewController _controller;
  @override void initState() {
    super.initState();
    _controller = MultiSplitViewController(
      areas: [
        Area(weight: c.ratio, minimalWeight: 0.33),
        Area(weight: 1.0 - c.ratio, minimalWeight: 0.15)
      ]
    );
  }
  @override void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await c.parent.newDeadline(c, context, c.getSelectedDay() ?? (isSameMonth(DateTime.now(), c.getFirstDayInSelectedMonth()) ? DateTime.now() : c.getFirstDayInSelectedMonth()));
        },
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(
            child: MultiSplitViewTheme(
              data: MultiSplitViewThemeData(
                dividerPainter: DividerPainters.background(color: Theme.of(context).colorScheme.onBackground.withAlpha(50), highlightedColor: Theme.of(context).colorScheme.onBackground.withAlpha(200))
              ),
              child: MultiSplitView(
                  axis: Axis.vertical,
                  controller: _controller,
                  onWeightChange: () {
                    c.ratio = _controller.areas[0].weight!;
                    c.safeRatio();
                  },
                  children: [DeadlineTableCalendar(c), MonthShownBelow(c,)]
              )
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
                          c.parent.db.queryDeadlinesActiveOrTimelessOrAfter(DateTime.now()).then((all) {
                            for(var d in all) {
                              DeadlineAlarms.updateAlarmsFor(d);
                            }
                          });

                          Fluttertoast.showToast(
                              msg: "Reloaded",
                              backgroundColor: Colors.white,
                              textColor: Colors.black,
                              toastLength: Toast.LENGTH_SHORT
                          );

                          if(!context.mounted) return;
                          Navigator.of(context).pop();
                        }, child: const Text("reload all alarms"))),
                        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                          String builder = "";
                          for (Deadline d in await c.parent.db.selectAll()) {
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
                          if(!context.mounted) return;
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

                          if(!context.mounted) return;
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
                onChanged: (newlySelected) => setState(() async {
                  // todo does not work properly, move these boxes elsewhere
                  c.parent.showWhat = ShownType.values[["Show Active", "Show Month"].indexOf(newlySelected!)];
                  await c.invalidate();
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
                onChanged: (newlySelected) => setState(() async {
                  // todo does not work properly, move these boxes elsewhere
                  c.showDaily = newlySelected == "Show Daily";
                  await c.invalidate();
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

class MonthShownBelow extends StatefulWidget {
  final DeadlinesCalendarController controller;
  const MonthShownBelow(this.controller, {super.key});

  @override State<MonthShownBelow> createState() => _MonthShownBelowState();
}

class _MonthShownBelowState extends State<MonthShownBelow> {
  DeadlinesCalendarController get c => widget.controller;

  late ScrollController listController;
  @override void initState() {
    super.initState();
    listController = ScrollController(initialScrollOffset: c.scrollOffset);
    listController.addListener(() {c.scrollOffset = listController.offset;});
    c.addContentListener(reload);
  }
  @override void dispose() {
    listController.dispose();
    c.removeContentListener(reload);
    super.dispose();
  }

  void reload() {
    setState(() {});
    if(c.scrollOffset != listController.offset) {
      listController.animateTo(c.scrollOffset, duration: Duration(milliseconds: 250), curve: Curves.decelerate);
    }
  }
  Future<List<((DateTime, DateTime), List<Deadline>)>> buildShownBelow() async {
    var deadlines = await c.queryRelevantDeadlines();

    final List<((DateTime, DateTime), List<Deadline>)> shownBelow = [];

    if (c.getSelectedDay() != null) {
      shownBelow.add(((c.getSelectedDay()!, c.getSelectedDay()!), getDeadlinesOnDay(c.getSelectedDay()!, candidates: deadlines, showWhat: c.parent.showWhat, showDaily: true,)));
    } else {
      //todo: improve readability and maintainability of this insanity:
      var now = DateTime.now();
      var firstDayInMonth = c.getFirstDayInSelectedMonth();

      var occurrencesInMonth = <Deadline, List<DateTime>>{};
      DateTime i = firstDayInMonth;
      while(i.month == firstDayInMonth.month) {
        var ds = getDeadlinesOnDay(i, candidates: deadlines, showWhat: c.parent.showWhat, showDaily: c.showDaily);
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

    return shownBelow;
  }
  
  @override Widget build(BuildContext context) {
    return FutureBuilder(
      future: buildShownBelow(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return Container();
        return GestureDetector(
          child: ListView.builder(
            controller: listController,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var ((dtr1, dtr2), ds) = snapshot.data![index];
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
                    (d) => c.parent.editDeadline(c, context, d.id!),
                    (d) => c.parent.deleteDeadline(c, context, d, dtr1),
                    (d) => c.parent.toggleDeadlineActive(c, context, d),
                    (d, nrdt) => c.parent.toggleDeadlineNotificationType(c, d, nrdt),
                  );
                }
              );
            },
          ),
          onTap: () {
            c.setDayUnselected();
          },
        );
      }
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

  late PageController controller;
  int getPage(DateTime d) {
    return d.year*12 + d.month;
  }
  (int, int) getYearMonthFromPage(int page) {
    return ((page / 12).floor(), page % 12);
  }

  Iterable<Deadline>? deadlines;

  @override void initState() {
    super.initState();
    controller = PageController(initialPage: getPage(c.getSelectedMonth()));
    controller.addListener(() {
      var (year, month) = getYearMonthFromPage(controller.page!.round());
      c.setSelection(DateTime(year, month, 1), null);
    });
    c.addContentListener(reloadCalendar);
    reloadCalendar();
  }
  @override void dispose() {
    controller.dispose();
    c.removeContentListener(reloadCalendar);
    super.dispose();
  }
  void reloadCalendar() {
    c.queryRelevantDeadlines().then((deadlines) {
      setState(() {
        this.deadlines = deadlines;
      });
    });
  }

  @override Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemBuilder: (context, page) {
        var (year, month) = getYearMonthFromPage(page);
        var firstDayInMonth = DateTime(year, month, 1);

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () async {
                var tappedMonth = await MainApp.navigatorKey.currentState?.pushNamed(
                    '/years',
                    arguments: c.getSelectedMonth().year
                );

                if(tappedMonth is DateTime) {
                  controller.animateToPage(getPage(tappedMonth), duration: const Duration(milliseconds: 500), curve: Curves.linear);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.elasticIn);
                    },
                    icon: const Icon(Icons.keyboard_double_arrow_left)
                  ),
                  Text(
                    "  ${DateFormat.MMMM().format(firstDayInMonth)}",
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: () {
                      controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.elasticIn);
                    },
                    icon: const Icon(Icons.keyboard_double_arrow_right)
                  ),
                ],
              ),
            ),
            Expanded(
              child: BigMonthView(
                year: year, month: month, c: c, deadlines: deadlines,
                onTapped: (day) {
                  if (c.getSelectedDay() != null && isSameDay(c.getSelectedDay()!, day)) return;
                  if(isSameMonth(day, firstDayInMonth)) {
                    c.setSelectedDay(day);
                  } else {
                    c.setDayUnselected();
                  }
                },
              )
            ),
          ],
        );
      },
    );
  }
}




class BigMonthView extends StatelessWidget {
  final DeadlinesCalendarController c;
  final Iterable<Deadline>? deadlines;
  final int year;
  final int month;

  final Function(DateTime) onTapped;

  final bool showWeekdayLabels;
  const BigMonthView({super.key, required this.year, required this.month, required this.c, required this.onTapped, this.showWeekdayLabels = true, required this.deadlines});

  @override Widget build(BuildContext context) {
    int firstWeekdayDay = DateTime(year, month, 1).weekday;
    var firstDayInMonth = DateTime(year, month, 1);
    var firstDayOfNextMonth = DateTime(year, month+1, 1);
    var numDaysInMonth = (firstWeekdayDay-1) + DateTimeRange(start: firstDayInMonth, end: firstDayOfNextMonth).duration.inDays;

    List<(Deadline?, Importance?)> lastDrawnAtIndex = [];
    return NotDumbGridView(
      xCount: 7,
      yCount: (numDaysInMonth / 7).ceil() + (showWeekdayLabels?1:0), //if correct size, not all same size which looks bad
      builder: (i) {
        if(showWeekdayLabels) {
          if(i < 7) {
            return Center(child: Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i]));
          }
        }
        var current = firstDayInMonth.add(Duration(days: -firstWeekdayDay + (i-(showWeekdayLabels?6:0))));
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => onTapped(current),
          child: buildWidgetForDay(current, lastDrawnAtIndex, context)
        );
      },
    );
  }


  Widget buildWidgetForDay(DateTime day, List<(Deadline?, Importance?)> lastDrawnAtIndex, BuildContext context) {
    Iterable<Deadline> events = deadlines == null? [] : getDeadlinesOnDay(day, candidates: deadlines!, showWhat: c.parent.showWhat, showDaily: c.showDaily);
    var today = stripTime(DateTime.now());

    ShapeDecoration decoration;
    if (c.getSelectedDay() != null && isSameDay(c.getSelectedDay()!, day)) {
      decoration = const ShapeDecoration(shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5))),
          color: Color(0xFF5C6BC0));
    } else if (isSameDay(today, day)) {
      decoration = const ShapeDecoration(shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5))),
          color: Color(0x5F5C6BC0));
    } else {
      decoration = const ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),);
    }

    List<Widget> children = [];
    children.add(Text("${day.day}", style: TextStyle(fontSize: 14, color: day.weekday >= 6 ? Theme.of(context).hintColor : null),));
    if (events.isNotEmpty) {
      List<Deadline> oneDayNormalEvents = sorted(
          events.where((d) =>
          (d.isOneDay() &&
              d.importance == Importance.normal)));
      List<Deadline> oneDayImportantEvents = sorted(
          events.where((d) =>
          (d.isOneDay() &&
              d.importance == Importance.important)));

      List<Deadline> criticalEvents = sorted(
          events.where((d) => d.importance == Importance.critical));
      List<Deadline> multiDayNormalEvents = sorted(
          events.where((d) =>
          (!d.isOneDay() &&
              d.importance == Importance.normal)));
      List<Deadline> multiDayImportantEvents = sorted(
          events.where((d) =>
          (!d.isOneDay() &&
              d.importance == Importance.important)));

      List<Deadline> shortEventsSorted = oneDayImportantEvents +
          oneDayNormalEvents;
      List<Deadline> wideEventsSorted = criticalEvents +
          multiDayImportantEvents + multiDayNormalEvents;

      for (Deadline d in wideEventsSorted) {
        if (d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) {
          bool found = false;
          for (var (i, (lastAt, imp)) in lastDrawnAtIndex.indexed) {
            var hasSameHeight = ((d.importance != Importance.critical) == (imp != Importance.critical));
            if (lastAt == null && hasSameHeight) {
              lastDrawnAtIndex[i] = (d, null);
              found = true;
              break;
            }
          }
          if (!found) {
            lastDrawnAtIndex.add((d, null));
          }
        } else {
          for (var (i, (lastAt, _)) in lastDrawnAtIndex.indexed) {
            if (d.id == lastAt?.id) {
              lastDrawnAtIndex[i] = (d, null);
              break;
            }
          }
        }
      }

      List<(Deadline?, Importance?)> multiDayEventsDraw = [];
      multiDayEventsDraw.addAll(lastDrawnAtIndex);

      for (Deadline d in wideEventsSorted) {
        if (d.deadlineAt != null && d.deadlineAt!.date.isOnThisDay(day)) {
          var i = lastDrawnAtIndex.indexOf((d, null));
          if (i != -1) lastDrawnAtIndex[i] = (null, d.importance);
        }
      }
      while (lastDrawnAtIndex.isNotEmpty && lastDrawnAtIndex.last.$1 == null) {
        lastDrawnAtIndex.removeLast();
      }

      children.add(Expanded(
        child: LayoutBuilder(builder: (context, constraints) {
          List<Widget> children = [];

          var shortEventsSortedIterator = ListIterator(shortEventsSorted);

          var rowHeight = max(1.0, constraints.maxHeight / 7);
          var maxWidth = constraints.maxWidth-5;
          var maxHeight = constraints.maxHeight-1;
          var countY = 0.0;

          shortEventContainerFor(Deadline d, double width) {
            return d.importance == Importance.important ?
            Container(
              margin: const EdgeInsets.only(left: 0.4, right: 0.4, bottom: 1),
              width: width,
              height: rowHeight,
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight / 2))), color: Color(d.color).withAlpha(d.active && !(d.isRepeating() && day.isBefore(today)) ? 255 : 155)),
              // child: FittedBox(
              //   fit: BoxFit.fitHeight,
              //   clipBehavior: Clip.hardEdge,
              //   alignment: Alignment.centerLeft,
              //   child: Text(
              //     " ${d.title} ",
              //     style: TextStyle(color: getForegroundForColor(Color(d.color)),)
              //   )
              // ),
              alignment: Alignment.center,
              child: FittedText(foreground: getForegroundForColor(Color(d.color))!.withAlpha(d.active && !(d.isRepeating() && day.isBefore(today)) ? 255 : 105), text: d.title, maxWidth: width*0.85, maxHeight: rowHeight*0.9, preferredMinFontSize: 5, maxFontSize: 10),
            )
                :
            Container(
              margin: const EdgeInsets.only(left: 0.4, right: 0.4, bottom: 1),
              width: rowHeight,
              height: rowHeight,
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight / 2))), color: Color(d.color).withAlpha(d.active && !(d.isRepeating() && day.isBefore(today)) ? 255 : 155)),
            );
          }

          for (var (d, imp) in multiDayEventsDraw) {
            var actualRowHeight = ((d?.importance ?? imp) == Importance.critical) ? rowHeight : rowHeight*0.6;
            if (d != null) {
              Widget? child;
              if ((d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) || day.day == 1 || day.weekday == 1) {
                // child = FittedBox(
                //   fit: BoxFit.fitHeight,
                //   clipBehavior: Clip.hardEdge,
                //   alignment: Alignment.centerLeft,
                //   child: Text(
                //     "${(!(d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) && (day.day == 1 || day.weekday == 1)) ? "..." : " "}${d.title} ",
                //     style: TextStyle(color: getForegroundForColor(Color(d.color)),)
                //   )
                // );
                var text = "${(!(d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) && (day.day == 1 || day.weekday == 1)) ? "..." : " "}${d.title} ";
                child = FittedText(foreground: getForegroundForColor(Color(d.color))!.withAlpha(d.active && !(d.isRepeating() && day.isBefore(today)) ? 255 : 105), text: text, maxWidth: maxWidth, maxHeight: actualRowHeight*0.9, preferredMinFontSize: 5, maxFontSize: 10);
              }
              var radius = BorderRadius.zero;
              if ((d.startsAt?.date.isOnThisDay(day) ?? true) &&
                  (d.deadlineAt?.date.isOnThisDay(day) ?? true)) {
                radius = BorderRadius.all(Radius.circular(actualRowHeight / 2));
              } else if (d.startsAt?.date.isOnThisDay(day) ?? false) {
                radius = BorderRadius.only(
                    topLeft: Radius.circular(actualRowHeight / 2),
                    bottomLeft: Radius.circular(actualRowHeight / 2));
              } else if (d.deadlineAt?.date.isOnThisDay(day) ?? false) {
                radius = BorderRadius.only(
                    topRight: Radius.circular(actualRowHeight / 2),
                    bottomRight: Radius.circular(actualRowHeight / 2));
              }
              if(countY + actualRowHeight + 1 > maxHeight) return Column(children: children);
              countY += actualRowHeight + 1;
              children.add(Container(
                margin: const EdgeInsets.only(bottom: 1),
                width: double.maxFinite,
                height: actualRowHeight,
                decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: radius), color: Color(d.color).withAlpha(d.active && !(d.isRepeating() && day.isBefore(today)) ? 255 : 155)),
                alignment: d.isOneDay() ? Alignment.center : Alignment.centerLeft,
                child: child,
              ));
            } else {
              List<Container> rowChildren = [];
              if(actualRowHeight == rowHeight) { //if space available
                double occupiedWidth = 0;
                double importantWidth = shortEventsSortedIterator.numLeft() >= 3 ?
                max(maxWidth / 3.33, rowHeight * 2) : maxWidth / (shortEventsSortedIterator.numLeft() + 0.33);
                while (occupiedWidth + importantWidth < maxWidth && shortEventsSortedIterator.hasNext()) {
                  var container = shortEventContainerFor(shortEventsSortedIterator.next(), importantWidth);
                  occupiedWidth += importantWidth;
                  rowChildren.add(container);
                }
              }
              if (rowChildren.isNotEmpty) {
                if(countY + rowHeight + 1 > maxHeight) return Column(children: children);
                countY += rowHeight + 1;
                children.add(Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: rowChildren,
                ));
              } else {
                if(countY + actualRowHeight + 1 > maxHeight) return Column(children: children);
                countY += actualRowHeight + 1;
                children.add(Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  width: double.maxFinite,
                  height: actualRowHeight,
                ));
              }
            }
          }

          while (shortEventsSortedIterator.hasNext()) {
            List<Container> rowChildren = [];
            double occupiedWidth = 0;
            double importantWidth = shortEventsSortedIterator.numLeft() >= 3 ?
            max(maxWidth / 3.33, rowHeight*2) : maxWidth / (shortEventsSortedIterator.numLeft()+0.33);
            while (occupiedWidth + importantWidth < maxWidth && shortEventsSortedIterator.hasNext()) {
              var container = shortEventContainerFor(shortEventsSortedIterator.next(), importantWidth);
              occupiedWidth += importantWidth;
              rowChildren.add(container);
            }
            if (rowChildren.isNotEmpty) {
              if(countY + rowHeight + 1 > maxHeight) return Column(children: children);
              countY += rowHeight + 1;
              children.add(Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: rowChildren,
              ));
            }
          }

          return Column(children: children);
        }),
      ));
    }

    var container = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: decoration,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
    if (!isSameMonth(c.getSelectedMonth(), day)) {
      return Opacity(opacity: 0.2, child: container);
    } else {
      return container;
    }
  }
}