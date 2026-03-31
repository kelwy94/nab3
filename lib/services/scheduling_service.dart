import '../models/types.dart';

class SchedulingService {
  static List<IrrigationSlot> generateSchedule({
    required Well well,
    required List<WellMember> members,
    required DateTime startDate,
    required int daysToGenerate,
  }) {
    List<IrrigationSlot> slots = [];
    DateTime currentTime = startDate;
    int memberIndex = 0;

    // Filter approved members
    final approvedMembers =
        members.where((m) => m.status == 'approved').toList();
    if (approvedMembers.isEmpty) return [];

    // Simple scheduling algorithm
    for (int day = 0; day < daysToGenerate; day++) {
      String dayName = _getDayName(currentTime.weekday);

      if (well.allowedDays.contains(dayName)) {
        // Parse start/end hours
        final startParts = well.allowedHours['start']!.split(':');
        final endParts = well.allowedHours['end']!.split(':');

        DateTime slotStart = DateTime(
          currentTime.year,
          currentTime.month,
          currentTime.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );
        DateTime dayEnd = DateTime(
          currentTime.year,
          currentTime.month,
          currentTime.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        while (slotStart
            .add(Duration(minutes: well.slotDuration))
            .isBefore(dayEnd)) {
          final member =
              _getNextMember(approvedMembers, well.fairnessRule, memberIndex);

          slots.add(IrrigationSlot(
            id: 'slot_${slots.length}',
            scheduleId: 'sched_current',
            wellId: well.id,
            userId: member.userId,
            startTime: slotStart,
            endTime: slotStart.add(Duration(minutes: well.slotDuration)),
            status: 'planned',
          ));

          slotStart = slotStart.add(Duration(minutes: well.slotDuration));
          memberIndex++;
        }
      }
      currentTime = currentTime.add(const Duration(days: 1));
    }

    return slots;
  }

  static WellMember _getNextMember(
      List<WellMember> members, FairnessRule rule, int index) {
    if (rule == FairnessRule.equal) {
      return members[index % members.length];
    } else {
      // Proportional logic (Simplified: weighted random or sorted list expansion)
      // For MVP, we'll repeat members in the list based on their land area weight
      List<WellMember> weightedList = [];
      for (var m in members) {
        int weight =
            (m.landAreaFeddan / 5).ceil(); // 1 slot per 5 feddans minimum
        for (int i = 0; i < weight; i++) {
          weightedList.add(m);
        }
      }
      return weightedList[index % weightedList.length];
    }
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      default:
        return 'sat';
    }
  }
}
