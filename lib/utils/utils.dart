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

DateTime stripTime(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day);
}

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