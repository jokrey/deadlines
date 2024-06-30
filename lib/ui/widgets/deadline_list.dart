import 'package:deadlines/persistence/model.dart';
import 'package:deadlines/ui/controller/parent_controller.dart';
import 'package:deadlines/ui/widgets/card_in_list.dart';
import 'package:deadlines/utils/utils.dart';
import 'package:flutter/cupertino.dart';

/// group of deadlines
class Group {
  /// Label of group, displayed above
  final String label;
  /// First day of deadline group
  final DateTime? startDay;
  /// Last day of deadline group
  final DateTime? endDay;
  /// Deadlines in group, nulls will be treated as a space
  final List<Deadline?> content;
  Group(this.label, this.startDay, this.endDay, this.content) {
    content.sort((a, b) {
      if(a == null || b == null) return nullableCompare(a, b);
      if(a.startsAt != null && a.startsAt!.isOverdue(DateTime.now())) {
        int cmp = a.deadlineAt!.time.compareTo(b.deadlineAt!.time);
        if(cmp == 0) return a.title.compareTo(b.title);
        return cmp;
      }
      int cmp = nullableCompare(a.startsAt?.time ?? a.deadlineAt?.time, b.startsAt?.time ?? b.deadlineAt?.time);
      if(cmp == 0) return a.title.compareTo(b.title);
      return cmp;
    });
  }

  /// Create a new group with equal contents to this, except for the list
  Group copyWithList(List<Deadline?> newList) => Group(label, startDay, endDay, newList);

  static String _dayString(DateTime day) => "${pad0(day.day)}.${pad0(day.month)}.${day.year} (${shortWeekdayString(day)})";
  /// Create Group from a single day
  static Group fromDay(DateTime day, Iterable<Deadline> deadlines) => Group(
    _dayString(day), day, day, deadlines.toList(growable: false)
  );
  /// Create Group from a range of days
  static Group fromRange(DateTime dtr1, DateTime dtr2, Iterable<Deadline> deadlines) => Group(
    isSameDay(dtr1, dtr2) ? _dayString(dtr1) : "${_dayString(dtr1)} - ${_dayString(dtr2)}",
    dtr1, dtr2, deadlines.toList(growable: false)
  );
  /// Create Group from a range of days
  static Group fromTimeless(Importance i, Iterable<Deadline> deadlines) => Group(
    "ToDo (${camel(i.name)})", null, null, deadlines.toList(growable: false)
  );
  /// Create a Group which will be interpreted as an empty space in the list ui
  static Group emptySpace() => Group("", null, null, []);
}

/// Sort the given groups by an appropriate, especially ranges aware algorithm
List<Group> sortedGroupList(Iterable<Group> groups) {
  var list = groups.toList(growable: false);
  list.sort((a, b) {
    if(a.startDay!.isAfter(DateTime.now())) {
      var diffA = a.startDay!.difference(a.endDay!).inDays;
      var diffB = b.startDay!.difference(b.endDay!).inDays;
      if(diffA == diffB) {
        var compare = a.endDay!.compareTo(b.endDay!);
        if(compare != 0) return compare;
      }
      var compare = a.startDay!.compareTo(b.startDay!);
      if(compare == 0) return diffB - diffA;
      return compare;
    }
    var compare = a.startDay!.compareTo(b.startDay!);
    if(compare == 0) {
      var diffA = a.startDay!.difference(a.endDay!).inDays;
      var diffB = b.startDay!.difference(b.endDay!).inDays;
      return diffB - diffA;
    }
    return compare;
  },);
  return list;
}




///
class ListOfGroupedDeadlinesWidget extends StatelessWidget {
  /// ParentController of which there should be only one instance per app
  final ParentController parent;
  /// Future that eventually returns a list of groups of deadlines
  final Future<List<Group>> listFuture;
  /// scroll controller that can be used to reset the scroll position of the list
  final ScrollController scrollController;
  /// Called when not an item, but the background of the list (for example next to a label) is tapped
  final VoidCallback? onTappedOutsideItems;
  const ListOfGroupedDeadlinesWidget(this.parent, {required this.listFuture, required this.scrollController, this.onTappedOutsideItems, super.key});

  @override Widget build(BuildContext context) {
    final stableContext = context;
    return FutureBuilder(
      future: listFuture,
      builder: (context, snapshot) {
        if(!snapshot.hasData) return Container();
        return GestureDetector(
          onTap: () { if(onTappedOutsideItems != null) onTappedOutsideItems!(); },
          child: ListView.builder(
            controller: scrollController,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var upcoming = snapshot.data![index];
              var firstNonNullIndex = upcoming.content.takeWhile((d) => d == null).length;
              if(upcoming.label.isEmpty) {
                return const SizedBox(height: 25,);
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: upcoming.content.length + (upcoming.content.isEmpty? 0 : 1),
                  padding: const EdgeInsets.all(5),
                  itemBuilder: (context, index) {
                    if (index == firstNonNullIndex) {
                      return Text(upcoming.label, style: TextStyle(color: upcoming.startDay != null && isSameDay(upcoming.startDay!, DateTime.now()) ? const Color(0xFFF94144) : null),);
                    }
                    var d = upcoming.content[index < firstNonNullIndex? index:index - 1];
                    if(d == null) {
                      return const SizedBox(height: 25,);
                    } else {
                      return DeadlineCard(parent, stableContext, d, upcoming.startDay,);
                    }
                  }
                );
              }
            },
          ),
        );
      }
    );
  }
}