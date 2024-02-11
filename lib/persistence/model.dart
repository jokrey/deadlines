// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:sqflite/sqflite.dart' as sql;
// import 'package:table_calendar/table_calendar.dart';
//
// class Deadline {
//   int? id;
//   int? repetitionId;
//   final String title;
//   final String description;
//   final Color color;
//   final int importance;
//   final DateTime startsAt;
//   final DateTime deadlineAt;
//
//   Deadline(this.id, this.repetitionId, this.title, this.description, this.color, this.importance, this.startsAt, this.deadlineAt) {
//     if (deadlineAt.isBefore(startsAt)) throw ArgumentError("deadline before work start");
//   }
//
//   @override String toString() => title;
//   bool isOneDay() {
//     return isSameDay(startsAt, deadlineAt);
//   }
//
//   Duration rangeLength() {
//     return deadlineAt.difference(startsAt);
//   }
// }
//
// enum RepetitionType {
//   yearly, monthly, daily
// }
// class Repetition {
//   final RepetitionType type;
//   final int skipInBetween;
//   final int times;
//   Repetition(this.type, this.skipInBetween, this.times);
// }
//
//
// Future<sql.Database> getDB() async {
//   return sql.openDatabase(
//     'deadlines.db',
//     version: 1,
//     onCreate: (db, version) async {
//       await createTables(db);
//     },
//   );
// }
//
// Future<void> createTables(sql.Database db) async {
//   await db.execute("""CREATE TABLE deadlines(
//         id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
//         repetitionId INTEGER,
//         title TEXT NOT NULL,
//         description TEXT NOT NULL,
//         color int NOT NULL,
//         importance int NOT NULL,
//         startsAt DATETIME NOT NULL,
//         deadlineAt DATETIME NOT NULL
//       )
//       """);
// }
//
// int parseInt(Object? o) {
//   if (o == null) throw ArgumentError("o is null");
//   return int.parse(o.toString());
// }
// Deadline _fromMap(Map<String, Object?> m) {
//   return Deadline(
//     parseInt(m["id"]), parseInt(m["repetitionId"]),
//     m["title"].toString(), m["description"].toString(),
//     Color(parseInt(m["color"])), parseInt(m["importance"]),
//     DateTime.fromMicrosecondsSinceEpoch(parseInt(m["startsAt"])), DateTime.fromMicrosecondsSinceEpoch(parseInt(m["deadlineAt"]))
//   );
// }
// Map<String, Object?> _toMapWithoutId(Deadline d) {
//   return {"repetitionId": d.repetitionId, "title": d.title, "description": d.description, "color": d.color.value, "importance": d.importance, "startsAt": d.startsAt.microsecondsSinceEpoch, "deadlineAt": d.deadlineAt.microsecondsSinceEpoch, };
// }
//
//
// Future<List<Deadline>> queryDeadlinesInMonth(int year, int month) async {
//   final db = await getDB();
//   var beginningOfMonth = DateTime(year, month);
//   var afterEndOfMonth = beginningOfMonth.add(const Duration(days: 31)); //definitely after, might get a few event too much, but who cares
//
//   var rawResults = await db.rawQuery("""SELECT repetitionId, title, description, color, importance, startsAt, deadlineAt FROM deadlines WHERE NOT
//                                         (startsAt < ${beginningOfMonth.microsecondsSinceEpoch} AND deadlineAt < ${beginningOfMonth.microsecondsSinceEpoch})
//                                      OR (startsAt > ${afterEndOfMonth.microsecondsSinceEpoch} AND deadlineAt > ${afterEndOfMonth.microsecondsSinceEpoch})
//                                     ;""");
//   List<Deadline> found = (rawResults).map((e) => _fromMap(e)).toList();
//
//   return found;
// }
//
// Future<void> createDeadline(Deadline d, Repetition r) async {
//   if(d.rangeLength().inDays > 365) throw ArgumentError("range too long");
//   final db = await getDB();
//
//   db.transaction((txn) async {
//     int repetitionId = Random().nextInt(1<<32);
//     d.repetitionId = repetitionId;
//     await txn.insert("deadlines", _toMapWithoutId(d));
//
//
//   });
// }
//
// Future<void> deleteDeadline(Deadline d) async {
//   final db = await getDB();
//
//   await db.delete("deadlines", where: "id = ?", whereArgs: [d.id]);
// }
//
// Future<void> updateDeadline(Deadline d) async {
//   if(d.rangeLength().inDays > 365) throw ArgumentError("range too long");
//   final db = await getDB();
//
//   await db.update("deadlines", _toMapWithoutId(d), where: "id = ?", whereArgs: [d.id]);
// }


import 'dart:ui';
import 'package:deadlines/alarm_external_wrapper/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';

@immutable
class Deadline implements Comparable<Deadline> {
  final int? id;
  final String title;
  final String description;
  final int color;
  final bool active;
  final NotifyableRepeatableDateTime? startsAt;
  final NotifyableRepeatableDateTime? deadlineAt;
  final Importance importance;
  final Iterable<Removal> removals;//note: can be only partially loaded for premature optimization and performance reasons, which is why they are not part of == and hash

  Deadline(this.id, this.title, this.description, this.color, this.active, this.startsAt, this.deadlineAt, this.importance, this.removals) {
    if(startsAt != null && deadlineAt != null) {
      if(!deadlineAt!.date.isSameRepetitionType(startsAt!.date)) throw ArgumentError("startsAt and deadline are not of the same repetition type");
      // if(startsAt!.date.isAfterWithinRepetition(deadlineAt.date)) throw ArgumentError("start after deadline");
      if(startsAt == deadlineAt) throw ArgumentError("start == deadline, set start to null instead");
      if(deadlineAt!.date.isDaily() && ! deadlineAt!.date.isSameDay(startsAt!.date)) throw ArgumentError("range for daily cannot be greater 1");
      if(deadlineAt!.date.isWeekly() && deadlineAt!.date.difference(startsAt!.date).inDays > 6) throw ArgumentError("range for weekly cannot be greater 6");
      if(deadlineAt!.date.isMonthly() && deadlineAt!.date.difference(startsAt!.date).inDays > 28) throw ArgumentError("range for monthly cannot be greater 28");//todo
      if(deadlineAt!.date.isYearly() && deadlineAt!.date.difference(startsAt!.date).inDays > 31*2.5) throw ArgumentError("range for yearly cannot be greater 31*2.5 (because cache only contains three months");//todo
    }
    if(deadlineAt == null && startsAt != null) throw ArgumentError("startsAt must be null if timeless (deadlineAt == null)");
    if(removals.where((r) => r.allFuture).length >= 2) throw ArgumentError("cannot have more than one all future removals");
  }

  @override bool operator ==(Object other) {
    return other is Deadline &&
      id == other.id && title == other.title && description == other.description &&
      color == other.color && active == other.active &&
      startsAt == other.startsAt && deadlineAt == other.deadlineAt && importance == other.importance &&
      iterEquals(removals, other.removals)
    ;
  }
  @override int get hashCode => Object.hash(id, title, description, color, active, startsAt, deadlineAt, importance, Object.hashAllUnordered(removals));
  @override int compareTo(Deadline other) {
    int cmp = nullableCompare(startsAt, other.startsAt);
    if(cmp != 0) return cmp;
    cmp = nullableCompare(deadlineAt, other.deadlineAt);
    if(cmp != 0) return cmp;
    cmp = importance.index.compareTo(other.importance.index);
    return cmp;
  }
  @override String toString() => "Deadline[$id, $title, $description, $color, $active, $startsAt, $deadlineAt, ${importance.name}]";

  bool isOneDay() {
    return !hasRange() || startsAt!.date.isSameDay(deadlineAt!.date);
  }
  Duration rangeLength() {
    return !hasRange()? Duration.zero : deadlineAt!.date.difference(startsAt!.date);
  }
  bool hasRange() => startsAt != null;
  bool isOnThisDay(DateTime day) {
    if(isTimeless() || ! (startsAt ?? deadlineAt!).date.isInitialOnOrBefore(day)) return false;
    if(hasRange()) {
      if(! includesThisDay(startsAt!.date, deadlineAt!.date, day.year, day.month, day.day, deadlineAt!.date.isWeekly()?day.weekday:-1)) return false;
      var nextDeadline = deadlineAt!.nextOccurrenceAfter(day);
      return nextDeadline == null || !removals.any((r) => r.makesInvalid(nextDeadline));
    } else {
      return (
        (startsAt != null && startsAt!.date.isOnThisDay(day)) ||
        (deadlineAt!.date.isOnThisDay(day))
      ) && !removals.any((r) => r.makesInvalid(day));
    }
  }

  bool isTimeless() => deadlineAt == null;

  bool isRepeating() => !isTimeless() && deadlineAt!.date.isRepeating();

  bool isOverdue() => active && !isTimeless() && deadlineAt!.isOverdue();

  bool isOneFullDay() => startsAt != null && deadlineAt != null &&
        startsAt!.date.isSameDay(deadlineAt!.date) &&
        startsAt!.time.hour == 0 && startsAt!.time.minute == 0 &&
        deadlineAt!.time.hour == 23 && deadlineAt!.time.minute == 59;


  Deadline copyResetFirstOccurrenceTo(DateTime dayToResetTo) {
    if(!isRepeating()) throw StateError("must be repeating");
    NotifyableRepeatableDateTime? newStartsAt;
    if (startsAt != null) {
      dayToResetTo = startsAt!.date.nextOccurrenceAfter(dayToResetTo.add(const Duration(days: 1)))!;
      newStartsAt = NotifyableRepeatableDateTime(
          RepeatableDate(dayToResetTo.year, dayToResetTo.month, dayToResetTo.day, repetition: 1, repetitionType: startsAt!.date.repetitionType),
          startsAt!.time, startsAt!.notifyType
      );
      dayToResetTo = deadlineAt!.date.nextOccurrenceAfter(dayToResetTo)!;
    } else {
      dayToResetTo = deadlineAt!.date.nextOccurrenceAfter(dayToResetTo.add(const Duration(days: 1)))!;
    }
    var newDeadlineAt = NotifyableRepeatableDateTime(
      RepeatableDate(dayToResetTo.year, dayToResetTo.month, dayToResetTo.day, repetition: 1, repetitionType: deadlineAt!.date.repetitionType),
      deadlineAt!.time, deadlineAt!.notifyType
    );
    return Deadline(id, title, description, color, active, newStartsAt, newDeadlineAt, importance, removals);
  }
  Deadline copyRemoveOccurrence(RepeatableDate day) {
    if(!isRepeating()) throw StateError("must be repeating");
    return Deadline(id, title, description, color, active, startsAt, deadlineAt, importance, [Removal(day, false)] + removals.toList(growable: false));
  }
  Deadline copyRemoveOccurrencesAfter(RepeatableDate day) {
    if(!isRepeating()) throw StateError("must be repeating");
    if(day.isRepeating()) throw ArgumentError("day to remove after cannot be repeating");
    return Deadline(id, title, description, color, active, startsAt, deadlineAt, importance, [Removal(day, true)] + removals.where((r) => !r.allFuture).toList(growable: false));
  }

  Deadline copyWithNextNotifyType(bool modifyStartsAt) => Deadline(
    id, title, description, color, active,
    modifyStartsAt && startsAt!=null?startsAt!.withNextNotifyType():startsAt,
    !modifyStartsAt && deadlineAt!=null?deadlineAt!.withNextNotifyType():deadlineAt,
    importance,
    removals
  );
  copyWithNotifyType(bool modifyStartsAt, NotificationType ov) => Deadline(
    id, title, description, color, active,
    modifyStartsAt && startsAt!=null?startsAt!.withNotifyType(ov):startsAt,
    !modifyStartsAt && deadlineAt!=null?deadlineAt!.withNotifyType(ov):deadlineAt,
    importance,
    removals
  );
  Deadline copyToggleActive() => Deadline(id, title, description, color, !active, startsAt, deadlineAt, importance, removals);
  Deadline copyWithRemovals(List<Removal> removals) => Deadline(id, title, description, color, active, startsAt, deadlineAt, importance, removals);

  Deadline copyWithId(int id) => Deadline(id, title, description, color, active, startsAt, deadlineAt, importance, removals);
}

enum Importance {
  critical,
  important,
  normal
}

class Removal implements Comparable<Removal> {
  final RepeatableDate day;
  final bool allFuture;
  Removal(this.day, this.allFuture) {
    if(allFuture && day.isRepeating()) throw ArgumentError("cannot be repeating if all future");
  }

  bool makesInvalid(DateTime day) => this.day.isOnThisDay(day) || (allFuture && this.day.isBeforeThisDay(day));
  @override bool operator ==(Object other) => other is Removal && day == other.day && allFuture == other.allFuture;
  @override int get hashCode => Object.hash(allFuture, day);
  @override String toString() => "${allFuture?"from-":"at-"}${day.year}.${day.month}.${day.day}";
  @override int compareTo(Removal other) {
    return allFuture != other.allFuture? (allFuture?-1:1) : day.compareTo(other.day);
  }
}
