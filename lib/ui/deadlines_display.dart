import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/ui/widgets/edit.dart';
import 'package:deadlines/ui/widgets/list_of_upcoming.dart';
import 'package:deadlines/ui/widgets/calendar.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

const colors = [
  /*Color(0xFFF94144),*/ Color(0xFFF3722C), Color(0xFFF8961E), Color(0xFFF9C74F),   Color(0xFF90BE6D), Color(0xFF43AA8B), Color(0xFF577590),
  /*Colors.red,*/       Colors.deepOrange,   Colors.amber,      Colors.yellowAccent, Colors.green,    Colors.cyan,        Colors.blue,
];
Color? getForegroundForColor(Color c) {
  if (c.value == const Color(0xFFF94144).value || c.value == Colors.red.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF3722C).value || c.value == Colors.deepOrange.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF8961E).value || c.value == Colors.amber.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF9C74F).value || c.value == Colors.yellowAccent.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF90BE6D).value || c.value == Colors.green.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF43AA8B).value) {
    return Colors.white;
  } else if (c.value == Colors.cyan.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF577590).value) {
    return Colors.white;
  } else if (c.value == Colors.blue.value) {
    return Colors.black;
  } else {
    return null;
  }
}

abstract class ChildController {
  void addToCache(Deadline d);
  bool removeFromCache(Deadline d);

  void updateShownList();

  Future<void> init();
}

enum ShownType {
  showActive, showAll
}
class ParentController {
  final DeadlinesDatabase db = DeadlinesDatabase();
  ParentController() {
    db.updateAllAlarms();
  }

  ShownType showWhat = ShownType.showActive;


  Future<bool> newDeadlineWithoutReload(ChildController callingChild, BuildContext context, DateTime? newAt) {
    return _editOrNewWithoutReload(callingChild, context, null, newAt);
  }
  Future<bool> editDeadlineWithoutReload(ChildController callingChild, BuildContext context, int toEditId) {
    return _editOrNewWithoutReload(callingChild, context, toEditId, null);
  }
  Future<bool> _editOrNewWithoutReload(ChildController callingChild, BuildContext context, int? toEditId, DateTime? newAt) async {
    Deadline? toEdit = toEditId==null?null:await db.loadById(toEditId);
    var newDeadline = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeadlineWidget(
          toEdit ?? Deadline(null, "", "", colors.last.value, true, null, newAt==null?null:fromDateTime(withTime(newAt, DateTime.now().hour+1), notify: NotificationType.silent), Importance.important, const []),
          autofocusTitle: toEdit == null,
        )
      ),
    );
    print("newDeadline: $newDeadline");
    if(newDeadline == null) {
      Fluttertoast.showToast(
        msg: "Canceled...",
        backgroundColor: Theme.of(context).colorScheme.onBackground.withAlpha(200),
        textColor: Theme.of(context).colorScheme.background,
        toastLength: Toast.LENGTH_SHORT
      );
      return false;
    }

    if(toEdit != null) {
      callingChild.removeFromCache(toEdit);
    }

    if(newDeadline.id == null) {
      newDeadline = await db.createDeadline(newDeadline);
    } else {
      await db.updateDeadline(newDeadline);
    }
    callingChild.addToCache(newDeadline);
    callingChild.updateShownList();
    return true;
  }

  void deleteDeadlineWithoutReload(ChildController callingChild, BuildContext context, Deadline d, DateTime? day) {
    if(d.isRepeating() && day != null) {
      showDialog(context: context, builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Deadline?"),
          alignment: Alignment.center,
          titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!));
              updateWithUndoUI(callingChild, context, "${d.title} on ${day.day}.${day.month}.${day.year} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
              var dNew = d.copyResetFirstOccurrenceTo(day);
              updateWithUndoUI(callingChild, context, "${d.title}'s past deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and before"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrencesAfter(RepeatableDate(day.year, day.month, day.day));
              updateWithUndoUI(callingChild, context, "${d.title}'s future deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and after"))),
          ]
          +
          (
            d.deadlineAt!.date.isDaily()?
            [
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
                var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.weekly));
                updateWithUndoUI(callingChild, context, "${d.title} on every ${DateFormat('EEEE').format(day)} deleted", d, dNew);

                Navigator.of(context).pop();
              }, child: const Text("This occurrence every week"))),
            ]:
            d.deadlineAt!.date.isMonthly()?
            [
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
                var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.yearly));
                updateWithUndoUI(callingChild, context, "${d.title} on every ${DateFormat('MMMM').format(day)} deleted", d, dNew);

                Navigator.of(context).pop();
              }, child: const Text("This occurrence every year"))),
            ]:
            []
          )
          +
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              deleteDeadlineWithoutReloadAll(callingChild, context, d);
              Navigator.of(context).pop();
            }, child: const Text("Every occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: const Text("Cancel"))),
          ],
          // content: Text("Saved successfully"),
        );
      });
    } else {
      deleteDeadlineWithoutReloadAll(callingChild, context, d);
    }
  }
  void deleteDeadlineWithoutReloadAll(ChildController callingChild, BuildContext context, Deadline d) {
    db.deleteDeadline(d);
    callingChild.removeFromCache(d);
    callingChild.updateShownList();

    undoUI(
      "\"${d.title}\" deleted", Color(d.color), context,
      () async {
        d = await db.createDeadline(d);
        callingChild.addToCache(d);
        callingChild.updateShownList();
      }
    );
  }

  void toggleDeadlineNotificationTypeWithoutReload(ChildController callingChild, Deadline d, NotifyableRepeatableDateTime nrdt) {
    updateWithoutUndoUI(callingChild, d, d.copyWithNextNotifyType(nrdt == d.startsAt));
  }

  void toggleDeadlineActiveWithoutReload(ChildController callingChild, BuildContext context, Deadline d) {
    Deadline newD = d.copyToggleActive();
    updateWithoutUndoUI(callingChild, d, newD);
    if(d.active) {//was active
      undoUI(
        "\"${d.title}\" is done", Color(d.color), context,
        () {
          updateWithoutUndoUI(callingChild, newD, d);
        }
      );
    }
  }

  Future<void> updateWithoutUndoUI(ChildController callingChild, Deadline d, Deadline dNew) async {
    callingChild.removeFromCache(d);
    await db.updateDeadline(dNew);
    callingChild.addToCache(dNew);
    callingChild.updateShownList();
  }
  Future<void> updateWithUndoUI(ChildController callingChild, BuildContext context, String msg, Deadline d, Deadline dNew) async {
    await updateWithoutUndoUI(callingChild, d, dNew);
    undoUI(
      msg, Color(d.color), context,
      () => updateWithoutUndoUI(callingChild, dNew, d),
    );
  }
}




void undoUI(String text, Color color, BuildContext context, Function() undo) {
  FToast fToast = FToast();
  fToast.init(context);
  fToast.showToast(
    isDismissable: true,
    toastDuration: const Duration(seconds: 7),
    gravity: ToastGravity.BOTTOM,
    child: Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Theme.of(context).colorScheme.onBackground.withAlpha(200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 15,),
          Flexible(
            child: FittedBox(
              fit: BoxFit.cover,
              child: Text(text, style: TextStyle(color: color))
            ),
          ),
          const SizedBox(width: 15,),
          ElevatedButton(
            child: Text("UNDO", style: TextStyle(color: color),),
            onPressed: () {
              fToast.removeCustomToast();
              undo();
            },
          ),
        ],
      )
    )
  );
}




class DeadlinesDisplay extends StatefulWidget {
  const DeadlinesDisplay({super.key});

  @override State<DeadlinesDisplay> createState() => _DeadlinesDisplayState();
}

class _DeadlinesDisplayState extends State<DeadlinesDisplay> {
  final ParentController parent = ParentController();
  late final UpcomingDeadlinesListController upcomingController = UpcomingDeadlinesListController(parent);
  late final DeadlinesCalendarController calendarController = DeadlinesCalendarController(parent);

  @override Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([upcomingController.init(), calendarController.init()]),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return Container();
        return PageView.builder(
          controller: PageController(initialPage: 100000),
          itemBuilder: (context, index) {
            if (index % 2 == 0) {
              calendarController.updateShownList();
              return DeadlinesCalendar(calendarController);
            } else {
              upcomingController.updateShownList();
              return UpcomingDeadlinesList(upcomingController);
            }
          },
        );
      }
    );
  }
}



