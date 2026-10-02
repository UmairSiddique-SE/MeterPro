import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderSettings {
  final bool enabled;
  final bool billReminders;
  final bool highUsageAlert;
  final String frequency; // Daily or Weekly
  final TimeOfDay reminderTime;

  const ReminderSettings({
    this.enabled = true,
    this.billReminders = true,
    this.highUsageAlert = true,
    this.frequency = 'Daily',
    required this.reminderTime,
  });

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'billReminders': billReminders,
        'highUsageAlert': highUsageAlert,
        'frequency': frequency,
        'hour': reminderTime.hour,
        'minute': reminderTime.minute,
      };

  factory ReminderSettings.fromMap(Map<String, dynamic> map) {
    final hour = map['hour'] as int? ?? 9;
    final minute = map['minute'] as int? ?? 0;
    return ReminderSettings(
      enabled: map['enabled'] as bool? ?? true,
      billReminders: map['billReminders'] as bool? ?? true,
      highUsageAlert: map['highUsageAlert'] as bool? ?? true,
      frequency: map['frequency'] as String? ?? 'Daily',
      reminderTime: TimeOfDay(hour: hour, minute: minute),
    );
  }
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _prefKey = 'meterpro_reminder_settings';

  Future<void> _ensureAndroidPermissions() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.requestNotificationsPermission();

    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (_) {
      debugPrint('Exact alarm permission check skipped.');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {
      try {
        for (final name in tz.timeZoneDatabase.locations.keys) {
          if (name.contains('Karachi') || name.contains('Pakistan')) {
            tz.setLocalLocation(tz.getLocation(name));
            break;
          }
        }
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);
    await _ensureAndroidPermissions();

    // Explicitly create notification channel for Android 8.0+
    const androidChannel = AndroidNotificationChannel(
      'meterpro_reminders_v3',
      'MeterPro Reminders',
      description: 'Daily meter reading alerts and scheduled reminders.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;

    // Always ensure a reminder is scheduled on app start
    await scheduleReminder(await loadSettings());
  }

  Future<void> showTestNotification() async {
    try {
      if (!_initialized) await initialize();
      await _ensureAndroidPermissions();

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders_v3',
        'MeterPro Reminders',
        channelDescription: 'Daily meter reading alerts and scheduled reminders.',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _localNotifications.show(
        99,
        '⚡ MeterPro: Test Notification',
        'Notifications bilkul sahi kaam kar rahe hain! Aap ko rozana reminder notification milega.',
        details,
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// Schedules a test reminder for N seconds from now (default 15s) to test background waking
  Future<DateTime> scheduleQuickTestReminder({int seconds = 15}) async {
    if (!_initialized) await initialize();
    await _ensureAndroidPermissions();

    final now = DateTime.now();
    final scheduledDate = now.add(Duration(seconds: seconds));
    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'meterpro_reminders_v4',
      'MeterPro Reminders',
      channelDescription: 'Daily meter reading alerts and scheduled reminders.',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      ticker: 'MeterPro quick test',
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    try {
      await _localNotifications.zonedSchedule(
        998,
        'MeterPro: Test Reminder ($seconds sec)',
        'Background alarm timer 100% active aur working hai!',
        scheduledTz,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: 'meterpro_quick_test',
      );
    } catch (_) {
      await _localNotifications.zonedSchedule(
        998,
        'MeterPro: Test Reminder ($seconds sec)',
        'Background alarm timer 100% active aur working hai!',
        scheduledTz,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'meterpro_quick_test',
      );
    }

    return scheduledDate;
  }

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) {
      return const ReminderSettings(
        enabled: true,
        reminderTime: TimeOfDay(hour: 9, minute: 0),
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ReminderSettings(
          enabled: true,
          reminderTime: TimeOfDay(hour: 9, minute: 0),
        );
      }
      return ReminderSettings.fromMap(decoded);
    } catch (_) {
      return const ReminderSettings(
        enabled: true,
        reminderTime: TimeOfDay(hour: 9, minute: 0),
      );
    }
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(settings.toMap()));
    await scheduleReminder(settings);
  }

  Future<DateTime> scheduleReminder(ReminderSettings settings) async {
    try {
      if (!_initialized) await initialize();
      await _localNotifications.cancel(1);

      if (!settings.enabled) {
        return DateTime.now();
      }

      await _ensureAndroidPermissions();

      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        settings.reminderTime.hour,
        settings.reminderTime.minute,
        0,
      );

      // If scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(
          Duration(days: settings.frequency == 'Weekly' ? 7 : 1),
        );
      }

      final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders_v4',
        'MeterPro Reminders',
        channelDescription: 'Daily meter reading alerts and scheduled reminders.',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        ticker: 'MeterPro reminder',
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use alarmClock mode without matchDateTimeComponents for 100% Android alarm accuracy
      try {
        await _localNotifications.zonedSchedule(
          1,
          'MeterPro Reminder',
          settings.billReminders && settings.highUsageAlert
              ? 'Apna bijli ka meter reading check karein aur units record karein.'
              : 'Time to check your electricity meter reading and record units.',
          scheduledTz,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          payload: 'meterpro_reminder',
        );
      } catch (alarmClockErr) {
        debugPrint('alarmClock mode fallback to exactAllowWhileIdle: $alarmClockErr');
        try {
          await _localNotifications.zonedSchedule(
            1,
            'MeterPro Reminder',
            settings.billReminders && settings.highUsageAlert
                ? 'Apna bijli ka meter reading check karein aur units record karein.'
                : 'Time to check your electricity meter reading and record units.',
            scheduledTz,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'meterpro_reminder',
          );
        } catch (exactErr) {
          debugPrint('exactAllowWhileIdle fallback to inexact: $exactErr');
          await _localNotifications.zonedSchedule(
            1,
            'MeterPro Reminder',
            'Apna bijli ka meter reading check karein aur units record karein.',
            scheduledTz,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'meterpro_reminder',
          );
        }
      }

      return scheduledDate;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return DateTime.now();
    }
  }

}
