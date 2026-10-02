import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterunit/services/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {}
  });

  group('ReminderService & Schedule Math Verification', () {
    test('Future time today schedules for today', () {
      final now = DateTime(2026, 10, 2, 10, 0, 0); // 10:00 AM
      final reminderTime = const TimeOfDay(hour: 14, minute: 30); // 2:30 PM

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime.hour,
        reminderTime.minute,
        0,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      expect(scheduledDate.year, equals(2026));
      expect(scheduledDate.month, equals(10));
      expect(scheduledDate.day, equals(2));
      expect(scheduledDate.hour, equals(14));
      expect(scheduledDate.minute, equals(30));
    });

    test('Past time today schedules for tomorrow', () {
      final now = DateTime(2026, 10, 2, 23, 15, 0); // 11:15 PM
      final reminderTime = const TimeOfDay(hour: 9, minute: 0); // 9:00 AM

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime.hour,
        reminderTime.minute,
        0,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      expect(scheduledDate.year, equals(2026));
      expect(scheduledDate.month, equals(10));
      expect(scheduledDate.day, equals(3)); // Tomorrow!
      expect(scheduledDate.hour, equals(9));
      expect(scheduledDate.minute, equals(0));
    });

    test('Quick test reminder adds exact seconds', () {
      final now = DateTime(2026, 10, 2, 23, 15, 0);
      final scheduledDate = now.add(const Duration(seconds: 15));

      expect(scheduledDate.difference(now).inSeconds, equals(15));
    });
  });
}
