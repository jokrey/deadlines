import 'package:flutter/material.dart';


int nullableCompare(Comparable? o1, Comparable? o2) {
  if(o1 != null && o2 != null) return o1.compareTo(o2);
  if(o1 == null && o2 == null) return 0;
  if(o1 != null) return 1;
  return -1;
}

List<T> sort<T>(List<T> list, [int Function(T, T)? compare]) {
  list.sort(compare);
  return list;
}
List<T> sorted<T>(Iterable<T> iterable, [int Function(T, T)? compare]) {
  var list = iterable.toList(growable: false);
  list.sort(compare);
  return list;
}

T minCmp<T extends Comparable<T>>(T a, T b) {
  return a.compareTo(b) <= 0? a : b;
}
T maxCmp<T extends Comparable<T>>(T a, T b) {
  return a.compareTo(b) >= 0? a : b;
}

class NotDumbIterator<T> {
  late Iterator<T> _iterator;
  late T _current;
  bool hasNext = false;
  NotDumbIterator(Iterable<T> iterable) {
    this._iterator = iterable.iterator;
    hasNext = _iterator.moveNext();
    if(hasNext) _current = _iterator.current;
  }

  T next() {
    T r = _current;
    hasNext = _iterator.moveNext();
    if(hasNext) _current = _iterator.current;
    return r;
  }
}

class ListIterator<T> {
  final List list;
  int _currentIndex = 0;
  ListIterator(this.list);

  int numLeft() => list.length - _currentIndex;
  bool hasNext() {
    return _currentIndex < list.length;
  }
  T next() => list[_currentIndex++];
}

bool iterEquals(Iterable elements1, Iterable elements2) {
  if (elements1 == elements2) return true;
  var iter1 = elements1.iterator;
  var iter2 = elements2.iterator;
  while (true) {
    var hasNext = iter1.moveNext();
    if (hasNext != iter2.moveNext()) return false;
    if (!hasNext) return true;
    if (iter1.current != iter2.current) return false;
  }
}

DateTime stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
DateTime withTime(DateTime dt, [int hour = 0, int minute = 0, int second = 0]) => DateTime(dt.year, dt.month, dt.day, hour, minute, second);
bool isSameMonth(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month;

///https://stackoverflow.com/a/60191441
Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.fromARGB(
      c.alpha,
      (c.red * f).round(),
      (c.green  * f).round(),
      (c.blue * f).round()
  );
}

///https://stackoverflow.com/a/60191441
Color lighten(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var p = percent / 100;
  return Color.fromARGB(
      c.alpha,
      c.red + ((255 - c.red) * p).round(),
      c.green + ((255 - c.green) * p).round(),
      c.blue + ((255 - c.blue) * p).round()
  );
}


String? convert0To99ToText(int i) {
  if(i < 20) {
    switch (i) {
      case 0:return "zero";
      case 1:return "one";
      case 2:return "two";
      case 3:return "three";
      case 4:return "four";
      case 5:return "five";
      case 6:return "six";
      case 7:return "seven";
      case 8:return "eight";
      case 9:return "nine";
      case 10:return "ten";
      case 11:return "eleven";
      case 12:return "twelve";
      case 13:return "thirteen";
      case 14:return "fourteen";
      case 15:return "fifteen";
      case 16:return "sixteen";
      case 17:return "seventeen";
      case 18:return "eighteen";
      case 19:return "nineteen";
      default:return null;
    }
  } else {
    var tenner = i - i%10;
    String tt;
    switch (tenner) {
      case 20:tt="twenty";
      case 30:tt="thirty";
      case 40:tt="forty";
      case 50:tt="fifty";
      case 60:tt="sixty";
      case 70:tt="seventy";
      case 80:tt="eighty";
      case 90:tt="ninety";
      default:return null;
    }
    return "$tt ${i % 10 == 0?"":convert0To99ToText(i % 10)}";
  }
}