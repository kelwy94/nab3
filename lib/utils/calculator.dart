class NabaCalculator {
  /// Calculates if a specific date is an irrigation day for a given well/schedule
  static bool isIrrigationDay({
    required DateTime targetDay,
    required DateTime? dynamicStartDate,
    required int frequencyDays,
    required String fairnessRule,
    Map<String, dynamic>? manualSchedule,
  }) {
    final freq = frequencyDays > 0 ? frequencyDays : 1;
    final target = DateTime.utc(targetDay.year, targetDay.month, targetDay.day);

    if (fairnessRule == 'FairnessRule.manual' || fairnessRule == 'manual') {
      if (manualSchedule != null && manualSchedule.containsKey('dayOffset')) {
        final dayOffset = manualSchedule['dayOffset'] as int;
        final base = DateTime.utc(2024, 1, 1);
        final diff = target.difference(base).inDays;
        return diff % freq == dayOffset;
      }
      return false;
    } else if (dynamicStartDate != null) {
      final start = DateTime.utc(
          dynamicStartDate.year, dynamicStartDate.month, dynamicStartDate.day);
      if (target.isBefore(start)) return false;
      final diff = target.difference(start).inDays;
      return diff % freq == 0;
    }
    return false;
  }

  /// Reference pricing for Jumbo Trucks by location (Farafra)
  static double getJumboReferencePrice(String locationName) {
    if (locationName.contains('الفرافرة') || locationName.contains('مدينة')) {
      return 2000.0;
    } else if (locationName.contains('الكفاح') ||
        locationName.contains('أبو منقار')) {
      return 2500.0;
    } else if (locationName.contains('سهل بركة')) {
      return 3500.0;
    }
    return 2000.0; // default base price
  }

  /// Calculates Tractor rental cost based on unit (per hour vs per feddan)
  static double calculateTractorCost({
    required double baseRate,
    required String unit,
    required double usageAmount,
  }) {
    if (baseRate < 0 || usageAmount < 0) return 0.0;
    // For both 'ساعة' and 'فدان', it's a simple multiplication right now.
    return baseRate * usageAmount;
  }
}
