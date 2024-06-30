import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/foundation.dart';

@immutable
class Deadline implements Comparable<Deadline> {
  final int? id;
  final String title;
  final String description;
  final int color;
  final DateTime? activeAfter;
  final NotifyableRepeatableDateTime? startsAt;
  final NotifyableRepeatableDateTime? deadlineAt;
  final Importance importance;
  final Iterable<Removal> removals;//note: can be only partially loaded for premature optimization and performance reasons, which is why they are not part of == and hash

  Deadline(this.id, this.title, this.description, this.color, this.activeAfter, this.startsAt, this.deadlineAt, this.importance, this.removals) {
    if(startsAt != null && deadlineAt != null) {
      if(!deadlineAt!.date.isSameRepetitionType(startsAt!.date)) throw ArgumentError("startsAt and deadline are not of the same repetition type");
      // if(startsAt!.date.isAfterWithinRepetition(deadlineAt.date)) throw ArgumentError("start after deadline");
      if(startsAt == deadlineAt) throw ArgumentError("start == deadline, set start to null instead");
      if(deadlineAt!.date.isDaily() && !deadlineAt!.date.isSameDay(startsAt!.date)) throw ArgumentError("range for daily cannot be greater 1");
      if(deadlineAt!.date.isWeekly() && deadlineAt!.date.difference(startsAt!.date).inDays > 6) throw ArgumentError("range for weekly cannot be greater 6");
      if(deadlineAt!.date.isMonthly() && deadlineAt!.date.difference(startsAt!.date).inDays > 28) throw ArgumentError("range for monthly cannot be greater 28");//todo
      if(deadlineAt!.date.isYearly() && deadlineAt!.date.difference(startsAt!.date).inDays > 31*2.5) throw ArgumentError("range for yearly cannot be greater 31*2.5 (because cache only contains three months");//todo
    }
    if(deadlineAt == null && startsAt != null) throw ArgumentError("startsAt must be null if timeless (deadlineAt == null)");
    if(removals.where((r) => r.allFuture).length >= 2) throw ArgumentError("cannot have more than one all future removals");
    if(rangeLength().inDays > 365) throw ArgumentError("range too long");
  }

  @override bool operator ==(Object other) {
    return other is Deadline &&
      id == other.id && title == other.title && description == other.description &&
      color == other.color && activeAfter == other.activeAfter &&
      startsAt == other.startsAt && deadlineAt == other.deadlineAt && importance == other.importance &&
      iterableEquals(removals, other.removals)
    ;
  }
  @override int get hashCode => Object.hash(id, title, description, color, activeAfter, startsAt, deadlineAt, importance, Object.hashAllUnordered(removals));
  @override int compareTo(Deadline other) {
    int cmp = nullableCompare(startsAt, other.startsAt);
    if(cmp != 0) return cmp;
    cmp = nullableCompare(deadlineAt, other.deadlineAt);
    if(cmp != 0) return cmp;
    cmp = importance.index.compareTo(other.importance.index);
    return cmp;
  }
  @override String toString() => "Deadline[$id, $title, $description, $color, $activeAfter, $startsAt, $deadlineAt, ${importance.name}]";

  bool isOneDay() => !hasRange() || startsAt!.date.isSameDay(deadlineAt!.date);
  bool hasRange() => startsAt != null;
  Duration rangeLength() => !hasRange()? Duration.zero : deadlineAt!.date.difference(startsAt!.date);
  bool isTimeless() => deadlineAt == null;
  bool isRepeating() => !isTimeless() && deadlineAt!.date.isRepeating();
  bool get activeAtAll => activeAfter != null;

  bool isOverdue(DateTime on) => isActiveOn(on) && !isTimeless() && deadlineAt!.isOverdue(on);
  bool isOnThisDay(DateTime day) {
    if(isTimeless() || ! (startsAt ?? deadlineAt!).date.isInitialOnOrBefore(day)) return false;
    if(hasRange()) {
      if(! includesThisDay(startsAt!.date, deadlineAt!.date, day.year, day.month, day.day, deadlineAt!.date.isWeekly()?day.weekday:-1)) return false;

      return !removals.any((r) => r.makesInvalid(day));
    } else {
      return (
        (startsAt != null && startsAt!.date.isOnThisDay(day)) ||
        (deadlineAt!.date.isOnThisDay(day))
      ) && !removals.any((r) => r.makesInvalid(day));
    }
  }
  bool willRepeatAfter(DateTime day) {
    return isRepeating() && removals.where((e) => e.allFuture && e.day.isBeforeThisDay(day)).isEmpty;
  }
  bool isActiveOn(DateTime day) => activeAtAll && day.isAfter(activeAfter!);


  Deadline copyWithId(int id) => Deadline(id, title, description, color, activeAfter, startsAt, deadlineAt, importance, removals);

  Deadline copyWithNextNotifyType(bool modifyStartsAt) => Deadline(
    id, title, description, color, activeAfter,
    modifyStartsAt && startsAt!=null?startsAt!.withNextNotifyType():startsAt,
    !modifyStartsAt && deadlineAt!=null?deadlineAt!.withNextNotifyType():deadlineAt,
    importance,
    removals
  );
  Deadline copyToggleActiveAtAll() => Deadline(id, title, description, color, activeAtAll? null : DateTime(1970), startsAt, deadlineAt, importance, removals);
  Deadline copyToggleActiveAfter(DateTime day) {
    if(!isRepeating()) {
      return copyToggleActiveAtAll();
    } else {
      var newActiveAfter = isActiveOn(day) ? day : stripTimeNullable((startsAt ?? deadlineAt)?.lastOccurrenceBefore(day));
      return Deadline(id, title, description, color, newActiveAfter, startsAt, deadlineAt, importance, removals);
    }
  }

  Deadline copyResetFirstOccurrenceTo(DateTime dayToResetTo) {
    if(!isRepeating()) throw StateError("must be repeating");
    NotifyableRepeatableDateTime? newStartsAt;
    if (startsAt != null) {
      dayToResetTo = startsAt!.nextOccurrenceAfter(dayToResetTo.add(const Duration(days: 1)))!;
      newStartsAt = NotifyableRepeatableDateTime(
          RepeatableDate(dayToResetTo.year, dayToResetTo.month, dayToResetTo.day, repetition: 1, repetitionType: startsAt!.date.repetitionType),
          startsAt!.time, startsAt!.notifyType
      );
      dayToResetTo = deadlineAt!.nextOccurrenceAfter(dayToResetTo)!;
    } else {
      dayToResetTo = deadlineAt!.nextOccurrenceAfter(dayToResetTo.add(const Duration(days: 1)))!;
    }
    var newDeadlineAt = NotifyableRepeatableDateTime(
        RepeatableDate(dayToResetTo.year, dayToResetTo.month, dayToResetTo.day, repetition: 1, repetitionType: deadlineAt!.date.repetitionType),
        deadlineAt!.time, deadlineAt!.notifyType
    );
    return Deadline(id, title, description, color, activeAfter, newStartsAt, newDeadlineAt, importance, removals);
  }
  Deadline copyRemoveOccurrence(RepeatableDate day) {
    if(!isRepeating()) throw StateError("must be repeating");
    return Deadline(id, title, description, color, activeAfter, startsAt, deadlineAt, importance, [Removal(day, false)] + removals.toList(growable: false));
  }
  Deadline copyRemoveOccurrencesAfter(RepeatableDate day) {
    if(!isRepeating()) throw StateError("must be repeating");
    if(day.isRepeating()) throw ArgumentError("day to remove after cannot be repeating");
    return Deadline(id, title, description, color, activeAfter, startsAt, deadlineAt, importance, [Removal(day, true)] + removals.where((r) => !r.allFuture).toList(growable: false));
  }
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
