import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/ui/controller/parent_controller.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:deadlines/persistence/model.dart';

/// A Card representing a deadline in a list, exposes ui features that allow the user to mutate the deadline
/// Users of the deadline card must persist that change and reload this widget
class DeadlineCard extends StatelessWidget {
  final ParentController parent;
  final Deadline d;
  final DateTime? day;
  // /// Show edit screen for this deadline
  // final Function(Deadline) edit;
  // /// Remove this deadline from storage
  // final Function(Deadline) delete;
  // /// Toggle whether the deadline is active on the given day
  // final Function(Deadline, DateTime) toggleActive;
  // /// Toggle the notification type of the given NotifyableRepeatableDateTime (either startsAt or deadlineAt)
  // final Function(Deadline, NotifyableRepeatableDateTime) toggleNotificationType;
  const DeadlineCard(this.parent, this.d, this.day, {super.key});

  Color get _appropriateColor => Color(d.color);//d.active? Color(d.color) : Color(d.color).withAlpha(150);

  @override Widget build(BuildContext context) {
    var dayOrNow = day ?? DateTime.now();
    return Dismissible(
      direction: (day==null?d.activeAtAll : d.isActiveOn(dayOrNow))? DismissDirection.endToStart : DismissDirection.startToEnd,
      background: Container(
        color: _appropriateColor,
        alignment: (day==null?d.activeAtAll : d.isActiveOn(dayOrNow))?Alignment.centerRight:Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Text((day==null?d.activeAtAll : d.isActiveOn(dayOrNow))? "Done!" : "Set to active again..."),
      ),
      key: Key(d.toString()),
      confirmDismiss: (_) async {
        if(day==null) {
          parent.toggleDeadlineActiveAtAll(context, d);
        } else {
          parent.toggleDeadlineActiveOnOrAfter(context, d, dayOrNow);
        }
        return false; //remains visible
      },
      child: Card(
        shadowColor: d.isOverdue(dayOrNow)? const Color(0xFFF94144) : _appropriateColor,
        elevation: d.isOverdue(dayOrNow)? 6 : 3,
        child: Stack(
          alignment: Alignment.center,
          children:
            <Widget>[ListTile(
              shape: const RoundedRectangleBorder( //as is parent
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              onTap: () => parent.editDeadline(context, d.id!),
              leading: GestureDetector(
                child: Icon(Icons.delete, color: _appropriateColor,),
                onTap: () => parent.deleteDeadline(context, d, day),
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
                      _buildDateTimeWidgets()
                    ],
                  )
                    :
                  _buildDateTimeWidgets()

            ),]
            +
            ((day==null?d.activeAtAll : d.isActiveOn(dayOrNow))? (d.isOverdue(dayOrNow) ? [Positioned.fill(child: IgnorePointer(child: Container(decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), color: const Color(0xFFF94144).withAlpha(7)),)))] : []) : [IgnorePointer(child: Container(height: 4, color: _appropriateColor))]),
        ),
      ),
    );
  }

  Widget _buildDateTimeWidgets() =>
    !d.hasRange() ?
      _buildDateTimeWidget(d.deadlineAt!, d.deadlineAt!, isFirst: true)
        :
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildDateTimeWidget(d.startsAt!, d.deadlineAt!, isFirst: true),
          _buildDateTimeWidget(d.deadlineAt!, d.startsAt!, isFirst: false)
        ],
      );

  Widget _buildDateTimeWidget(NotifyableRepeatableDateTime d1, NotifyableRepeatableDateTime d2, {required bool isFirst}) {
    var dayOrNow = day ?? DateTime.now();
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _dateText(d1, d2, isUpper: isFirst),
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
                color: _appropriateColor,
              ),
              onTap: () {
                if(!d1.isOverdue(dayOrNow)) {
                  parent.toggleDeadlineNotificationType(d, d1);
                }
              }
            ),
          ],
        ),
      ]
      +
      (d1.isOverdue(dayOrNow)? [Positioned(left: 0, right: 0, child: Container(height: 2, color: const Color(0xFFF94144).withAlpha(105)))] : []),
    );
  }

  String _dateText(RepeatableDateTime d1, RepeatableDateTime d2, {required bool isUpper}) {
    String s = "";
    if(!d1.date.isRepeating() && d1.date == d2.date) {
      //date label above anyways, no need to print date
    } else {
      if(isUpper) {
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
}