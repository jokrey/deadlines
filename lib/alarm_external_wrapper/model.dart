import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:flutter/cupertino.dart';

enum NotificationType {
  /// No notification even scheduled
  off,
  /// Max importance notification without sound or vibration
  silent,
  /// Normal MAX importance notification with sound and vibration according to DnD-mode
  normal,
  /// Normal notification, but fullscreen intent when screen off
  fullscreen,
  /// Uses all means to intrude
  /// fullscreen intent(screen off or app running) / system alert window(screen on),
  /// alarm channel sound,
  /// vibrations
  alarm
}

@immutable
class NotifyableRepeatableDateTime extends RepeatableDateTime {
  final NotificationType notifyType;
  const NotifyableRepeatableDateTime(super.date, super.time, this.notifyType);

  @override bool operator ==(Object other) {
    return other is NotifyableRepeatableDateTime &&
        super.date == other.date && super.time == other.time && notifyType == other.notifyType;
  }
  @override int get hashCode => Object.hash(super.hashCode, notifyType);
  @override String toString() => "NRDT[${notifyType.index}, $date-$time]";

  NotifyableRepeatableDateTime withNextNotifyType([List<NotificationType> allowed = NotificationType.values]) => withNotifyType(allowed[(allowed.indexOf(notifyType)+1) % allowed.length]);
  NotifyableRepeatableDateTime withNotifyType(NotificationType type) => NotifyableRepeatableDateTime(date, time, type);
}

NotifyableRepeatableDateTime fromDateTime(DateTime dt, {RepetitionType rep = RepetitionType.none, NotificationType notify = NotificationType.off}) {
  return NotifyableRepeatableDateTime(
      RepeatableDate(dt.year, dt.month, dt.day, repetitionType: rep, repetition: 1),
      Time(dt.hour, dt.minute, dt.second),
      notify
  );
}



@immutable
class RepeatableDateTime implements Comparable<RepeatableDateTime> {
  final RepeatableDate date;
  final Time time;

  const RepeatableDateTime(this.date, this.time);

  @override bool operator ==(Object other) {
    return other is RepeatableDateTime && date == other.date && time == other.time;
  }
  @override int get hashCode => Object.hash(date, time);

  @override int compareTo(RepeatableDateTime other) {
    var dateCompare = date.compareTo(other.date);
    return dateCompare != 0 ? dateCompare : time.compareTo(other.time);
  }

  DateTime toDateTime() {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second);
  }

  bool isOverdue() => !date.isRepeating() && toDateTime().isBefore(DateTime.now());

  DateTime? lastOccurrenceBefore(DateTime reference) => date.lastOccurrenceBefore(reference, time);
  DateTime? nextOccurrenceAfter(DateTime reference) => date.nextOccurrenceAfter(reference, time);
}

class Time implements Comparable<Time> {
  final int hour;
  final int minute;
  final int second;

  Time(this.hour, this.minute, [this.second = 0]) {
    if(hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
      throw ArgumentError("hour($hour) or minute($minute) or second($second) invalid");
    }
  }

  @override bool operator ==(Object other) {
    return other is Time && hour == other.hour && minute == other.minute && second == other.second;
  }
  @override int get hashCode => Object.hash(hour, minute, second);
  @override String toString() => "${pad0(hour)}:${pad0(minute)}:${pad0(second)}";

  @override int compareTo(Time other) {
    return hour != other.hour ? hour - other.hour : minute != other.minute ? minute - other.minute : second - other.second;
  }
}


enum RepetitionType {
  none,yearly,monthly,weekly,daily,hourly,minutely
}

class RepeatableDate implements Comparable<RepeatableDate> {
  final int year;
  final int month;
  final int day;

  final RepetitionType repetitionType;
  final int repetition;

  RepeatableDate(this.year, this.month, this.day, {this.repetitionType = RepetitionType.none, this.repetition = 1}) {
    if(repetitionType == RepetitionType.weekly && repetition != 1) throw ArgumentError("weekly not doable with repetition != 1");
  }

  @override operator==(Object other) => other is RepeatableDate && year == other.year && month == other.month && day == other.day && repetitionType == other.repetitionType && repetition == other.repetition;
  @override int get hashCode => Object.hash(year, month, day, repetitionType, repetition);
  @override int compareTo(RepeatableDate other) {
    if(!isSameRepetitionType(other)) return repetitionType.index - other.repetitionType.index;
    if(!isRepeating()) {
      if (year != other.year) return year - other.year;
      if (month != other.month) return month - other.month;
      if (day != other.day) return day - other.day;
    }
    if(isYearly()) {
      if (month != other.month) return month - other.month;
      if (day != other.day) return day - other.day;
    }
    if(isMonthly()) {
      if (day != other.day) return day - other.day;
    }
    if(isWeekly()) return toDateTime().weekday - other.toDateTime().weekday;
    return 0;
  }
  @override String toString() {
    return "$year-$month-$day";
  }

  bool isSameRepetitionType(RepeatableDate o) {
    return repetitionType == o.repetitionType && repetition == o.repetition;
  }
  bool isInThisRepetition(int orig, int current) {
    return (current - orig).abs() % (repetition) == 0;
  }
  RepetitionType getRepetitionType() {
    return repetitionType;
  }
  bool isSameDay(RepeatableDate o) {
    if (!isSameRepetitionType(o)) throw ArgumentError("not of same repetition type");
    return year == o.year && month == o.month && day == o.day;
  }

  bool isInitialOnOrBefore(DateTime o) {
    return o.year > year || (o.year == year && o.month > month) || (o.year == year && o.month == month && o.day >= day);
  }
  bool isOnThisDay(DateTime o) {
    if(isWeekly()) return toDateTime().weekday == o.weekday;
    return (isMonthly() || isDaily() || (isYearly()? isInThisRepetition(year, o.year) : year == o.year)) && (isDaily() || (isMonthly()? isInThisRepetition(month, o.month) : month == o.month)) && (isDaily()? isInThisRepetition(day, o.day) : day == o.day);
  }
  bool isAfterThisDay(DateTime d) {
    if(isRepeating()) throw ArgumentError("after cannot be checked when repeating, always before AND after");
    return year != d.year? year > d.year : month != d.month? month > d.month : day > d.day;
  }
  bool isBeforeThisDay(DateTime o) {
    return !isOnThisDay(o) && !isAfterThisDay(o);
  }


  bool isAfterWithinRepetition(RepeatableDate o) {
    return !isSameDay(o) && !isBeforeWithinRepetition(o);
  }
  bool isBeforeWithinRepetition(RepeatableDate o) {
    if (!isSameRepetitionType(o)) throw ArgumentError("not of same repetition type");
    if(isDaily()) return false;
    return (
        (!isRepeating() && year != o.year?year < o.year:month!=o.month?month<o.month:day<o.day) ||
            (isYearly() && month!=o.month?month<o.month:day<o.day) ||
            (isMonthly() && day < o.day) ||
            (isWeekly() && toDateTime().weekday < o.toDateTime().weekday)
    );
  }

  bool isRepeating() => repetitionType != RepetitionType.none;
  bool isYearly() => repetitionType == RepetitionType.yearly;
  bool isMonthly() => repetitionType == RepetitionType.monthly;
  bool isWeekly() => repetitionType == RepetitionType.weekly;
  bool isDaily() => repetitionType == RepetitionType.daily;

  Duration difference(RepeatableDate o) {
    if (!isSameRepetitionType(o)) throw ArgumentError("not of same repetition type");

    if (!isRepeating()) return toDateTime().difference(o.toDateTime());
    if (isMonthly()) return Duration(days: day - o.day);
    if (isWeekly()) return Duration(days: toDateTime().weekday - o.toDateTime().weekday);
    if (isYearly()) return toDateTime().difference(o.toDateTime());
    return Duration.zero;
  }


  DateTime? lastOccurrenceBefore(DateTime reference, [Time? time]) {
    var raw = toDateTime().copyWith(hour: time?.hour, minute: time?.minute, second: time?.second);
    if(raw.isBefore(reference)) return raw;

    if(isYearly()) {
      var ret = raw.copyWith(year: reference.year, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isBefore(reference)) return ret;
      return raw.copyWith(year: ret.year - 1);
    }
    if(isMonthly()) {
      var ret = raw.copyWith(year: reference.year, month: reference.month, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isBefore(reference)) return ret;
      return raw.copyWith(year: reference.month == 1 ? reference.year - 1 : reference.year, month: reference.month == 1 ? 12 : reference.month - 1);
    }
    if(isWeekly()) {
      var weekday = raw.weekday;
      var ret = reference.copyWith(hour: time?.hour, minute: time?.minute, second: time?.second, millisecond: 0, microsecond: 0);
      if(ret.isBefore(reference)) return ret;
      return reference.subtract(Duration(days: weekday < reference.weekday ? reference.weekday - weekday : (reference.weekday - weekday) + 7));
    }
    if(isDaily()) {
      var ret = raw.copyWith(year: reference.year, month: reference.month, day: reference.day, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isBefore(reference)) return ret;
      return ret.subtract(const Duration(days: 1));
    }
    return null;
  }
  DateTime? nextOccurrenceAfter(DateTime reference, [Time? time]) {
    var raw = toDateTime().copyWith(hour: time?.hour, minute: time?.minute, second: time?.second);
    if(raw.isAfter(reference)) return raw;

    if(isYearly()) {
      var ret = raw.copyWith(year: reference.year, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isAfter(reference)) return ret;
      return raw.copyWith(year: ret.year + 1);
    }
    if(isMonthly()) {
      var ret = raw.copyWith(year: reference.year, month: reference.month, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isAfter(reference)) return ret;
      return raw.copyWith(year: ret.month == 12 ? ret.year + 1 : ret.year, month: ret.month == 12 ? 1 : ret.month + 1);
    }
    if(isWeekly()) {
      var weekday = raw.weekday;
      var ret = reference.copyWith(hour: time?.hour, minute: time?.minute, second: time?.second, millisecond: 0, microsecond: 0);
      if(ret.isAfter(reference)) return ret;
      return reference.add(Duration(days: weekday > reference.weekday ? reference.weekday - weekday : 7 - (reference.weekday - weekday) ));
    }
    if(isDaily()) {
      var ret = raw.copyWith(year: reference.year, month: reference.month, day: reference.day, hour: time?.hour, minute: time?.minute, second: time?.second);
      if(ret.isAfter(reference)) return ret;
      return ret.add(const Duration(days: 1));
    }
    return null;
  }

  DateTime toDateTime() {
    return DateTime(year, month, day);
  }

  static from(DateTime dt, {RepetitionType repetitionType = RepetitionType.none, int repetition = 1}) => RepeatableDate(dt.year, dt.month, dt.day, repetitionType: repetitionType, repetition: repetition);
}

bool includesThisDay(RepeatableDate rStart, RepeatableDate rEnd, int dYear, int dMonth, int dDay, int dWeekday) {
  if(!rStart.isSameRepetitionType(rEnd)) throw ArgumentError("must be of same repetition type");
  
  if(!rStart.isRepeating()) {
    if(rStart.isAfterWithinRepetition(rEnd)) throw ArgumentError("start must not be after end");
    return (rStart.year != dYear? dYear > rStart.year : rStart.month != dMonth? dMonth > rStart.month : dDay >= rStart.day) &&
           (rEnd.year != dYear? dYear < rEnd.year : rEnd.month != dMonth? dMonth < rEnd.month : dDay <= rEnd.day);
  }
  if(rStart.isDaily()) return true;
  if(rStart.isWeekly()) {
    var rSWeekday = rStart.toDateTime().weekday;
    var rEWeekday = rEnd.toDateTime().weekday;
    if(rSWeekday > rEWeekday) {
      return dWeekday >= rSWeekday || dWeekday <= rEWeekday;
    }
    return dWeekday >= rSWeekday && dWeekday <= rEWeekday;
  }
  if(rStart.isMonthly()) {
    if(rStart.day > rEnd.day) {
      return (rStart.isInThisRepetition(rStart.month, dMonth) && dDay >= rStart.day) ||
          (rEnd.isInThisRepetition(rEnd.month, dMonth)     && dDay <= rEnd.day);
    } else {
      return (rStart.isInThisRepetition(rStart.month, dMonth) && dDay >= rStart.day) &&
             (rEnd.isInThisRepetition(rEnd.month, dMonth)     && dDay <= rEnd.day);
    }
  }
  if(rStart.isYearly()) {
    if(rStart.month != rEnd.month? rStart.month > rEnd.month : rStart.day > rEnd.day) {
      return (rStart.isInThisRepetition(rStart.year, dYear) && rStart.month != dMonth? dMonth > rStart.month : dDay >= rStart.day) ||
          (rEnd.isInThisRepetition(rEnd.year, dYear) && rEnd.month != dMonth? dMonth < rEnd.month : dDay <= rEnd.day);
    } else {
      return (rStart.isInThisRepetition(rStart.year, dYear) && rStart.month != dMonth? dMonth > rStart.month : dDay >= rStart.day) &&
             (rEnd.isInThisRepetition(rEnd.year, dYear) && rEnd.month != dMonth? dMonth < rEnd.month : dDay <= rEnd.day);
    }
  }
  return false;
}

bool between(int v, int rS, int rE) {
  return v >= rS && v <= rE;
}

// bool _beforeY(RepeatableDate d1, DateTime d2) {
//   return d1.year != d2.year? d1.year < d2.year : d1.month != d2.month? d1.month < d2.month : d1.day < d2.day;
// }
// bool _afterM(RepeatableDate d1, DateTime d2) {
//   return d1.month != d2.month? d1.month < d2.month : d1.day < d2.day;
// }
// bool _afterD(RepeatableDate d1, DateTime d2) {
//   return d1.day < d2.day;
// }

bool invertIf(bool i, bool v) => i? !v:v;