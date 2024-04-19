import 'dart:io';

import 'package:deadlines/notifications/alarm_external_wrapper/model.dart';
import 'package:synchronized/synchronized.dart';

import 'model.dart';
import 'package:sqflite/sqflite.dart' as sql;

/// The deadlines storage interface, an abstract representation which can be both a cache or the database itself
abstract class DeadlinesStorage {
  ///no requirement to have id != null, will be calculated and set accordingly
  Future<Deadline> add(Deadline d);
  ///Deadline with id of dNew will be replaced with contents of dNew
  Future<void> update(Deadline dOld, Deadline dNew);
  ///Deadline with id will be removed
  Future<void> remove(Deadline d);
}

/// A cache allowing quick in-memory access to database functionality
/// Subclasses must allow the mutation functionality of the parent class, but can implement their own queryable lists
/// must be thread-safe, for which the l lock must be used
mixin Cache implements DeadlinesStorage {
  Lock l = Lock();
  /// invalidates the cache and cleans up the underlying data structures
  /// query functionality must work as before, but must access the underlying database again
  Future<void> invalidate();
}


/// Actual deadlines and occurrence-removals queried from and written to memory
final class DeadlinesDatabase implements DeadlinesStorage {
  final Future<sql.Database> _db = _initDB();

  static Future<sql.Database> _initDB() async {
    String path;
    if(Platform.isAndroid) {
      //Only for private use (with MANAGE_EXTERNAL_STORAGE permission)
      //required Permission.manageExternalStorage.request() in main
      path = "/storage/emulated/0/Deadlines/deadlines.db";
    } else {
      path = "deadlines.db"; //for public use (WITHOUT MANAGE_EXTERNAL_STORAGE permission)
    }

    // sql.deleteDatabase("deadlines.db");
    return sql.openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(sql.Database db) async {
    await db.execute(
      """CREATE TABLE deadlines(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,

        title TEXT NOT NULL,
        description TEXT NOT NULL,
        color int NOT NULL,
        active int NOT NULL,
        importance int NOT NULL,
        
        startsAt_year int NOT NULL,
        startsAt_month int NOT NULL,
        startsAt_day int NOT NULL,
        startsAt_repetition int NOT NULL,
        startsAt_repetitionType int NOT NULL,
        startsAt_hour int NOT NULL,
        startsAt_minute int NOT NULL,
        startsAt_notificationType int NOT NULL,
        
        deadlineAt_year int NOT NULL,
        deadlineAt_month int NOT NULL,
        deadlineAt_day int NOT NULL,
        deadlineAt_repetition int NOT NULL,
        deadlineAt_repetitionType int NOT NULL,
        deadlineAt_hour int NOT NULL,
        deadlineAt_minute int NOT NULL,
        deadlineAt_notificationType int NOT NULL
      );"""
    );

    await db.execute(
      """CREATE TABLE removals(
        rm_id int NOT NULL,
        all_future int NOT NULL,
        rm_dlAt_year int NOT NULL,
        rm_dlAt_month int NOT NULL,
        rm_dlAt_day int NOT NULL,
        rm_dlAt_repetition int NOT NULL,
        rm_dlAt_repetitionType int NOT NULL,
        UNIQUE (rm_id, all_future, rm_dlAt_year, rm_dlAt_month, rm_dlAt_day)
      );"""
    );
  }

  static int _parseInt(Object? o) {
    return int.parse(o.toString());
  }

  static Deadline _fromSQLMap(Map<String, Object?> m, Iterable<Removal> removals) {
    return Deadline(
      _parseInt(m["id"]), m["title"].toString(), m["description"].toString(),
      _parseInt(m["color"]), _parseInt(m["active"]) == 0? null : DateTime.fromMillisecondsSinceEpoch(_parseInt(m["active"])),
      _parseInt(m["startsAt_year"]) == 0? null:NotifyableRepeatableDateTime(
        RepeatableDate(
          _parseInt(m["startsAt_year"]), _parseInt(m["startsAt_month"]), _parseInt(m["startsAt_day"]),
          repetition: _parseInt(m["startsAt_repetition"]), repetitionType: RepetitionType.values[_parseInt(m["startsAt_repetitionType"])]
        ),
        Time(_parseInt(m["startsAt_hour"]), _parseInt(m["startsAt_minute"]),),
        NotificationType.values[_parseInt(m["startsAt_notificationType"])]
      ),
      _parseInt(m["deadlineAt_year"]) == 0? null:NotifyableRepeatableDateTime(
        RepeatableDate(
          _parseInt(m["deadlineAt_year"]), _parseInt(m["deadlineAt_month"]), _parseInt(m["deadlineAt_day"]),
          repetition: _parseInt(m["deadlineAt_repetition"]), repetitionType: RepetitionType.values[_parseInt(m["deadlineAt_repetitionType"])]
        ),
        Time(_parseInt(m["deadlineAt_hour"]), _parseInt(m["deadlineAt_minute"]),),
        NotificationType.values[_parseInt(m["deadlineAt_notificationType"])]
      ),
      Importance.values[_parseInt(m["importance"])],
      removals
    );
  }

  Map<String, Object?> _toSQLMapWithoutId(Deadline d) {
    return {
      "title": d.title, "description": d.description, "color": d.color, "active": d.activeAfter?.millisecondsSinceEpoch ?? 0, "importance": d.importance.index,
      "startsAt_year": d.startsAt==null?0:d.startsAt!.date.year, "startsAt_month": d.startsAt==null?0:d.startsAt!.date.month, "startsAt_day": d.startsAt==null?0:d.startsAt!.date.day,
      "startsAt_repetition": d.startsAt==null?0:d.startsAt!.date.repetition, "startsAt_repetitionType": d.startsAt==null?0:d.startsAt!.date.repetitionType.index,
      "startsAt_hour": d.startsAt==null?0:d.startsAt!.time.hour, "startsAt_minute": d.startsAt==null?0:d.startsAt!.time.minute,
      "startsAt_notificationType": d.startsAt==null?0:d.startsAt!.notifyType.index,
      "deadlineAt_year": d.deadlineAt==null?0:d.deadlineAt!.date.year, "deadlineAt_month": d.deadlineAt==null?0:d.deadlineAt!.date.month, "deadlineAt_day": d.deadlineAt==null?0:d.deadlineAt!.date.day,
      "deadlineAt_repetition": d.deadlineAt==null?0:d.deadlineAt!.date.repetition, "deadlineAt_repetitionType": d.deadlineAt==null?0:d.deadlineAt!.date.repetitionType.index,
      "deadlineAt_hour": d.deadlineAt==null?0:d.deadlineAt!.time.hour, "deadlineAt_minute": d.deadlineAt==null?0:d.deadlineAt!.time.minute,
      "deadlineAt_notificationType": d.deadlineAt==null?0:d.deadlineAt!.notifyType.index,
    };
  }

  Removal _rFromSQLMap(Map<String, Object?> m) {
    return Removal(
      RepeatableDate(_parseInt(
        m["rm_dlAt_year"]), _parseInt(m["rm_dlAt_month"]), _parseInt(m["rm_dlAt_day"]),
        repetition: _parseInt(m["rm_dlAt_repetition"]), repetitionType: RepetitionType.values[_parseInt(m["rm_dlAt_repetitionType"])],
      ),
      _parseInt(m["all_future"]) == 1
    );
  }
  Map<String, Object?> _toSQLMap(int id, Removal r) {
    return {
      "rm_id": id,
      "all_future": r.allFuture?1:0,
      "rm_dlAt_year": r.day.year,
      "rm_dlAt_month": r.day.month,
      "rm_dlAt_day": r.day.day,
      "rm_dlAt_repetition": r.day.repetition,
      "rm_dlAt_repetitionType": r.day.repetitionType.index,
    };
  }

  Future<List<Deadline>> _withRemovals(List<Map<String, Object?>> rawResults) {
    return Future.wait(rawResults.map((e) async => _fromSQLMap(e, (await (await _db).rawQuery(
        """SELECT *
        FROM removals
        WHERE
        (
          rm_id == ${e["id"]}
        )
      ;"""
    )).map(_rFromSQLMap).toList(growable: false))).toList());
  }


  /// load deadline with specified id fully from disk (with removals)
  /// will return null if no deadline with the specified id is available
  Future<Deadline?> loadById(int id) async {
    var rawResults = await (await _db).query("deadlines", where: "id = ?", whereArgs: [id]);
    if(rawResults.isEmpty) return null;
    return (await _withRemovals([rawResults.first])).first;
  }

  @override Future<Deadline> add(Deadline d) async {
    final id = await (await _db).insert("deadlines", _toSQLMapWithoutId(d));
    d = d.copyWithId(id);
    for (var r in d.removals) {
      await (await _db).insert("removals", _toSQLMap(d.id!, r), conflictAlgorithm: sql.ConflictAlgorithm.replace);
    }
    return d;
  }

  @override Future<void> remove(Deadline d) async {
    await (await _db).delete("deadlines", where: "id = ?", whereArgs: [d.id]);
    await (await _db).delete("removals", where: "rm_id = ?", whereArgs: [d.id]);
  }

  @override Future<void> update(Deadline _, Deadline dNew) async {
    await (await _db).update("deadlines", _toSQLMapWithoutId(dNew), where: "id = ?", whereArgs: [dNew.id]);

    await (await _db).delete("removals", where: "rm_id = ?", whereArgs: [dNew.id]);
    for (var r in dNew.removals) {
      await (await _db).insert("removals", _toSQLMap(dNew.id!, r), conflictAlgorithm: sql.ConflictAlgorithm.replace);
    }
  }

  /// Return all stored deadlines
  Future<List<Deadline>> selectAll() async {
    var rawResults = await (await _db).rawQuery("SELECT * FROM deadlines d;", []);

    return _withRemovals(rawResults);
  }

  /// Return all deadlines in month and whether they must be active
  Future<List<Deadline>> queryDeadlinesInMonth(int year, int month, {required bool requireActive}) async {
    var rawResults = await (await _db).rawQuery(
      """SELECT *
        FROM deadlines d
        WHERE
        ${requireActive?"d.active != 0 AND d.active < ${DateTime(year, month+1).millisecondsSinceEpoch} AND":""} (
          (d.startsAt_year   < $year OR (d.startsAt_year   == $year AND d.startsAt_month <= $month))
          AND
          (
               ((d.startsAt_year   == $year OR d.startsAt_repetitionType   != ${RepetitionType.none.index}) AND (d.startsAt_month   == $month OR (d.startsAt_repetitionType   != ${RepetitionType.none.index} AND d.startsAt_repetitionType   != ${RepetitionType.yearly.index})))
            OR ((d.deadlineAt_year == $year OR d.deadlineAt_repetitionType != ${RepetitionType.none.index}) AND (d.deadlineAt_month == $month OR (d.deadlineAt_repetitionType != ${RepetitionType.none.index} AND d.deadlineAt_repetitionType != ${RepetitionType.yearly.index})))
          )
          AND
          (
            d.id NOT IN (SELECT rm_id FROM removals WHERE all_future)
            OR
            d.id IN (
              SELECT rm_id FROM removals r WHERE 
              d.id == r.rm_id
              AND
              r.all_future
              AND
              (r.rm_dlAt_year > $year OR (r.rm_dlAt_year == $year AND r.rm_dlAt_month >= $month))
            )
          )
        )
      ;"""
    );

    return _withRemovals(rawResults);
  }

  /// Return all deadlines deadlines that are active, timeless or after the given minute
  /// for the non-active deadlines it can be further specified whether they must be active
  Future<List<Deadline>> queryDeadlinesActiveAtAllOrTimelessOrAfter(DateTime minute, {required bool requireActive}) async {
    var rawResults = await (await _db).rawQuery(
        """SELECT *
          FROM deadlines d
          WHERE
          ${requireActive? "d.active != 0 AND":""} (
            d.active
            OR
            (d.startsAt_year == 0 AND d.deadlineAt_year == 0)
            OR
            d.startsAt_repetitionType != ${RepetitionType.none.index}
            OR
            d.deadlineAt_repetitionType != ${RepetitionType.none.index}
            OR
            (
              (d.startsAt_year    > ${minute.year}) OR
              (d.startsAt_year   == ${minute.year} AND d.startsAt_month  > ${minute.month}) OR
              (d.startsAt_year   == ${minute.year} AND d.startsAt_month == ${minute.month} AND d.startsAt_day  > ${minute.day}) OR
              (d.startsAt_year   == ${minute.year} AND d.startsAt_month == ${minute.month} AND d.startsAt_day == ${minute.day} AND d.startsAt_hour  > ${minute.hour}) OR
              (d.startsAt_year   == ${minute.year} AND d.startsAt_month == ${minute.month} AND d.startsAt_day == ${minute.day} AND d.startsAt_hour == ${minute.hour} AND d.startsAt_minute >= ${minute.minute})
            )
            OR
            (
              (d.startsAt_year == 0)
              AND
              (
                (d.deadlineAt_year    > ${minute.year}) OR
                (d.deadlineAt_year   == ${minute.year} AND d.deadlineAt_month  > ${minute.month}) OR
                (d.deadlineAt_year   == ${minute.year} AND d.deadlineAt_month == ${minute.month} AND d.deadlineAt_day  > ${minute.day}) OR
                (d.deadlineAt_year   == ${minute.year} AND d.deadlineAt_month == ${minute.month} AND d.deadlineAt_day == ${minute.day} AND d.deadlineAt_hour  > ${minute.hour}) OR
                (d.deadlineAt_year   == ${minute.year} AND d.deadlineAt_month == ${minute.month} AND d.deadlineAt_day == ${minute.day} AND d.deadlineAt_hour == ${minute.hour} AND d.deadlineAt_minute >= ${minute.minute})
              )
            )
          )
          AND
          (
            d.id NOT IN (SELECT rm_id FROM removals WHERE all_future)
            OR
            d.id IN (
              SELECT rm_id FROM removals r WHERE 
              d.id == r.rm_id
              AND
              r.all_future
              AND
              (r.rm_dlAt_year > ${minute.year} OR (r.rm_dlAt_year == ${minute.year} AND r.rm_dlAt_month > ${minute.month}) OR (r.rm_dlAt_year == ${minute.year} AND r.rm_dlAt_month == ${minute.month} AND r.rm_dlAt_day >= ${minute.day}))
            )
          )
      ;"""
    );

    return _withRemovals(rawResults);
  }

  /// Return all critical deadlines after the given minute or timeless deadlines and whether they must be active
  Future<List<Deadline>> queryCriticalDeadlinesInYear(int year, {required bool requireActive}) async {
    var rawResults = await (await _db).rawQuery(
        """SELECT *
        FROM deadlines d
        WHERE
        ${requireActive? "d.active != 0 AND d.active < ${DateTime(year+1).millisecondsSinceEpoch} AND":""} (
          (d.importance = ${Importance.critical.index})
          AND
          (
               (d.startsAt_year   == $year OR d.startsAt_repetitionType   != ${RepetitionType.none.index})
            OR (d.deadlineAt_year == $year OR d.deadlineAt_repetitionType != ${RepetitionType.none.index})
          )
          AND
          (
            d.id NOT IN (SELECT rm_id FROM removals WHERE all_future)
            OR
            d.id IN (
              SELECT rm_id FROM removals r WHERE 
              d.id == r.rm_id
              AND
              r.all_future
              AND
              (r.rm_dlAt_year >= $year)
            )
          )
        )
      ;"""
    );

    return _withRemovals(rawResults);
  }
}