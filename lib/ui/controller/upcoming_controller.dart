import 'dart:async';

import 'package:deadlines/persistence/database.dart';
import 'package:deadlines/persistence/model.dart';
import '../controller/parent_controller.dart';

/// The Controller for the list of upcoming deadlines display with included cache functionality
/// Allows simple, efficient and synchronized access for the ui to storage functionality
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
      _cache.remove(dOld.id); //possible that nothing removed if would be newly in cache
      _cache[dNew.id!] = dNew;
    }
    notifyContentsChanged();
  });

  /// Returns a list of relevant deadlines to the list of upcoming deadlines widget
  /// Transparently either loaded from database or from cache
  Future<Iterable<Deadline>> queryRelevantDeadlines() => l.synchronized(() async {
    if(!_cacheValid) {
      _cache.clear();
      for(var d in await parent.db.queryDeadlinesActiveAtAllOrTimelessOrAfter(DateTime.now(), requireActive: parent.showWhat == ShownType.showActive)) {
        _cache[d.id!] = d;
      }
      _cacheValid = true;
    }
    return _cache.values;
  });
}