import 'dart:math';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/deadline_alarm_manager.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../defaults.dart';
import 'edit.dart';

enum ShownType {
  showActive, showAll
}
class ParentController implements DeadlinesStorage {
  final DeadlinesDatabase db = DeadlinesDatabase();
  ParentController() {
    //tested that NOT technically required, except in fringe cases (first startup after reinstalling)
    db.queryDeadlinesActiveOrTimelessOrAfter(DateTime.now(), requireActive: false).then((all) {
      for(var d in all) {
        DeadlineAlarms.updateAlarmsFor(d);
      }
    });
  }
  ShownType showWhat = ShownType.showActive;

  final List<Cache> registeredCaches = [];
  void registerCache(Cache cache) {
    registeredCaches.add(cache);
  }

  @override Future<Deadline> add(Deadline d) async {
    Deadline newD = await db.add(d);
    for(var c in registeredCaches) {
      await c.add(newD);
    }
    await DeadlineAlarms.updateAlarmsFor(newD);
    return newD;
  }
  @override Future<void> remove(Deadline d) async {
    for(var c in registeredCaches) {
      await c.remove(d);
    }
    await DeadlineAlarms.cancelAlarmsFor(d);
    await db.remove(d);
  }
  @override Future<void> update(Deadline dOld, Deadline dNew) async {
    for(var c in registeredCaches) {
      await c.update(dOld, dNew);
    }
    await DeadlineAlarms.updateAlarmsFor(dNew);
    await db.update(dOld, dNew);
  }



  Future<bool> newDeadline(BuildContext context, DateTime? newAt) {
    return _editOrNew(context, null, newAt);
  }
  Future<bool> editDeadline(BuildContext context, int toEditId) {
    return _editOrNew(context, toEditId, null);
  }
  Future<bool> _editOrNew(BuildContext context, int? toEditId, DateTime? newAt) async {
    var colorScheme = Theme.of(context).colorScheme;

    Deadline? toEdit = toEditId==null?null:await db.loadById(toEditId);
    if (!context.mounted) return false;
    var newDeadline = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeadlineWidget(
          toEdit ?? Deadline(
            null,
            "", "", colors.last.value, true,
            null,
            newAt==null?null:fromDateTime(withTime(newAt, isSameDay(newAt, DateTime.now()) ? DateTime.now().hour+1 : max(6, min(22, DateTime.now().hour+1))), notify: NotificationType.silent),
            Importance.important, const []
          ),
          autofocusTitle: toEdit == null,
        )
      ),
    );
    if(newDeadline == null) {
      Fluttertoast.showToast(
        msg: "Canceled...",
        backgroundColor: colorScheme.onBackground.withAlpha(200),
        textColor: colorScheme.background,
        toastLength: Toast.LENGTH_SHORT
      );
      return false;
    }


    if(newDeadline.id == null) {
      newDeadline = await add(newDeadline);
    } else {
      await update(toEdit!, newDeadline);
    }
    return true;
  }

  void deleteDeadline(BuildContext context, Deadline d, DateTime? day) {
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
              updateWithUndoUI(context, "${d.title} on ${day.day}.${day.month}.${day.year} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
              var dNew = d.copyResetFirstOccurrenceTo(day);
              updateWithUndoUI(context, "${d.title}'s past deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and before"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrencesAfter(RepeatableDate(day.year, day.month, day.day));
              updateWithUndoUI(context, "${d.title}'s future deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and after"))),
          ]
          +
          (
          d.deadlineAt!.date.isDaily()?
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.weekly));
              updateWithUndoUI(context, "${d.title} on every ${DateFormat('EEEE').format(day)} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("This occurrence every week"))),
          ]:
          d.deadlineAt!.date.isMonthly()?
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.yearly));
              updateWithUndoUI(context, "${d.title} on every ${DateFormat('MMMM').format(day)} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("This occurrence every year"))),
          ]:
          []
          )
          +
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              deleteDeadlineAllOccurrences(context, d);
              Navigator.of(context).pop();
            }, child: const Text("Every occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: const Text("Cancel"))),
          ],
        );
      });
    } else {
      deleteDeadlineAllOccurrences(context, d);
    }
  }
  void deleteDeadlineAllOccurrences(BuildContext context, Deadline d) async {
    await remove(d);

    undoUI(
      "\"${d.title}\" deleted", Color(d.color), context,
      () => add(d),
    );
  }

  void toggleDeadlineNotificationType(Deadline d, NotifyableRepeatableDateTime nrdt) {
    update(d, d.copyWithNextNotifyType(nrdt == d.startsAt));
  }

  void toggleDeadlineActive(BuildContext context, Deadline d) {
    Deadline newD = d.copyToggleActive();
    update(d, newD);
    if(d.active) {//was active
      undoUI(
        "\"${d.title}\" is done", Color(d.color), context,
        () => update(newD, d),
      );
    }
  }

  Future<void> updateWithUndoUI(BuildContext context, String msg, Deadline d, Deadline dNew) async {
    undoUI(
      msg, Color(d.color), context,
      () => update(dNew, d),
    );
    await update(d, dNew);
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





abstract class ChildController implements Cache {
  final ParentController parent;
  ChildController(this.parent) {
    parent.registerCache(this);
  }

  final List<VoidCallback> _callbacks = [];
  void addContentListener(VoidCallback callback) => _callbacks.add(callback);
  void removeContentListener(VoidCallback callback) => _callbacks.remove(callback);
  void notifyContentsChanged() {
    for (var callback in _callbacks) {
      callback();
    }
  }

  Future<void> init() async {}
}