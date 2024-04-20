import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/controller/years_controller.dart';
import 'package:deadlines/utils/ui/not_dumb_grid_view.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


/// Years View, shows overview of a single year (calendar format) and allows switching between years
class YearsView extends StatefulWidget {
  /// Appropriate YearsController (should exist only once per app instance, but only set in one active ui instance)
  final YearsController controller;
  /// initial year to show
  final int initialYear;
  const YearsView(this.controller, {super.key, required this.initialYear});

  @override State<YearsView> createState() => _YearsViewState();
}

class _YearsViewState extends State<YearsView> {
  late PageController _controller;
  @override void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialYear);
  }
  @override void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: PageView.builder(
      controller: _controller,
      itemBuilder: (context, year) {
        return FutureBuilder(
          future: widget.controller.queryRelevantDeadlinesInYear(year),
          builder: (context, snapshot) {
            return Container(
              margin: const EdgeInsets.only(top: 12, bottom: 22),
              child: Column(
                children: [
                  Text(
                    "$year",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DateTime.now().year == year ? const Color(0xFFF94144).withAlpha(210) : null
                    ),
                  ),
                  Expanded(child: NotDumbGridView(
                    xMargin: 15, yMargin: 2, xCount: 2, yCount: 6,
                    builder: (i) => _TinyMonthView(year: year, month: i+1, deadlines: snapshot.data),
                  ),),
                ]
              ),
            );
          }
        );
      },
    ),),);
  }
}

class _TinyMonthView extends StatelessWidget {
  final int _year;
  final int _month;
  final Iterable<Deadline>? _deadlines;
  const _TinyMonthView({required int year, required int month, required Iterable<Deadline>? deadlines}) : _deadlines = deadlines, _month = month, _year = year;

  @override Widget build(BuildContext context) {
    int firstWeekdayDay = DateTime(_year, _month, 1).weekday;
    var firstDayInMonth = DateTime(_year, _month, 1);
    var today = DateTime.now();
    int dayOfMonth = 1;

    List<Deadline?> lastDrawnAtIndex = []; //to keep ranged deadlines at their index if they were ever drawn != 0
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Navigator.pop(context, firstDayInMonth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "  ${DateFormat.MMMM().format(firstDayInMonth)}",
            textAlign: TextAlign.left,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isSameMonth(today, firstDayInMonth) ? const Color(0xFFF94144).withAlpha(210) : null
            ),
          ),
          Expanded(child: NotDumbGridView(
            xCount: 7,
            yCount: 6, //(numDaysInMonth / 7).ceil(), //if correct size, not all same size which looks bad
            builder: (i) {
              var day = DateTime(_year, _month, dayOfMonth);
              if(i+1 < firstWeekdayDay || day.month != _month) {
                return Container();
              } else {
                var firstDayDrawn = i+1 == firstWeekdayDay;
                var eventsOnThisDay = sorted(_deadlines?.where((d) => d.isOnThisDay(day)).toList(growable: false) ?? []);

                for (Deadline d in eventsOnThisDay) {
                  if (d.startsAt == null || d.startsAt!.date.isOnThisDay(day) || (firstDayDrawn && d.startsAt!.date.isBeforeThisDay(day))) {
                    bool found = false;
                    for (var (i, lastAt) in lastDrawnAtIndex.indexed) {
                      if (lastAt == null) {
                        lastDrawnAtIndex[i] = d;
                        found = true;
                        break;
                      }
                    }
                    if (!found) {
                      lastDrawnAtIndex.add(d);
                    }
                  } else {
                    for (var (i, lastAt) in lastDrawnAtIndex.indexed) {
                      if (d.id == lastAt?.id) {
                        lastDrawnAtIndex[i] = d;
                        break;
                      }
                    }
                  }
                }

                List<Deadline?> eventsToDraw = [];
                eventsToDraw.addAll(lastDrawnAtIndex);

                for (Deadline d in eventsOnThisDay) {
                  if (d.deadlineAt != null && d.deadlineAt!.date.isOnThisDay(day)) {
                    var i = lastDrawnAtIndex.indexOf(d);
                    if (i != -1) lastDrawnAtIndex[i] = null;
                  }
                }
                while (lastDrawnAtIndex.isNotEmpty && lastDrawnAtIndex.last == null) {
                  lastDrawnAtIndex.removeLast();
                }

                dayOfMonth++;
                return Stack(
                  children: <Widget>[
                    day.isBefore(DateTime(1989, 11, 9)) ?
                      const Center(child: Icon(Icons.fence_rounded, size: 15,))
                      :
                      LayoutBuilder(
                        builder: (context, constraints) {
                          var w = constraints.maxWidth;
                          double singleEventHeight = 1.5+1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              children: eventsToDraw.take(((constraints.maxHeight-4)/singleEventHeight).floor()).map(
                                (d) => Container(
                                  color: d==null? null : Color(d.color),
                                  width: w,
                                  height: 1.5,
                                  margin: EdgeInsets.only(
                                    left: d != null && (d.isOneDay() || d.startsAt!.date.isOnThisDay(day)) ? w*0.15 : 0,
                                    right: d != null && (d.isOneDay() || d.deadlineAt!.date.isOnThisDay(day)) ? w*0.15 : 0,
                                    bottom: 1
                                  ),
                                ),
                              ).toList(),
                            ),
                          );
                        },
                      ),
                    Center(child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Text(
                        "${dayOfMonth-1}", textAlign: TextAlign.center,
                        style: TextStyle(color: isSameDay(today, day) ? const Color(0xFFF94144) : null),
                      ),
                    ),),
                  ],
                );
              }
            },
          ),),
        ],
      ),
    );
  }
}