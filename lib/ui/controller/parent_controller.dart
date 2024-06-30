import 'dart:math';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/notifications/deadline_alarm_manager.dart';
import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../defaults.dart';
import '../widgets/edit.dart';

/// User choices of which deadlines should be shown/filtered in the ui
enum ShownType {
  showActive, showAll
}

/// A child controller that can register with the parent to be synchronized with all other
/// The ui itself can register a content listener to self update on any changes
/// The registration should be removed on disposal of the ui component
/// Should only be created once and kept in the main app state
abstract class ChildController implements Cache {
  final ParentController parent;
  ChildController(this.parent) {
    parent._registerCache(this);
  }

  /// Called on app initialization before the app is shown
  Future<void> init() async {}

  final List<VoidCallback> _callbacks = [];
  /// ui-widgets using the child controller should register here to self update on any changes
  void addContentListener(VoidCallback callback) => _callbacks.add(callback);
  /// ui-widgets should remove themselves if the are disposed of
  void removeContentListener(VoidCallback callback) => _callbacks.remove(callback);
  void notifyContentsChanged() {
    for (var callback in _callbacks) {
      callback();
    }
  }
}

/// Parent controller maintained in app's state that manages the middle layer between ui and database
/// Any changes to any deadlines must be done through this parent controller, as it will update child-caches
/// These child cache updates will automatically trigger appropriate ui-widget reloads
///
/// Also registers itself with static notify to reset the alarm to the next repetition once it is called
///     -> this is too tight coupling, but more efficient that the alternatives
///     -> problem: removals are stored in the deadline itself, not in the notify-date for memory reasons
class ParentController implements DeadlinesStorage {
  final DeadlinesDatabase db = DeadlinesDatabase();
  ParentController() {
    //tested that NOT technically required, except in fringe cases (first startup after reinstalling)
    //but still kept, because it should improve fault tolerance (which are common in notifications)
    db.queryDeadlinesActiveAtAllOrTimelessOrAfter(DateTime.now(), requireActive: false).then((all) {
      for(var d in all) {
        DeadlineAlarms.updateAlarmsFor(d);
      }
    });

    //slight break in coupling rule, because used to implement repetition functionality in notifywrapper
    staticNotify.registerNotificationOccurredCallback((id) async {
      try {
        int dlId = DeadlineAlarms.toDeadlineId(id);
        if (dlId != -1 && id < NotifyWrapper.snoozeOffset) {
          var d = await db.loadById(dlId);
          if (d != null) await DeadlineAlarms.updateAlarmsFor(d);
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }
  ShownType showWhat = ShownType.showActive;

  final List<Cache> registeredCaches = [];
  void _registerCache(Cache cache) {
    registeredCaches.add(cache);
  }
  /// invalidates all underlying caches (causing all to reload from disk), see Cache.invalidate
  Future<void> invalidateAllCaches() => Future.wait(registeredCaches.map((cache) => cache.invalidate()));

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



  /// start ui (edit-widget) for a new, empty deadline on the specified date or null for an initially timeless deadline
  Future<bool> newDeadline(BuildContext context, DateTime? newAt) {
    return _editOrNew(context, null, newAt);
  }
  /// start ui (edit-widget) and pre-fill all data from the given deadline database id
  Future<bool> editDeadline(BuildContext context, int toEditId) {
    return _editOrNew(context, toEditId, null);
  }
  Future<bool> _editOrNew(BuildContext context, int? toEditId, DateTime? newAt) async {
    var colorScheme = Theme.of(context).colorScheme;

    Deadline? toEdit = toEditId==null?null:await db.loadById(toEditId);
    if (!context.mounted) return false;
    var actualNewAt = newAt==null?null:fromDateTime(withTime(newAt, isSameDay(newAt, DateTime.now()) ? DateTime.now().hour+1 : max(6, min(22, DateTime.now().hour+1))), notify: NotificationType.silent);
    var newDeadline = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeadlineView(
          toEdit ?? Deadline(
            null,
            "", "", colors.last.value, DateTime(1970),
            null,
            actualNewAt,
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

  /// if day == null:
  ///   delete deadline from database and all caches and show undo ui (which would add the deadline again)
  /// if day != null:
  ///   show alert dialog with choice to only delete certain occurrences (store deadline back to disk with removals)
  ///   will also show undo ui, which up click would replace the new deadline with old deadline again
  Future<void> deleteDeadline(BuildContext context, Deadline d, DateTime? day) async {
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
              _updateWithUndoUI(context, "${d.title} on ${day.day}.${day.month}.${day.year} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
              var dNew = d.copyResetFirstOccurrenceTo(day);
              _updateWithUndoUI(context, "${d.title}'s past deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and before"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrencesAfter(RepeatableDate(day.year, day.month, day.day));
              _updateWithUndoUI(context, "${d.title}'s future deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("Only this and after"))),
          ]
          +
          (
          d.deadlineAt!.date.isDaily()?
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.weekly));
              _updateWithUndoUI(context, "${d.title} on every ${DateFormat('EEEE').format(day)} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("This occurrence every week"))),
          ]:
          d.deadlineAt!.date.isMonthly()?
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              var dNew = d.copyRemoveOccurrence(RepeatableDate.from(d.deadlineAt!.nextOccurrenceAfter(day)!, repetitionType: RepetitionType.yearly));
              _updateWithUndoUI(context, "${d.title} on every ${DateFormat('MMMM').format(day)} deleted", d, dNew);

              Navigator.of(context).pop();
            }, child: const Text("This occurrence every year"))),
          ]:
          []
          )
          +
          [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              _deleteDeadlineAllOccurrences(context, d);
              Navigator.of(context).pop();
            }, child: const Text("Every occurrence"))),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: const Text("Cancel"))),
          ],
        );
      });
    } else {
      await _deleteDeadlineAllOccurrences(context, d);
    }
  }
  Future<void> _deleteDeadlineAllOccurrences(BuildContext context, Deadline d) async {
    await remove(d);

    if(!context.mounted) throw Exception("require context");
    _undoUI(
      "\"${d.title}\" deleted", Color(d.color), context,
      () => add(d),
    );
  }

  /// update deadline with next notify type in database and caches
  Future<void> toggleDeadlineNotificationType(Deadline d, NotifyableRepeatableDateTime nrdt) async {
    await update(d, d.copyWithNextNotifyType(nrdt == d.startsAt));
  }

  /// update deadline with !active in database and caches
  Future<void> toggleDeadlineActiveAtAll(BuildContext context, Deadline d) async {
    Deadline newD = d.copyToggleActiveAtAll();
    await update(d, newD);
    if(d.activeAtAll) {//was active
      if(!context.mounted) throw Exception("require context");
      _undoUI(
        "\"${d.title}\" is done", Color(d.color), context,
        () => update(newD, d),
      );
    }
  }
  /// update deadline with active after given day in database and caches
  ///   (deadline will no longer be shown as active on the given day)
  Future<void> toggleDeadlineActiveOnOrAfter(BuildContext context, Deadline d, DateTime day) async {
    Deadline newD = d.copyToggleActiveAfter(day);
    await update(d, newD);
    if(d.activeAfter?.isBefore(day) ?? false) {//more was active before
      if(!context.mounted) throw Exception("require context");
      _undoUI(
        "\"${d.title}\" is done", Color(d.color), context,
        () => update(newD, d),
      );
    }
  }

  Future<void> _updateWithUndoUI(BuildContext context, String msg, Deadline d, Deadline dNew) async {
    _undoUI(
      msg, Color(d.color), context,
      () => update(dNew, d),
    );
    await update(d, dNew);
  }
}




void _undoUI(String text, Color color, BuildContext context, Function() undo) {
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