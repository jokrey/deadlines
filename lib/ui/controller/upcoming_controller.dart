import 'dart:async';

import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import '../controller/parent_controller.dart';


class UpcomingController extends ChildController with Cache {
  UpcomingController(super.parent);

  //ui choices to be restored
  double scrollOffset = -1;

  bool _cacheValid = false;
  final Map<int, Deadline> _cache = {};
  @override invalidate() => l.synchronized(() {
    _cacheValid = false;
    _cache.clear();
  });
  @override Future<Deadline> add(Deadline d) => l.synchronized(() {
    if(_cacheValid) _cache[d.id!] = d;
    notifyContentsChanged();
    return d;
  });
  @override Future<void> remove(Deadline d) => l.synchronized(() {
    if(_cacheValid) _cache.remove(d.id);
    notifyContentsChanged();
  });
  @override Future<void> update(Deadline dOld, Deadline dNew) => l.synchronized(() {
    if(_cacheValid) {
      if(_cache.remove(dOld.id) != null) {
        _cache[dNew.id!] = dNew;
      }
    }
    notifyContentsChanged();
  });

  Future<Iterable<Deadline>> queryRelevantDeadlines() => l.synchronized(() async {
    if(!_cacheValid) {
      _cache.clear();
      for(var d in await parent.db.queryDeadlinesActiveOrTimelessOrAfter(DateTime.now(), requireActive: parent.showWhat == ShownType.showActive)) {
        _cache[d.id!] = d;
      }
      _cacheValid = true;
    }
    return _cache.values;
  });
}