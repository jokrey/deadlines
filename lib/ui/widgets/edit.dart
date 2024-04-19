import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/ui/defaults.dart';
import 'package:deadlines/utils/ui/circled_text_checkbox.dart';
import 'package:deadlines/utils/ui/date_and_time_picker.dart';
import 'package:deadlines/utils/ui/not_dumb_grid_view.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deadlines/persistence/model.dart';

/// Edit Deadline View
/// Returns the new state of the given deadline on pop using the save button or null on cancel
/// If the given and returned deadline's id equals null, the storage process must create a new deadline
class EditDeadlineView extends StatefulWidget {
  /// original deadline state at the time of starting the editing
  final Deadline original;
  /// Whether to autofocus the title input widget on start (should be done for a new deadline)
  final bool autofocusTitle;
  const EditDeadlineView(this.original, {this.autofocusTitle = false, super.key});

  @override State<StatefulWidget> createState() => _EditDeadlineViewState();
}

class _EditDeadlineViewState extends State<EditDeadlineView> {
  final TextEditingController _titleInputController = TextEditingController();
  bool _wasTitleEmpty = true;
  final TextEditingController _descriptionInputController = TextEditingController();
  DateTime? _startsAt;
  NotificationType? _startsAtNotifyType;
  DateTime? _deadlineAt;
  NotificationType? _deadlineAtNotifyType;
  static final _repetitionTypeChoices = ["None", "Yearly", "Monthly", "Weekly", "Daily"];
  RepetitionType? _repetitionType;
  int? _repetition;
  late Color _color;
  late Importance _importance;
  late List<Removal> _removals;

  @override void initState() {
    super.initState();

    _titleInputController.text = widget.original.title;
    _descriptionInputController.text = widget.original.description;
    _deadlineAt = widget.original.deadlineAt?.toDateTime();
    _deadlineAtNotifyType = widget.original.deadlineAt?.notifyType;
    if(widget.original.startsAt != null) {
      _startsAt = widget.original.startsAt!.toDateTime();
      _startsAtNotifyType = widget.original.startsAt!.notifyType;
    }
    _color = Color(widget.original.color);
    _repetitionType = widget.original.deadlineAt?.date.repetitionType;
    _repetition = widget.original.deadlineAt?.date.repetition;

    _importance = widget.original.importance;
    _removals = widget.original.removals.toSet().toList();
    _removals.sort();
  }

  @override void dispose() {
    _titleInputController.dispose();
    _descriptionInputController.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    bool allowSave = _titleInputController.text.isNotEmpty && (_startsAt==null || _deadlineAt==null || _deadlineAt!.isAfter(_startsAt!));
    if(_startsAt != null && _deadlineAt != null) {
      if (_repetitionType == RepetitionType.daily && !isSameDay(_startsAt!, _deadlineAt!)) allowSave = false;
      if (_repetitionType == RepetitionType.weekly && _deadlineAt!.difference(_startsAt!).inDays > 6) allowSave = false;
      if (_repetitionType == RepetitionType.monthly && _deadlineAt!.difference(_startsAt!).inDays > 28) allowSave = false;
      if (_repetitionType == RepetitionType.yearly && _deadlineAt!.difference(_startsAt!).inDays > 31 * 2.5) allowSave = false;
    }

    return Scaffold(
      floatingActionButton: !allowSave?null: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () {
          var fn = _startsAt==null?null:fromDateTime(_startsAt!, rep:_repetitionType!, notify: _startsAtNotifyType!);
          var ft = _deadlineAt==null?null:fromDateTime(_deadlineAt!, rep:_repetitionType!, notify: _deadlineAtNotifyType!);
          if(fn == null && ft == null) _removals.clear();
          var newD = Deadline(widget.original.id, _titleInputController.text, _descriptionInputController.text, _color.value, DateTime(1970), fn, ft, _importance, _removals);
          Navigator.pop(context, newD);
        },
      ),
      body: SafeArea(child: Dismissible(
        direction: DismissDirection.startToEnd,
        onDismissed: (_) => Navigator.pop(context,null),
        key: const Key("whatever"),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 5,),
            TextField(
              controller: _titleInputController,
              onChanged: (str) {
                if (str.isEmpty != _wasTitleEmpty) {
                  setState(() {
                    _wasTitleEmpty = str.isEmpty;
                  });
                }
              },
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: "Title"),
              autofocus: widget.autofocusTitle,
            ),
            const SizedBox(height: 25,),
            Container(
              padding: const EdgeInsets.only(left: 30, right: 30),
              child: TextField(
                controller: _descriptionInputController,
                minLines: 3,
                maxLines: 3,
                maxLength: 100,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if(newValue.text.length < oldValue.text.length) return newValue;
                    var split = newValue.text.split('\n');
                    int newLines = split.length;
                    return newLines > 3 ? oldValue : newValue;
                  }),
                ],
                decoration: const InputDecoration(hintText: "Description"),
              ),
            ),
            const SizedBox(height: 15,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(_deadlineAt == null?"ToDo:":"Importance:"),
                DropdownButton<Importance>(
                  items: Importance.values.map((Importance v) {
                    return DropdownMenuItem<Importance>(
                      value: v,
                      child: Text(v.name),
                    );
                  }).toList(),
                  onChanged: (newlySelected) => setState(() {if(newlySelected != null) _importance = newlySelected;}),
                  value: _importance,
                ),
              ],
            ),
            const SizedBox(height: 10,),
            SizedBox(
              height: 100,
              child: NotDumbGridView(
                xCount: (colors.length/2).round(), yCount: 2,
                builder: (index) {
                  Color cAtIndex = colors[index];
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        _color = cAtIndex;
                      });
                    },
                    style: IconButton.styleFrom(shape: const CircleBorder(), foregroundColor: cAtIndex, backgroundColor: Colors.transparent),
                    icon: Icon(_color.value == cAtIndex.value?Icons.circle: Icons.circle_outlined,),
                  );
                },
              ),
            ),
            const SizedBox(height: 25,),
            buildFromToDateTimePicker(),
            const SizedBox(height: 25,),
          ],
        ),),
      ),),
    );
  }

  Widget buildFromToDateTimePicker() {
    List<Widget> columnChildren = [];

    if(_deadlineAt == null) {
      columnChildren.add(TextButton(
        onPressed: () => setState(() {
          var now = DateTime.now();
          _deadlineAt = DateTime(now.year, now.month, now.day, now.hour + 1);
          _deadlineAtNotifyType = NotificationType.off;
          _repetitionType = RepetitionType.none;
          _repetition = 1;
        }),
        child: const Text("Add Deadline")
      ));
    }

    if(_deadlineAt != null) {
      List<Widget> rowChildren = [];
      if (_startsAt != null) {
        rowChildren.add(Column(
          children: [
            Row(
              children: [
                _buildNotificationSelector(
                  _startsAtNotifyType!, () {
                    setState(() {
                      _startsAtNotifyType = NotificationType.values[(_startsAtNotifyType!.index + 1) % NotificationType.values.length];
                    });
                  }
                ),
                const SizedBox(width: 10,),
                const Text("Start at", textAlign: TextAlign.center),
                const SizedBox(width: 10,),
                GestureDetector(
                  onTap: () => setState(() {
                    _startsAt = null;
                    _startsAtNotifyType = null;
                  }),
                  child: const Icon(Icons.remove_circle_rounded, size: 15,),
                ),
              ],
            ),
            NicerDatePickerWidget(
              _startsAt,
              (result) => setState(() {
                if (result != null) {
                  _startsAt = _startsAt!.copyWith(year: result.year, month: result.month, day: result.day);
                }
              })
            ),
            NicerTimePickerWidget(
              _startsAt!.hour, _startsAt!.minute,
              onChanged: (h, m) {
                bool beforeWasAfter = _deadlineAt!.isAfter(_startsAt!);
                _startsAt = _startsAt!.copyWith(hour: h, minute: m);
                if (beforeWasAfter != _deadlineAt!.isAfter(_startsAt!)) {
                  setState(() {});
                }
              },
            ),
          ],
        ));
      } else {
        rowChildren.add(TextButton(
          onPressed: () => setState(() {
            _startsAt = _deadlineAt!.copyWith();
            _deadlineAt = _deadlineAt!.add(const Duration(hours: 1));
            _startsAtNotifyType = NotificationType.off;
          }),
          child: const Text("Add Start Date")
        ));
      }

      rowChildren.add(Column(children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                setState(() {
                  _startsAt = null;
                  _startsAtNotifyType = null;
                  _deadlineAt = null;
                  _deadlineAtNotifyType = null;
                  _repetitionType = null;
                  _repetition = null;
                  _removals.clear();
                }),
              child: const Icon(Icons.remove_circle_rounded, size: 15,),
            ),
            const SizedBox(width: 10,),
            const Text("Deadline", textAlign: TextAlign.center,),
            const SizedBox(width: 10,),
            _buildNotificationSelector(
              _deadlineAtNotifyType!,
              () => setState(() {
                _deadlineAtNotifyType = NotificationType.values[(_deadlineAtNotifyType!.index + 1) % NotificationType.values.length];
              }),
            ),
          ]
        ),
        NicerDatePickerWidget(
          _deadlineAt,
          (result) => setState(() {
            if (result != null) {
              _deadlineAt = _deadlineAt!.copyWith(year: result.year, month: result.month, day: result.day);
            }
          })
        ),
        NicerTimePickerWidget(
          _deadlineAt!.hour, _deadlineAt!.minute,
          onChanged: (h, m) {
            bool beforeWasAfter = _startsAt == null || _deadlineAt!.isAfter(_startsAt!);
            _deadlineAt = _deadlineAt!.copyWith(hour: h, minute: m);
            if (beforeWasAfter != (_startsAt == null || _deadlineAt!.isAfter(_startsAt!))) {
              setState(() {});
            }
          },
        ),
      ]));

      columnChildren.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: rowChildren,
      ));

      columnChildren.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Repeat: "),
            DropdownButton<String>(
              items: _repetitionTypeChoices.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newlySelected) => setState(() {
                if (newlySelected == null) return;
                _repetition = 1;
                if (newlySelected == "None") {
                  _repetitionType = RepetitionType.none;
                } else if (newlySelected == "Yearly") {
                  _repetitionType = RepetitionType.yearly;
                } else if (newlySelected == "Monthly") {
                  _repetitionType = RepetitionType.monthly;
                } else if (newlySelected == "Weekly") {
                  _repetitionType = RepetitionType.weekly;
                } else if (newlySelected == "Daily") {
                  _repetitionType = RepetitionType.daily;
                }
              }),
              value: _repetitionType == RepetitionType.none ? "None" :
                     _repetitionType == RepetitionType.yearly ? "Yearly" :
                     _repetitionType == RepetitionType.monthly ? "Monthly" :
                     _repetitionType == RepetitionType.weekly ? "Weekly" :
                     "Daily"
            ),
          ]
          +
          (
            _repetitionType != RepetitionType.none ?
            [
              const Text(" -> until: "),
              NicerDatePickerWidget(
                _removals.where((r) => r.allFuture).firstOrNull?.day.toDateTime(),
                (result) => setState(() {
                  if (result != null) {
                    var newR = Removal(RepeatableDate.from(result), true);
                    var indexOfAllFuture = _removals.indexWhere((r) =>
                    r.allFuture);
                    if (indexOfAllFuture == -1) {
                      _removals.add(newR);
                    } else {
                      _removals[indexOfAllFuture] = newR;
                    }
                  }
                })
              ),
              const SizedBox(width: 5,),
              GestureDetector(
                onTap: () => setState(() => _removals.removeWhere((r) => r.allFuture)),
                child: Icon(Icons.delete, size: 20, color: _color,),
              ),
            ] : []
          )
      ));
      if (_repetitionType == RepetitionType.monthly) {
        var monthsInYear = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        columnChildren.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: monthsInYear.indexed.map((v) {
              var (i, e) = v;
              return CircledTextCheckbox(
                text: e,
                initial: _removals.indexWhere((r) => !r.allFuture && r.day.isYearly() && r.day.month == i + 1) != -1,
                checkedColor: null,
                notCheckedColor: _color,
                callback: (isChecked) {
                  var newR = Removal(RepeatableDate(_deadlineAt!.year, i + 1, _deadlineAt!.day, repetitionType: RepetitionType.yearly), false);
                  var indexOfBefore = _removals.indexWhere((r) =>
                  !r.allFuture && r.day.isYearly() && r.day.month == i + 1);
                  if (indexOfBefore == -1) {
                    if (_removals.where(((r) => !r.allFuture && r.day.isYearly())).length >= monthsInYear.length - 1) {
                      return false; //cannot unselect ALL
                    }
                    setState(() => _removals.add(newR));
                    return true;
                  } else {
                    setState(() => _removals.removeAt(indexOfBefore));
                    return false;
                  }
                }
              );
            }).toList(growable: false)
          ),
        ));
      }
      if (_repetitionType == RepetitionType.daily) {
        columnChildren.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: weekdayStrings.indexed.map((v) {
              var (i, e) = v;
              return CircledTextCheckbox(
                text: e,
                initial: _removals.indexWhere((r) => !r.allFuture && r.day.isWeekly() && r.day.toDateTime().weekday == i + 1) != -1,
                checkedColor: null,
                notCheckedColor: _color,
                callback: (isChecked) {
                  var d = (_startsAt ?? _deadlineAt!).copyWith();
                  while (d.weekday != i + 1) {
                    d = d.add(const Duration(days: 1));
                  }
                  var newR = Removal(RepeatableDate(d.year, d.month, d.day, repetitionType: RepetitionType.weekly), false);
                  var indexOfBefore = _removals.indexWhere((r) => !r.allFuture && r.day.isWeekly() && r.day.toDateTime().weekday == i + 1);
                  if (indexOfBefore == -1) {
                    if (_removals.where(((r) => !r.allFuture && r.day.isWeekly())).length >= weekdayStrings.length - 1) {
                      return false; //cannot unselect ALL
                    }
                    setState(() => _removals.add(newR));
                    return true;
                  } else {
                    setState(() => _removals.removeAt(indexOfBefore));
                    return false;
                  }
                }
              );
            }).toList(growable: false)
          ),
        ),);
      }

      if (_repetitionType != RepetitionType.none) {
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
                    initialDate: _deadlineAt,
                    firstDate: DateTime(1990),
                    lastDate: DateTime(2100)
                  );
                  if (date != null && _removals.where((r) => r.day.isOnThisDay(date)).isEmpty) {
                    setState(() {
                      _removals.add(Removal(RepeatableDate.from(date), false));
                    });
                  }
                },
                child: Icon(Icons.add, size: 25, color: _color),
              ),
            ]
          ),
        );

        var filteredRemovals = _removals.where(
          (r) => !(r.allFuture || (_repetitionType == RepetitionType.monthly && r.day.isYearly()) || (_repetitionType == RepetitionType.daily && r.day.isWeekly()))
        ).toList();
        columnChildren.add(ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRemovals.length,
          itemBuilder: (context, index) {
            Removal r = filteredRemovals[index];
            return ListTile(
              title: Text(
                textAlign: TextAlign.center,
                "${pad0(r.day.day)}.${pad0(r.day.month)}.${pad0(r.day.year)}${r.allFuture ? " ->" : ""}",
              ),
              leading: GestureDetector(
                child: Icon(Icons.delete, color: _color,),
                onTap: () => setState(() {
                  _removals.remove(r);
                }),
              ),
            );
          },
        ));
      }
    }

    return Column(children: columnChildren,);
  }

  GestureDetector _buildNotificationSelector(NotificationType notifyType, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        notifyType == NotificationType.off    ? Icons.notifications_off_rounded :
        notifyType == NotificationType.silent ? Icons.notifications_paused_rounded :
        notifyType == NotificationType.normal ? Icons.notifications_rounded :
        notifyType == NotificationType.fullscreen ? Icons.fullscreen_rounded :
        Icons.notifications_active_rounded,
        color: _color,
      )
    );
  }
}