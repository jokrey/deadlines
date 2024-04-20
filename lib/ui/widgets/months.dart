import 'dart:math';

import 'package:deadlines/main.dart';
import 'package:deadlines/notifications/deadline_alarm_manager.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/controller/months_controller.dart';
import 'package:deadlines/ui/defaults.dart';
import 'package:deadlines/ui/widgets/deadline_list.dart';
import 'package:deadlines/utils/ui/fitted_text.dart';
import 'package:deadlines/utils/ui/not_dumb_grid_view.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../controller/parent_controller.dart';

/// Months View, shows overview of a single month (both calendar and list) and allows switching between months
class MonthsView extends StatefulWidget {
  /// Appropriate MonthsController (should exist only once per app instance, but only set in one active ui instance)
  final MonthsController controller;
  const MonthsView(this.controller, {super.key});

  @override State<MonthsView> createState() => _MonthsViewState();
}

class _MonthsViewState extends State<MonthsView> {
  MonthsController get c => widget.controller;

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
          await c.parent.newDeadline(
            context,
            c.getSelectedDay() ?? (isSameMonth(DateTime.now(), c.getFirstDayInSelectedMonth()) ? DateTime.now() : c.getFirstDayInSelectedMonth())
          );
        },
      ),
      body: SafeArea(child: Column(
        children: [
          Expanded(child: MultiSplitViewTheme(
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
              children: [_MonthsCalendarView(c), _CurrentSelectionListView(c,)]
            )
          ),),
          _MonthsViewFooter(c)
        ],
      )),
    );
  }
}


class _MonthsCalendarView extends StatefulWidget {
  final MonthsController c;
  const _MonthsCalendarView(this.c);
  @override State<_MonthsCalendarView> createState() => _MonthsCalendarViewState();
}

class _MonthsCalendarViewState extends State<_MonthsCalendarView> {
  MonthsController get c => widget.c;

  late PageController _controller;
  int _getPage(DateTime d) => d.year*12 + d.month;
  (int, int) _getYearMonthFromPage(int page) => ((page / 12).floor() - (page % 12 == 0 ? 1 : 0), page % 12 == 0 ? 12 : page % 12);

  Iterable<Deadline>? _deadlines;

  @override void initState() {
    super.initState();
    _controller = PageController(initialPage: _getPage(c.getSelectedMonth()));
    _controller.addListener(() {
      var (year, month) = _getYearMonthFromPage(_controller.page!.round());
      c.setSelection(DateTime(year, month, 1), null);
    });
    c.addContentListener(reloadCalendar);
    reloadCalendar();
  }
  @override void dispose() {
    _controller.dispose();
    c.removeContentListener(reloadCalendar);
    super.dispose();
  }
  void reloadCalendar() {
    setState(() {});
    c.ensureAllRelevantDeadlinesInCache().then((_) {
      c.getFlatCache().then((deadlines) {
        setState(() {
          _deadlines = deadlines;
        });
      });
    });
  }

  @override Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemBuilder: (context, page) {
        var (year, month) = _getYearMonthFromPage(page);
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
                  _controller.animateToPage(_getPage(tappedMonth), duration: const Duration(milliseconds: 500), curve: Curves.linear);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.elasticIn);
                    },
                    icon: const Icon(Icons.keyboard_double_arrow_left)
                  ),
                  Text(
                    DateFormat.MMMM().format(firstDayInMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: () {
                      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.elasticIn);
                    },
                    icon: const Icon(Icons.keyboard_double_arrow_right)
                  ),
                ],
              ),
            ),
            Expanded(child: _BigMonthView(
              c: c, year: year, month: month, deadlines: _deadlines, showWeekdayLabels: true,
              onTapped: (day) {
                if(day.isBefore(DateTime(1989, 11, 9))) return;
                if (c.getSelectedDay() != null && isSameDay(c.getSelectedDay()!, day)) return;
                if(isSameMonth(day, firstDayInMonth)) {
                  c.setSelectedDay(day);
                } else {
                  c.setDayUnselected();
                }
              },
            ),),
          ],
        );
      },
    );
  }
}


class _BigMonthView extends StatelessWidget {
  final MonthsController c;
  final Iterable<Deadline>? _deadlines;
  final int _year;
  final int _month;

  final Function(DateTime) _onDayTapped;

  final bool _showWeekdayLabels;
  const _BigMonthView({required int year, required int month, required this.c, required dynamic Function(DateTime) onTapped, bool showWeekdayLabels = true, required Iterable<Deadline>? deadlines})
      : _showWeekdayLabels = showWeekdayLabels, _onDayTapped = onTapped, _month = month, _year = year, _deadlines = deadlines;

  @override Widget build(BuildContext context) {
    int firstWeekdayDay = DateTime(_year, _month, 1).weekday;
    var firstDayInMonth = DateTime(_year, _month, 1);
    var firstDayOfNextMonth = DateTime(_year, _month+1, 1);
    var numDaysInMonth = (firstWeekdayDay-1) + DateTimeRange(start: firstDayInMonth, end: firstDayOfNextMonth).duration.inDays;

    List<(Deadline?, Importance?)> lastDrawnAtIndex = [];
    return NotDumbGridView(
      xCount: 7,
      yCount: (numDaysInMonth / 7).ceil() + (_showWeekdayLabels?1:0), //if correct size, not all same size which looks bad
      builder: (i) {
        if(_showWeekdayLabels && i < 7) {
          return Center(child: Text(weekdayStrings[i]));
        }
        var current = firstDayInMonth.add(Duration(days: -firstWeekdayDay + (i-(_showWeekdayLabels?6:0))));
        return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _onDayTapped(current),
            child: _buildWidgetForDay(current, _showWeekdayLabels ? i == 7 : i == 0, lastDrawnAtIndex, context)
        );
      },
    );
  }

  Widget _buildWidgetForDay(DateTime day, bool firstDayDrawn, List<(Deadline?, Importance?)> lastDrawnAtIndex, BuildContext context) {
    Iterable<Deadline> events = _deadlines == null? [] : c.getDeadlinesShownOnDay(day, candidates: _deadlines!);
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
    if(day.isBefore(DateTime(1989, 11, 9))) {
      children.add(const Icon(Icons.fence_rounded));
    } else if (events.isNotEmpty) {
      List<Deadline> oneDayNormalEvents = sorted(events.where((d) => (d.isOneDay() && d.importance == Importance.normal)));
      List<Deadline> oneDayImportantEvents = sorted(events.where((d) => (d.isOneDay() && d.importance == Importance.important)));

      List<Deadline> criticalEvents = sorted(events.where((d) => d.importance == Importance.critical));
      List<Deadline> multiDayNormalEvents = sorted(events.where((d) => (!d.isOneDay() && d.importance == Importance.normal)));
      List<Deadline> multiDayImportantEvents = sorted(events.where((d) => (!d.isOneDay() && d.importance == Importance.important)));

      List<Deadline> shortEventsSorted = oneDayImportantEvents + oneDayNormalEvents;
      List<Deadline> wideEventsSorted = criticalEvents + multiDayImportantEvents + multiDayNormalEvents;

      for (Deadline d in wideEventsSorted) {
        if (d.startsAt == null || d.startsAt!.date.isOnThisDay(day) || (firstDayDrawn && d.startsAt!.date.isBeforeThisDay(day))) {
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
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight / 2))), color: Color(d.color).withAlpha(d.isActiveOn(day) ? 255 : 155)),
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
              child: FittedText(foreground: getForegroundForColor(Color(d.color))!.withAlpha(d.isActiveOn(day)? 255 : 105), text: d.title, maxWidth: width*0.85, maxHeight: rowHeight*0.9, preferredMinFontSize: 5, maxFontSize: 10),
            )
                :
            Container(
              margin: const EdgeInsets.only(left: 0.4, right: 0.4, bottom: 1),
              width: rowHeight,
              height: rowHeight,
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(rowHeight / 2))), color: Color(d.color).withAlpha(d.isActiveOn(day) ? 255 : 155)),
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
                child = FittedText(foreground: getForegroundForColor(Color(d.color))!.withAlpha(d.isActiveOn(day) ? 255 : 105), text: text, maxWidth: maxWidth, maxHeight: actualRowHeight*0.9, preferredMinFontSize: 5, maxFontSize: 10);
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
                decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: radius), color: Color(d.color).withAlpha(d.isActiveOn(day) ? 255 : 155)),
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
    if (day.year != _year || day.month != _month) {
      return Opacity(opacity: 0.2, child: container);
    } else {
      return container;
    }
  }
}


class _CurrentSelectionListView extends StatefulWidget {
  final MonthsController controller;
  const _CurrentSelectionListView(this.controller);

  @override State<_CurrentSelectionListView> createState() => _CurrentSelectionListViewState();
}

class _CurrentSelectionListViewState extends State<_CurrentSelectionListView> {
  MonthsController get c => widget.controller;

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

  void _reload() {
    setState(() {});
    if(c.scrollOffset != _listController.offset) {
      _listController.animateTo(c.scrollOffset, duration: const Duration(milliseconds: 250), curve: Curves.decelerate).then((_) {
        c.scrollOffset = _listController.offset;
      });
    }
  }

  @override Widget build(BuildContext context) {
    return ListOfGroupedDeadlinesWidget(
      c.parent, listFuture: _buildListForSelection(), scrollController: _listController,
      onTappedOutsideItems: () => c.setDayUnselected(),
    );
  }

  Future<List<Group>> _buildListForSelection() async {
    var deadlines = await c.queryOrRetrieveCurrentMonth();

    if (c.getSelectedDay() != null) {
      return [Group.fromDay(
        c.getSelectedDay()!,
        c.getDeadlinesShownOnDay(c.getSelectedDay()!, candidates: deadlines, showDaily: true)
      ),];
    } else {
      var firstDayInMonth = c.getFirstDayInSelectedMonth();

      var occurrencesInMonth = <Deadline, List<DateTime>>{};
      DateTime i = firstDayInMonth;
      while(i.month == firstDayInMonth.month) {
        var ds = c.getDeadlinesShownOnDay(i, candidates: deadlines);
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

      return sortedGroupList(combined.entries.map((e) => Group.fromRange(e.key.$1, e.key.$2, e.value,)));
    }
  }
}


class _MonthsViewFooter extends StatefulWidget {
  final MonthsController c;
  const _MonthsViewFooter(this.c);

  @override State<_MonthsViewFooter> createState() => _MonthsViewFooterState();
}

class _MonthsViewFooterState extends State<_MonthsViewFooter> {
  @override Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 10,),
        GestureDetector(
          child: const Icon(Icons.settings,),
          onTap: () => _showSettingsDialog(),
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
            widget.c.parent.showWhat = ShownType.values[["Show Active", "Show Month"].indexOf(newlySelected!)];
            widget.c.parent.invalidateAllCaches().then((_) => widget.c.notifyContentsChanged());
          }),
          value: ["Show Active", "Show Month"][widget.c.parent.showWhat.index],
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
            widget.c.showDaily = newlySelected == "Show Daily";
            widget.c.parent.invalidateAllCaches().then((_) => widget.c.notifyContentsChanged());
          }),
          value: widget.c.showDaily ? "Show Daily":"Hide Daily",
        ),
      ],
    );
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Are these settings?"),
        alignment: Alignment.center,
        titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
            widget.c.parent.db.queryDeadlinesActiveAtAllOrTimelessOrAfter(DateTime.now(), requireActive: false).then((all) {
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
            for (Deadline d in await widget.c.parent.db.selectAll()) {
              if (!d.activeAtAll) builder += "(\n  ";
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
              if (!d.activeAtAll) builder += ")\n";
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
      );
    });
  }
}