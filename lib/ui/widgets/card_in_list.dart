import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:deadlines/persistence/model.dart';

class DeadlineCard extends StatelessWidget {
  final Deadline d;
  final Function(Deadline) edit;
  final Function(Deadline) delete;
  final Function(Deadline) toggleActive;
  final Function(Deadline, NotifyableRepeatableDateTime) toggleNotificationType;
  const DeadlineCard(this.d, this.edit, this.delete, this.toggleActive, this.toggleNotificationType, {super.key});

  Color get appropriateColor => d.active? Color(d.color) : darken(Color(d.color), 35);

  @override Widget build(BuildContext context) {
    return Dismissible(
      direction: d.active? DismissDirection.endToStart : DismissDirection.startToEnd,
      background: Container(
        color: appropriateColor,
        alignment: d.active?Alignment.centerRight:Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Text(d.active? "Done!" : "Set to active again..."),
      ),
      key: Key(d.toString()),
      confirmDismiss: (_) async {
        toggleActive(d);
        return false; //remains visible
      },
      child: Card(
        shadowColor: d.isOverdue()? const Color(0xFFF94144) : appropriateColor,
        elevation: d.isOverdue()? 6 : 3,
        child: Stack(
          alignment: Alignment.center,
          children:
            <Widget>[ListTile(
              onTap: () => edit(d),
              leading: GestureDetector(
                child: Icon(Icons.delete, color: appropriateColor,),
                onTap: () => //confirmDialog(d).then((yes) {
                // if(yes)
                delete(d),
                // }),
              ),
              title: Text(d.title, softWrap: false, maxLines: 1),
              subtitle: d.description.isEmpty ? null : Text(d.description, softWrap: false, maxLines: 3,),
              trailing:
                d.isTimeless() ?
                  const Text("ToDo")
                :
                d.deadlineAt!.date.isRepeating() && (!d.deadlineAt!.date.isWeekly() || d.hasRange()) ?
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("${camel(d.deadlineAt!.date.repetitionType.name)} "),
                      buildDateTimeWidgets()
                    ],
                  )
                    :
                  buildDateTimeWidgets()

            ),]
            +
            (d.active? (d.isOverdue() ? [Positioned.fill(child: IgnorePointer(child: Container(decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), color: const Color(0xFFF94144).withAlpha(7)),)))] : []) : [IgnorePointer(child: Container(height: 4, color: appropriateColor))]),
        ),
      ),
    );
  }

  Widget buildDateTimeWidgets() =>
    !d.hasRange() ?
      buildDateTimeWidget(d.deadlineAt!, d.deadlineAt!, isFirst: true)
        :
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          buildDateTimeWidget(d.startsAt!, d.deadlineAt!, isFirst: true),
          buildDateTimeWidget(d.deadlineAt!, d.startsAt!, isFirst: false)
        ],
      );

  Widget buildDateTimeWidget(NotifyableRepeatableDateTime d1, NotifyableRepeatableDateTime d2, {required bool isFirst}) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateText(d1, d2, isFirst: isFirst),
              textAlign: TextAlign.right,
            ),
            const SizedBox(width: 15,),
            GestureDetector(
              child: Icon(
                d1.notifyType == NotificationType.off    ? Icons.notifications_off_rounded :
                d1.notifyType == NotificationType.silent ? Icons.notifications_paused_rounded :
                d1.notifyType == NotificationType.normal ? Icons.notifications_rounded :
                d1.notifyType == NotificationType.fullscreen ? Icons.fullscreen_rounded :
                Icons.notifications_active_rounded,
                color: d1.isOverdue()? darken(appropriateColor, 35) : appropriateColor,
              ),
              onTap: () {
                if(!d1.isOverdue()) {
                  toggleNotificationType(d, d1);
                }
              }
            ),
          ],
        ),
      ]
      +
      (d1.isOverdue()? [Positioned(left: 0, right: 0, child: Container(height: 2, color: darken(const Color(0xFFF94144), 35).withAlpha(105)))] : []),
    );
  }
}


Future<bool> confirmDialog(BuildContext context, Deadline d) {
  return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text('Delete "${d.title}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      }
  ).then((v) => v != null && v);
}


String pad0(int i) => i.toString().padLeft(2, "0");
String camel(String s) => s.substring(0, 1).toUpperCase() + s.substring(1);
String dateText(RepeatableDateTime d1, RepeatableDateTime d2, {required bool isFirst}) {
  String s = "";
  if(!d1.date.isRepeating() && d1.date == d2.date) {
    //date label above anyways, no need to print date
  } else {
    if(isFirst) {
      if (d1.date.isWeekly()) {
        s += "${DateFormat('EEEE').format(d1.date.toDateTime())}s ";
      } else {
        if((!d1.date.isRepeating() && (d1.date.year != d2.date.year || d1.date.month != d2.date.month || d1.date.day != d2.date.day)) || d1.date.isYearly() || d1.date.isMonthly()) {
          s+="${pad0(d1.date.day)}.";
        }
        if((!d1.date.isRepeating() && d1.date.year != d2.date.year || d1.date.month != d2.date.month) || d1.date.isYearly()) {
          s+="${pad0(d1.date.month)}.";
        }
        if(!d1.date.isRepeating() && d1.date.year != d2.date.year) {
          s+=pad0(d1.date.year);
        }
        s += " ";
      }
    } else {
      if(d1 != d2) s += "-";

      if(!d1.date.isSameDay(d2.date)) {
        if (d1.date.isWeekly()) {
          s += "${DateFormat('EEEE').format(d1.date.toDateTime())}s ";
        } else {
          if((!d1.date.isRepeating() && (d1.date.year != d2.date.year || d1.date.month != d2.date.month || d1.date.day != d2.date.day)) || d1.date.isYearly() || d1.date.isMonthly()) {
            s+="${pad0(d1.date.day)}.";
          }
          if((!d1.date.isRepeating() && d1.date.year != d2.date.year || d1.date.month != d2.date.month) || d1.date.isYearly()) {
            s+="${pad0(d1.date.month)}.";
          }
          if(!d1.date.isRepeating() && d1.date.year != d2.date.year) {
            s+=pad0(d1.date.year);
          }
          s += " ";
        }
      }
    }
  }

  s += "${pad0(d1.time.hour)}:${pad0(d1.time.minute)}";
  return s;
}