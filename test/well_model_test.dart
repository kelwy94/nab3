import 'package:flutter_test/flutter_test.dart';
import 'package:nab3_gded/models/types.dart';

void main() {
  group('Well Model Tests', () {
    test('Well instance should correctly store and assign dynamic schedule parameters', () {
      final well = Well(
        id: '123',
        adminUserId: 'admin_1',
        wellName: 'بئر الاختبار',
        location: {'lat': 0.0, 'lng': 0.0},
        depthMeters: 50.0,
        irrigatedAreaFeddan: 10.0,
        allowedDays: ['السبت'],
        allowedHours: {'start': '08:00', 'end': '18:00'},
        slotDuration: 60,
        hoursPerPerson: 5.5,
        irrigationFrequencyDays: 3,
        fairnessRule: FairnessRule.proportional,
      );

      expect(well.hoursPerPerson, 5.5);
      expect(well.irrigationFrequencyDays, 3);
      expect(well.wellName, 'بئر الاختبار');
    });

    test('Well instance should use default schedule parameters if omitted', () {
      final well = Well(
        id: '124',
        adminUserId: 'admin_2',
        wellName: 'بئر افتراضي',
        location: {'lat': 0.0, 'lng': 0.0},
        depthMeters: 20.0,
        irrigatedAreaFeddan: 5.0,
        allowedDays: ['الأحد'],
        allowedHours: {'start': '06:00', 'end': '12:00'},
        slotDuration: 30,
        fairnessRule: FairnessRule.proportional,
      );

      // Default values according to types.dart
      expect(well.hoursPerPerson, 1.0);
      expect(well.irrigationFrequencyDays, 1);
    });
  });
}
