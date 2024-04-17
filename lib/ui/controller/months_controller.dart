import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controller/parent_controller.dart';


class MonthsController extends ChildController with Cache {
  MonthsController(super.parent);

  //ui choices to be restored
  var ratio = 0.6;
  double scrollOffset = 0;
  bool showDaily = false;

  @override Future<void> init() async {
    ratio = (await SharedPreferences.getInstance()).getDouble("ratio") ?? 0.6;
  }
  Future<void> safeRatio() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setDouble("ratio", ratio);
  }


  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDay;

  DateTime getSelectedMonth() => _selectedMonth;
  DateTime getFirstDayInSelectedMonth() => DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  DateTime? getSelectedDay() => _selectedDay;

  void setSelection(DateTime month, DateTime? day) {
    if(_selectedMonth != month || _selectedDay != day) {
      if(_selectedMonth != month) scrollOffset = 0;
      _selectedMonth = month;
      _selectedDay = day;
      notifyContentsChanged();
    }
  }
  void setSelectedMonth(DateTime month) {
    if(_selectedMonth != month) {
      scrollOffset = 0;
      _selectedMonth = month;
      notifyContentsChanged();
    }
  }
  void setSelectedDay(DateTime day) {
    if(_selectedDay != day) {
      _selectedDay = day;
      notifyContentsChanged();
    }
  }
  void setDayUnselected() {
    if(_selectedDay != null) {
      _selectedDay = null;
      notifyContentsChanged();
    }
  }


  final Map<(int, int), Map<int, Deadline>> _cache = {};
  @override invalidate() => l.synchronized(() => _cache.clear());
  @override Future<Deadline> add(Deadline d) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      if ((d.startsAt?.date.isInThisMonth(year, month) ?? false) || (d.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map[d.id!] = d;
      }
    });
    notifyContentsChanged();
    return d;
  });
  @override Future<void> remove(Deadline d) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      if ((d.startsAt?.date.isInThisMonth(year, month) ?? false) || (d.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map.remove(d.id!);
      }
    });
    notifyContentsChanged();
  });
  @override Future<void> update(Deadline dOld, Deadline dNew) => l.synchronized(() {
    _cache.forEach((key, map) {
      var (year, month) = key;
      if ((dOld.startsAt?.date.isInThisMonth(year, month) ?? false) || (dOld.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map.remove(dOld.id!) != null;
      }
      if((dNew.startsAt?.date.isInThisMonth(year, month) ?? false) || (dNew.deadlineAt?.date.isInThisMonth(year, month) ?? false)) {
        map[dNew.id!] = dNew;
      }
    });
    notifyContentsChanged();
  });


  Future<Iterable<Deadline>> queryOrRetrieve(int year, int month) => l.synchronized(() async {
    Map<int, Deadline>? res = _cache[(year, month)];
    if(res == null) {
      res = {};
      for(var d in await parent.db.queryDeadlinesInMonth(year, month, requireActive: parent.showWhat == ShownType.showActive)) {
        res[d.id!] = d;
      }
      _cache[(year, month)] = res;
    }
    return res.values;
  });
  Future<void> cleanCache() => l.synchronized(() {
    int year = getSelectedMonth().year;
    int month = getSelectedMonth().month;
    _cache.removeWhere((k, v) {
      var ky = k.$1;
      var km = k.$2;
      return (year == ky && (month - km).abs() > 1) ||
          (ky < year && month != 1) ||
          (ky > year && month != 12);
    });
  });
  Future<Iterable<Deadline>> getFlatCache() => l.synchronized(() {
    Set<Deadline> l = {};
    for(var v in _cache.values) {
      l.addAll(v.values);
    }
    return l;
  });
  Future<Iterable<Deadline>> queryOrRetrieveCurrentMonth() {
    return queryOrRetrieve(getSelectedMonth().year, getSelectedMonth().month);
  }
  Future<void> ensureAllRelevantDeadlinesInCache() async {
    int year = getSelectedMonth().year;
    int month = getSelectedMonth().month;
    await queryOrRetrieve(month==1?year-1:year, month==1?12:month-1);
    await queryOrRetrieve(year, month);
    await queryOrRetrieve(month==12?year+1:year, month==12?1:month+1);
    await cleanCache();
  }

  List<Deadline> getDeadlinesOnDay(DateTime day, {required Iterable<Deadline> candidates, bool? showDaily}) {
    showDaily ??= this.showDaily;
    var l = candidates.where((d) =>
      !d.isTimeless() && d.isOnThisDay(day) &&
      (parent.showWhat == ShownType.showAll || d.isActiveOn(day)) &&
      (showDaily! || !d.deadlineAt!.date.isDaily() || d.isOverdue(day))
    ).toList();
    l.sort((a, b) {
      return nullableCompare(a.startsAt?.time ?? a.deadlineAt?.time, b.startsAt?.time ?? b.deadlineAt?.time);
    });
    return l;
  }
}