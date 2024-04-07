import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/not_dumb_grid_view.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class YearsPage extends StatefulWidget {
  final DeadlinesDatabase db;
  final int initialYear;
  const YearsPage({super.key, required this.db, required this.initialYear});

  @override State<YearsPage> createState() => _YearsPageState();
}

class _YearsPageState extends State<YearsPage> {
  late PageController controller;
  @override void initState() {
    super.initState();

    controller = PageController(initialPage: widget.initialYear);
  }
  @override void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
          controller: controller,
          itemBuilder: (context, year) {
            return FutureBuilder(
              future: widget.db.queryActiveCriticalDeadlinesInYear(year),
              builder: (context, snapshot) {
                return Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 22),
                  child: Column(
                    children: [
                      Text(
                        "$year",
                        // style: Theme.of(context).textTheme.headlineSmall?.copyWith(shadows: DateTime.now().year == year ? [Shadow(blurRadius: 1, color: Color(0xFFF94144).withAlpha(200), offset: Offset(1, 1))] : [] ),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: DateTime.now().year == year ? const Color(0xFFF94144).withAlpha(210) : null),
                      ),
                      Expanded(
                        child: NotDumbGridView(
                          xMargin: 15, yMargin: 2, xCount: 2, yCount: 6,
                          builder: (i) => TinyMonthView(year: year, month: i+1, deadlines: snapshot.data),//Container(color: Colors.amber,),
                        ),
                      ),
                    ]
                  ),
                );
              }
            );
          },
        ),
      )
    );
  }
}

class TinyMonthView extends StatelessWidget {
  final int year;
  final int month;
  final List<Deadline>? deadlines;
  const TinyMonthView({super.key, required this.year, required this.month, required this.deadlines});

  @override Widget build(BuildContext context) {
    int firstWeekdayDay = DateTime(year, month, 1).weekday;
    var firstDayInMonth = DateTime(year, month, 1);
    var today = DateTime.now();
    // var lastDayOfMonth = DateTime(year, month+1, 1);
    // var firstDayOfNextMonth = DateTime(year, month+1, 1);
    // var numDaysInMonth = (firstWeekdayDay-1) + DateTimeRange(start: firstDayInMonth, end: firstDayOfNextMonth).duration.inDays;
    int dayOfMonth = 1;

    List<Deadline?> lastDrawnAtIndex = [];
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: isSameMonth(today, firstDayInMonth) ? const Color(0xFFF94144).withAlpha(210) : null),
          ),
          Expanded(
            child: NotDumbGridView(
              xCount: 7,
              yCount: 6, //(numDaysInMonth / 7).ceil(), //if correct size, not all same size which looks bad
              builder: (i) {
                var day = DateTime(year, month, dayOfMonth);
                if(i+1 < firstWeekdayDay || day.month != month) {
                  return Container();
                } else {
                  var eventsOnThisDay = sorted(deadlines?.where((d) => d.isOnThisDay(day)).toList(growable: false) ?? []);

                  for (Deadline d in eventsOnThisDay) {
                    if (d.startsAt?.date.isOnThisDay(day) ?? d.startsAt == null) {
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          var w = constraints.maxWidth;
                          double singleEventHeight = 1.5+1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              children: eventsToDraw.take(((constraints.maxHeight-4)/singleEventHeight).floor()).map((d) => Container(
                                color: d==null? null : Color(d.color),
                                width: w,
                                height: 1.5,
                                margin: EdgeInsets.only(
                                  left: d != null && (d.isOneDay() || d.startsAt!.date.isOnThisDay(day)) ? w*0.15 : 0,
                                  right: d != null && (d.isOneDay() || d.deadlineAt!.date.isOnThisDay(day)) ? w*0.15 : 0,
                                  bottom: 1
                                ),
                              )).toList(),
                            ),
                          );
                        },
                      ),
                      Center(
                        child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: Text(
                            "${dayOfMonth-1}", textAlign: TextAlign.center,
                            style: TextStyle(color: isSameDay(today, day) ? const Color(0xFFF94144) : null),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}