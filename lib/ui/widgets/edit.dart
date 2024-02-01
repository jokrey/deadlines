import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/ui/widgets/date_and_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:table_calendar/table_calendar.dart';

class EditDeadlineWidget extends StatefulWidget {
  final Deadline original;
  const EditDeadlineWidget(this.original, {super.key});

  @override State<StatefulWidget> createState() => EditDeadlineWidgetState(original);
}

class EditDeadlineWidgetState extends State<EditDeadlineWidget> {
  final Deadline original;
  TextEditingController titleInputController = TextEditingController();
  bool wasTitleEmpty = true;
  TextEditingController descriptionInputController = TextEditingController();
  DateTime? startsAt;
  NotificationType? startsAtNotifyType;
  DateTime? deadlineAt;
  NotificationType? deadlineAtNotifyType;
  static final repetitionTypeChoices = ["None", "Yearly", "Monthly", "Weekly", "Daily"];
  RepetitionType? repetitionType;
  int? repetition;
  late Color color;
  late Importance importance;
  late List<Removal> removals;

  bool get isOneFullDay => startsAt != null && deadlineAt != null &&
      isSameDay(startsAt, deadlineAt) &&
      startsAt!.hour == 0 && startsAt!.minute == 0 &&
      deadlineAt!.hour == 23 && deadlineAt!.minute == 59;

  EditDeadlineWidgetState(this.original) {
    titleInputController.text = original.title;
    descriptionInputController.text = original.description;
    deadlineAt = original.deadlineAt?.toDateTime();
    deadlineAtNotifyType = original.deadlineAt?.notifyType;
    if(original.startsAt != null) {
      startsAt = original.startsAt!.toDateTime();
      startsAtNotifyType = original.startsAt!.notifyType;
    }
    color = Color(original.color);
    repetitionType = original.deadlineAt?.date.repetitionType;
    repetition = original.deadlineAt?.date.repetition;

    if(isOneFullDay && startsAtNotifyType != null) {
      var temp = deadlineAtNotifyType;
      deadlineAtNotifyType = startsAtNotifyType!;
      startsAtNotifyType = temp;
    }
    importance = original.importance;
    removals = original.removals.toSet().toList();
    removals.sort();
  }

  @override void dispose() {
    titleInputController.dispose();
    descriptionInputController.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    bool allowSave = titleInputController.text.isNotEmpty && (startsAt==null || deadlineAt==null || deadlineAt!.isAfter(startsAt!));
    if(startsAt != null && deadlineAt != null) {
      if (repetitionType == RepetitionType.daily && !isSameDay(startsAt!, deadlineAt)) allowSave = false;
      if (repetitionType == RepetitionType.weekly && deadlineAt!.difference(startsAt!).inDays > 6) allowSave = false;
      if (repetitionType == RepetitionType.monthly && deadlineAt!.difference(startsAt!).inDays > 28) allowSave = false; //todo
      if (repetitionType == RepetitionType.yearly && deadlineAt!.difference(startsAt!).inDays > 31 * 2.5) allowSave = false; //todo
    }

    return Scaffold(
      floatingActionButton: !allowSave?null: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () {
          if(isOneFullDay) {
            var temp = deadlineAtNotifyType;
            deadlineAtNotifyType = startsAtNotifyType!;
            startsAtNotifyType = temp;
          }
          var fn = startsAt==null?null:fromDateTime(startsAt!, rep:repetitionType!, notify: startsAtNotifyType!);
          var ft = deadlineAt==null?null:fromDateTime(deadlineAt!, rep:repetitionType!, notify: deadlineAtNotifyType!);
          if(fn == null && ft == null) removals.clear();
          var newD = Deadline(original.id, titleInputController.text, descriptionInputController.text, color.value, true, fn, ft, importance, removals);
          Navigator.pop(context, newD);
        },
      ),
      body: SafeArea(
        child: Dismissible(
          direction: DismissDirection.startToEnd,
          onDismissed: (_) {
            Navigator.pop(context,null);
          },
          key: const Key("whatever"),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5,),
                TextField(
                  controller: titleInputController,
                  onChanged: (str) {
                    if (str.isEmpty != wasTitleEmpty) {
                      setState(() {
                        wasTitleEmpty = str.isEmpty;
                      });
                    }
                  },
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: "Title"),
                ),
                const SizedBox(height: 25,),
                Container(
                  padding: const EdgeInsets.only(left: 30, right: 30),
                  child: TextField(
                    controller: descriptionInputController,
                    minLines: 3,
                    maxLines: 3,
                    maxLength: 100,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if(newValue.text.length < oldValue.text.length) return newValue;
                        var split = newValue.text.split('\n');
                        // for (var s in split) {
                        //   if(s.length > 30) return oldValue;
                        // }
                        int newLines = split.length;
                        return newLines > 3 ? oldValue : newValue;
                      }),
                    ],
                    decoration: const InputDecoration(hintText: "Description"),
                  ),
                ),
                const SizedBox(height: 25,),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true, // new line
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: (colors.length / 2).round()),
                    itemBuilder: (_, index) {
                      Color cAtIndex = colors[index];
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            color = cAtIndex;
                          });
                        },
                        style: IconButton.styleFrom(shape: const CircleBorder(), foregroundColor: cAtIndex, backgroundColor: Colors.transparent),
                        icon: Icon(color.value == cAtIndex.value?Icons.circle: Icons.circle_outlined,),
                      );
                    },
                    itemCount: colors.length,
                  ),
                ),
                const SizedBox(height: 25,),
                buildFromToDateTimePicker(),
                const SizedBox(height: 25,),
              ],
            )
          )
        )
      )
    );
  }

  Widget buildFromToDateTimePicker() {
    List<Widget> columnChildren = [];

    if(deadlineAt == null) {
      columnChildren.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text("ToDo:"),
          DropdownButton<Importance>(
            items: Importance.values.map((Importance v) {
              return DropdownMenuItem<Importance>(
                value: v,
                child: Text(v.name),
              );
            }).toList(),
            onChanged: (newlySelected) => setState(() {if(newlySelected != null) importance = newlySelected;}),
            value: importance,
          ),
        ],
      ));
      columnChildren.add(TextButton(
        onPressed: () => setState(() {
          deadlineAt = DateTime.now();
          deadlineAtNotifyType = NotificationType.off;
          repetitionType = RepetitionType.none;
          repetition = 1;
        }),
        child: const Text("Add Deadline")
      ));
    }

    if(deadlineAt != null) {
      List<Widget> rowChildren = [];
      if (startsAt != null && !isOneFullDay) {
        rowChildren.add(Column(
          children: [
            Row(
              children: [
                buildNotificationSelector(
                    startsAtNotifyType!,
                        () {
                      setState(() {
                        startsAtNotifyType =
                        NotificationType.values[(startsAtNotifyType!.index +
                            1) % NotificationType.values.length];
                      });
                    }
                ),
                const SizedBox(width: 10,),
                const Text("Start at", textAlign: TextAlign.center),
                const SizedBox(width: 10,),
                GestureDetector(
                  onTap: () =>
                      setState(() {
                        startsAt = null;
                        startsAtNotifyType = null;
                      }),
                  child: const Icon(Icons.remove_circle_rounded, size: 15,),
                ),
              ],
            ),
            NicerDatePickerWidget(startsAt, (result) =>
                setState(() {
                  if (result != null) {
                    startsAt = startsAt!.copyWith(year: result.year,
                        month: result.month,
                        day: result.day);
                  }
                })
            ),
            NicerTimePickerWidget(
              startsAt!.hour, startsAt!.minute,
              onChanged: (h, m) {
                bool beforeWasAfter = deadlineAt!.isAfter(startsAt!);
                startsAt = startsAt!.copyWith(hour: h, minute: m);
                if (beforeWasAfter !=
                    deadlineAt!.isAfter(startsAt!)) setState(() {});
              },
            ),
          ],
        ));
      }

      rowChildren.add(Column(
          children:
          <Widget>[
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() {
                          startsAt = null;
                          startsAtNotifyType = null;
                          deadlineAt = null;
                          deadlineAtNotifyType = null;
                          repetitionType = null;
                          repetition = null;
                          removals.clear();
                        }),
                    child: const Icon(Icons.remove_circle_rounded, size: 15,),
                  ),
                  const SizedBox(width: 10,),
                  const Text("Deadline", textAlign: TextAlign.center,),
                  const SizedBox(width: 10,),
                  buildNotificationSelector(
                      deadlineAtNotifyType!,
                          () {
                        setState(() {
                          deadlineAtNotifyType =
                          NotificationType.values[(deadlineAtNotifyType!.index +
                              1) % NotificationType.values.length];
                        });
                      }
                  ),
                ]
            ),
            Row(
              children: <Widget>[
                NicerDatePickerWidget(deadlineAt, (result) =>
                    setState(() {
                      if (result != null) {
                        if (isOneFullDay) {
                          startsAt = startsAt!.copyWith(year: result.year,
                              month: result.month,
                              day: result.day);
                        }
                        deadlineAt = deadlineAt!.copyWith(year: result.year,
                            month: result.month,
                            day: result.day);
                      }
                    })
                ),
              ]
              +
              (startsAt == null || isOneFullDay ?
              [Row(
                children: [
                  const SizedBox(width: 5,),
                  const Text("All Day"),
                  Checkbox(
                    value: isOneFullDay,
                    onChanged: (newValue) {
                      setState(() {
                        if (newValue == true) {
                          startsAt =
                              deadlineAt!.copyWith(hour: 0, minute: 0);
                          deadlineAt =
                              deadlineAt!.copyWith(hour: 23, minute: 59);
                          startsAtNotifyType = NotificationType.off;
                        } else {
                          startsAt = null;
                          startsAtNotifyType = null;
                          var now = DateTime.now();
                          deadlineAt = deadlineAt!.copyWith(
                              hour: now.hour, minute: now.minute);
                        }
                      });
                    },
                  )
                ],
              )
              ]
                  :
              []
              ),
            ),
          ]
          +
          (!isOneFullDay ?
          [NicerTimePickerWidget(
            deadlineAt!.hour, deadlineAt!.minute,
            onChanged: (h, m) {
              bool beforeWasAfter = startsAt == null ||
                  deadlineAt!.isAfter(startsAt!);
              deadlineAt = deadlineAt!.copyWith(hour: h, minute: m);
              if (beforeWasAfter != (startsAt == null ||
                  deadlineAt!.isAfter(startsAt!))) setState(() {});
            },
          ),
          ]
              :
          []
          )
      ));

      columnChildren.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: rowChildren,
      ));

      if (startsAt == null || isOneFullDay) {
        columnChildren.add(TextButton(
            onPressed: () =>
                setState(() {
                  startsAt = deadlineAt!.copyWith();
                  deadlineAt = deadlineAt!.add(const Duration(hours: 1));
                  startsAtNotifyType = NotificationType.off;
                }),
            child: const Text("Add Start Date")
        ));
      }

      columnChildren.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Repeat: "),
            DropdownButton<String>(
              items: repetitionTypeChoices.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newlySelected) =>
                  setState(() {
                    if (newlySelected == null) return;
                    repetition = 1;
                    if (newlySelected == "None") {
                      repetitionType = RepetitionType.none;
                    } else if (newlySelected == "Yearly") {
                      repetitionType = RepetitionType.yearly;
                    } else if (newlySelected == "Monthly") {
                      repetitionType = RepetitionType.monthly;
                    } else if (newlySelected == "Weekly") {
                      repetitionType = RepetitionType.weekly;
                    } else if (newlySelected == "Daily") {
                      repetitionType = RepetitionType.daily;
                    }
                  }),
              value: repetitionType == RepetitionType.none ? "None" :
              repetitionType == RepetitionType.yearly ? "Yearly" :
              repetitionType == RepetitionType.monthly ? "Monthly" :
              repetitionType == RepetitionType.weekly ? "Weekly" : "Daily"
            ),
          ]
          +
          (
            repetitionType != RepetitionType.none ?
            [
              const Text(" -> until: "),
              NicerDatePickerWidget(removals.where((r) => r.allFuture).firstOrNull?.day.toDateTime(), (result) =>
                setState(() {
                  if (result != null) {
                    var newR = Removal(RepeatableDate.from(result), true);
                    var indexOfAllFuture = removals.indexWhere((r) =>
                    r.allFuture);
                    if (indexOfAllFuture == -1) {
                      removals.add(newR);
                    } else {
                      removals[indexOfAllFuture] = newR;
                    }
                  }
                })
              ),
              const SizedBox(width: 5,),
              GestureDetector(
                onTap: () => setState(() => removals.removeWhere((r) => r.allFuture)),
                child: Icon(Icons.delete, size: 20, color: color,),
              ),
            ] : []
          )
      ));
      if (repetitionType == RepetitionType.monthly) {
        var monthsInYear = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        columnChildren.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: monthsInYear.indexed.map((v) {
              var (i, e) = v;
              return CircledTextCheckbox(
                  text: e,
                  initial: removals.indexWhere((r) => !r.allFuture && r.day.isYearly() && r.day.month == i + 1) != -1,
                  checkedColor: null,
                  notCheckedColor: color,
                  callback: (isChecked) {
                    var newR = Removal(RepeatableDate(deadlineAt!.year, i + 1, deadlineAt!.day, repetitionType: RepetitionType.yearly), false);
                    var indexOfBefore = removals.indexWhere((r) =>
                    !r.allFuture && r.day.isYearly() && r.day.month == i + 1);
                    if (indexOfBefore == -1) {
                      if (removals.where(((r) => !r.allFuture && r.day.isYearly())).length >= monthsInYear.length - 1) {
                        return false; //cannot unselect ALL
                      }
                      setState(() => removals.add(newR));
                      return true;
                    } else {
                      setState(() => removals.removeAt(indexOfBefore));
                      return false;
                    }
                  }
              );
            }).toList(growable: false)
        ));
      }
      if (repetitionType == RepetitionType.daily) {
        var daysInWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        columnChildren.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: daysInWeek.indexed.map((v) {
              var (i, e) = v;
              return CircledTextCheckbox(
                  text: e,
                  initial: removals.indexWhere((r) => !r.allFuture && r.day.isWeekly() && r.day.toDateTime().weekday == i + 1) != -1,
                  checkedColor: null,
                  notCheckedColor: color,
                  callback: (isChecked) {
                    var d = (startsAt ?? deadlineAt!).copyWith();
                    while (d.weekday != i + 1) {
                      d = d.add(const Duration(days: 1));
                    }
                    var newR = Removal(RepeatableDate(d.year, d.month, d.day, repetitionType: RepetitionType.weekly), false);
                    var indexOfBefore = removals.indexWhere((r) => !r.allFuture && r.day.isWeekly() && r.day.toDateTime().weekday == i + 1);
                    if (indexOfBefore == -1) {
                      if (removals.where(((r) => !r.allFuture && r.day.isWeekly())).length >= daysInWeek.length - 1) {
                        return false; //cannot unselect ALL
                      }
                      setState(() => removals.add(newR));
                      return true;
                    } else {
                      setState(() => removals.removeAt(indexOfBefore));
                      return false;
                    }
                  }
              );
            }).toList(growable: false))
        );
      }

      if (repetitionType != RepetitionType.none) {
        columnChildren.add(const SizedBox(height: 15,));
        columnChildren.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Removals:", textAlign: TextAlign.center, style: TextStyle(fontSize: 15),),
              const SizedBox(width: 10,),
              GestureDetector(
                onTap: () async {
                  var date = await showDatePicker(
                    context: context,
                    locale: const Locale('en', 'GB'),
                    initialDate: deadlineAt,
                    firstDate: DateTime(1990),
                    lastDate: DateTime(2100)
                  );
                  if (date != null && removals.where((r) => r.day.isOnThisDay(date)).isEmpty) {
                    setState(() {
                      removals.add(Removal(RepeatableDate.from(date), false));
                    });
                  }
                },
                child: Icon(Icons.add, size: 25, color: color),
              ),
            ]
          ),
        );

        var filteredRemovals = removals.where((r) =>
        !(r.allFuture ||
            (repetitionType == RepetitionType.monthly && r.day.isYearly()) ||
            (repetitionType == RepetitionType.daily && r.day.isWeekly())))
            .toList();
        columnChildren.add(ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRemovals.length,
          itemBuilder: (context, index) {
            Removal r = filteredRemovals[index];
            return ListTile(
              title: Text(
                "${pad0(r.day.day)}.${pad0(r.day.month)}.${pad0(r.day.year)}${r
                    .allFuture ? " ->" : ""}", textAlign: TextAlign.center,),
              leading: GestureDetector(
                child: Icon(Icons.delete, color: color,),
                onTap: () =>
                    setState(() {
                      removals.remove(r);
                    }),
              ),
            );
          },
        ));
      }
    }

    return Column(children: columnChildren,);
  }

  GestureDetector buildNotificationSelector(NotificationType notifyType, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        notifyType == NotificationType.off    ? Icons.notifications_off_rounded :
        notifyType == NotificationType.silent ? Icons.notifications_paused_rounded :
        notifyType == NotificationType.normal ? Icons.notifications_rounded :
        notifyType == NotificationType.fullscreen ? Icons.fullscreen_rounded :
        Icons.notifications_active_rounded,
        color: color,
        // d.completed ? Icons.check_box_outlined : Icons.check_box_outline_blank_rounded,
      )
    );
  }
}


class CircledTextCheckbox extends StatefulWidget {
  final String text;
  final bool initial;
  final Color? checkedColor;
  final Color? notCheckedColor;
  final bool Function(bool) callback;
  const CircledTextCheckbox({super.key, required this.text, required this.initial, required this.checkedColor, required this.notCheckedColor, required this.callback});

  @override State<CircledTextCheckbox> createState() => _CircledTextCheckboxState();
}

class _CircledTextCheckboxState extends State<CircledTextCheckbox> {
  late bool _isChecked;
  @override void initState() {
    super.initState();
    _isChecked = widget.initial;
  }
  @override Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() {
        _isChecked = widget.callback(!_isChecked);
      }),
      child: Container(
        decoration: BoxDecoration (
          shape: BoxShape.circle,
          border: Border.all(
            color: _isChecked ? widget.checkedColor ?? Theme.of(context).primaryTextTheme.bodySmall?.color ?? Colors.black : widget.notCheckedColor ?? Theme.of(context).primaryTextTheme.bodySmall?.color ?? Colors.black  ,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Text(
          widget.text,
          style: TextStyle(
            color: _isChecked ? widget.checkedColor : widget.notCheckedColor,
            fontSize: 14
          )
        ),
      ),
    );
  }
}
