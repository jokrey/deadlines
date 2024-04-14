import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import '../controller/parent_controller.dart';


class YearsController extends ChildController with Cache {
  YearsController(super.parent);

  int _cachedYear = -1;
  final Map<int, Deadline> _cache = {};
  @override invalidate() => l.synchronized(() {
    _cachedYear = -1;
    _cache.clear();
  });
  @override Future<Deadline> add(Deadline d) => l.synchronized(() {
    if((d.startsAt?.date.isInThisYear(_cachedYear) ?? false) || (d.deadlineAt?.date.isInThisYear(_cachedYear) ?? false)) {
      _cache[d.id!] = d;
    }
    notifyContentsChanged();
    return d;
  });
  @override Future<void> remove(Deadline d) => l.synchronized(() {
    if((d.startsAt?.date.isInThisYear(_cachedYear) ?? false) || (d.deadlineAt?.date.isInThisYear(_cachedYear) ?? false)) {
      _cache.remove(d.id);
    }
    notifyContentsChanged();
  });
  @override Future<void> update(Deadline dOld, Deadline dNew) => l.synchronized(() {
    bool wasRemoved;
    if((dOld.startsAt?.date.isInThisYear(_cachedYear) ?? false) || (dOld.deadlineAt?.date.isInThisYear(_cachedYear) ?? false)) {
      wasRemoved = _cache.remove(dOld.id) != null;
    } else {
      wasRemoved = true;
    }
    if((dNew.startsAt?.date.isInThisYear(_cachedYear) ?? false) || (dNew.deadlineAt?.date.isInThisYear(_cachedYear) ?? false)) {
      if(wasRemoved) _cache[dNew.id!] = dNew;
    }
    notifyContentsChanged();
  });

  Future<Iterable<Deadline>> queryRelevantDeadlinesInYear(int year) => l.synchronized(() async {
    if(_cachedYear != year) {
      _cache.clear();
      for(var d in await parent.db.queryCriticalDeadlinesInYear(year, requireActive: parent.showWhat == ShownType.showActive)) {
        _cache[d.id!] = d;
      }
      _cachedYear = year;
    }
    return _cache.values;
  });
}