import 'package:flutter_test/flutter_test.dart';
import 'package:nab3_gded/utils/calculator.dart';

void main() {
  group('NabaCalculator - Irrigation Logic', () {
    test('isIrrigationDay returns true when offset matches with manual rule',
        () {
      final manualSchedule = {'dayOffset': 1}; // Frequency 3, Day 1
      // Base date is 2024-01-01
      // Diff for 2024-01-03 is 2 days. 2 % 3 = 2. It does not match offset 1.
      // Offset 1 means diff % freq == 1 (e.g. 2024-01-02 -> diff 1)
      final result1 = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 1, 2),
        dynamicStartDate: null,
        frequencyDays: 3,
        fairnessRule: 'manual',
        manualSchedule: manualSchedule,
      );
      expect(result1, isTrue);

      final result2 = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 1, 3),
        dynamicStartDate: null,
        frequencyDays: 3,
        fairnessRule: 'manual',
        manualSchedule: manualSchedule,
      );
      expect(result2, isFalse);
    });

    test(
        'isIrrigationDay returns true for proportional rule with dynamic start date',
        () {
      final startDate = DateTime.utc(2024, 5, 10);

      // Target before start date
      final beforeResult = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 5, 5),
        dynamicStartDate: startDate,
        frequencyDays: 7,
        fairnessRule: 'proportional',
      );
      expect(beforeResult, isFalse);

      // Target exactly on start date (diff = 0)
      final onResult = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 5, 10),
        dynamicStartDate: startDate,
        frequencyDays: 7,
        fairnessRule: 'proportional',
      );
      expect(onResult, isTrue);

      // Target 7 days later (diff = 7)
      final laterResult = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 5, 17),
        dynamicStartDate: startDate,
        frequencyDays: 7,
        fairnessRule: 'proportional',
      );
      expect(laterResult, isTrue);

      // Target 8 days later (diff = 8)
      final invalidLaterResult = NabaCalculator.isIrrigationDay(
        targetDay: DateTime.utc(2024, 5, 18),
        dynamicStartDate: startDate,
        frequencyDays: 7,
        fairnessRule: 'proportional',
      );
      expect(invalidLaterResult, isFalse);
    });
  });

  group('NabaCalculator - Jumbo Reference Pricing', () {
    test('calculates correct base prices based on Farafra locations', () {
      expect(NabaCalculator.getJumboReferencePrice('الفرافرة (المدينة)'),
          equals(2000.0));
      expect(
          NabaCalculator.getJumboReferencePrice('مدينة أبو منقار'),
          equals(
              2000.0)); // Wait, contains both 'مدينة' and 'أبو منقار'. Code checks 'مدينة' first.
    });

    test('prices for Kefah and Sahl Baraka', () {
      expect(
          NabaCalculator.getJumboReferencePrice('قرية الكفاح'), equals(2500.0));
      expect(
          NabaCalculator.getJumboReferencePrice('سهل بركة 2'), equals(3500.0));
    });

    test('default price is 2000 for unknown locations', () {
      expect(NabaCalculator.getJumboReferencePrice('القاهرة'), equals(2000.0));
    });
  });

  group('NabaCalculator - Tractor Pricing', () {
    test('calculates per hour billing correctly', () {
      final cost = NabaCalculator.calculateTractorCost(
        baseRate: 200.0,
        unit: 'ساعة',
        usageAmount: 5.5,
      );
      expect(cost, equals(1100.0));
    });

    test('calculates per feddan billing correctly', () {
      final cost = NabaCalculator.calculateTractorCost(
        baseRate: 500.0,
        unit: 'فدان',
        usageAmount: 2.0,
      );
      expect(cost, equals(1000.0));
    });

    test('handles negative values correctly by returning 0', () {
      final cost = NabaCalculator.calculateTractorCost(
        baseRate: -100.0,
        unit: 'ساعة',
        usageAmount: 5,
      );
      expect(cost, equals(0.0));

      final cost2 = NabaCalculator.calculateTractorCost(
        baseRate: 100.0,
        unit: 'ساعة',
        usageAmount: -5,
      );
      expect(cost2, equals(0.0));
    });
  });
}
