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
  final Function(Deadline, NotifyableRepeatableDateTime, NotificationType?) toggleNotificationType;
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
        shadowColor: d.isOverdue()? Colors.red : appropriateColor,
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
              title: Text(d.title),
              subtitle: d.description.isEmpty ? null : Text(d.description.replaceAll("\n", "- "), softWrap: true, maxLines: 2,),
              trailing:
                d.isTimeless() ?
                  const Text("ToDo")
                :
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
                  ),
            ),]
            +
            (d.active? [] : [Container(height: 4, color: appropriateColor)]),
        ),
      ),
    );
  }

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
                if(d1.isOverdue()) {
                  toggleNotificationType(d, d1, NotificationType.off);
                } else {
                  toggleNotificationType(d, d1, null);
                }
              }
            ),
          ],
        ),
      ]
      +
      (d1.isOverdue()? [Positioned(left: 0, right: 0, child: Container(height: 2, color: darken(Colors.red, 35)))] : []),
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
  if(isFirst) {
    if(d1.date.isRepeating() && (!d1.date.isWeekly() || d1.date != d2.date)) {
      s += "${camel(d1.date.repetitionType.name)}: ";
    }
    if(d1.date.isWeekly()) {
      s += "${DateFormat('EEEE').format(d1.date.toDateTime())}s";
    }
  }

  if(d1 != d2 && !isFirst) s += "-";

  if(!d1.date.isRepeating()) {
    s += "${pad0(d1.date.day)}.${pad0(d1.date.month)}.${pad0(d1.date.year)}";
  } else if (d1.date.isYearly()) {
    s += "${pad0(d1.date.day)}.${pad0(d1.date.month)}.";
  } else if (d1.date.isMonthly()) {
    s += "${pad0(d1.date.day)}.";
  } else if (!isFirst && d1.date != d2.date && d1.date.isWeekly()) {
    s += "${DateFormat('EEEE').format(d1.date.toDateTime())}s";
  }
  // if(d1.time != d2.time && !isFirst) s += "-";
  s += " ${d1.time.hour.toString().padLeft(2, '0')}:${d1.time.minute.toString().padLeft(2, '0')}";
  // if(d1.time != d2.time && isFirst) s += "-";
  // if(d1 != d2 && isFirst) s += "-";
  return s;
}