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
      'meterpro_reminders',
      'MeterPro Reminders',
      description: 'Daily and weekly meter reading reminders.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;

    // Android removes scheduled alarms when the device restarts. Restore the
    // user's reminder after plugin setup so reminders survive a reboot/update.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      await scheduleReminder(await loadSettings());
    }
  }

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) {
      return const ReminderSettings(
        reminderTime: TimeOfDay(hour: 9, minute: 0),
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ReminderSettings(
          reminderTime: TimeOfDay(hour: 9, minute: 0),
        );
      }
      return ReminderSettings.fromMap(decoded);
    } catch (_) {
      return const ReminderSettings(
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
      await _localNotifications.cancelAll();

      if (!settings.enabled) {
        return DateTime.now();
      }

      await _ensureAndroidPermissions();

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        settings.reminderTime.hour,
        settings.reminderTime.minute,
        0,
      );

      // If scheduled time is in the past (more than 5 seconds ago), schedule for next occurrence
      if (scheduled.isBefore(now.subtract(const Duration(seconds: 5)))) {
        scheduled = scheduled.add(
          Duration(days: settings.frequency == 'Weekly' ? 7 : 1),
        );
      }

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders',
        'MeterPro Reminders',
        channelDescription: 'Daily and weekly meter reading reminders.',
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

      // Try alarmClock mode first (highest reliability, immune to Vivo/Samsung/Xiaomi Doze freeze)
      try {
        await _localNotifications.zonedSchedule(
          1,
          'Check your meter reading ⚡',
          settings.billReminders && settings.highUsageAlert
              ? 'Your meter reminder is ready. Record your reading to keep your bill accurate.'
              : 'Time to check your meter reading and record units.',
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: settings.frequency == 'Weekly'
              ? DateTimeComponents.dayOfWeekAndTime
              : DateTimeComponents.time,
          payload: 'meterpro_reminder',
        );
      } catch (alarmClockErr) {
        debugPrint('alarmClock mode fallback: $alarmClockErr');
        try {
          await _localNotifications.zonedSchedule(
            1,
            'Check your meter reading ⚡',
            settings.billReminders && settings.highUsageAlert
                ? 'Your meter reminder is ready. Record your reading to keep your bill accurate.'
                : 'Time to check your meter reading and record units.',
            scheduled,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: settings.frequency == 'Weekly'
                ? DateTimeComponents.dayOfWeekAndTime
                : DateTimeComponents.time,
            payload: 'meterpro_reminder',
          );
        } catch (exactErr) {
          debugPrint('exactAllowWhileIdle fallback: $exactErr');
          await _localNotifications.zonedSchedule(
            1,
            'Check your meter reading ⚡',
            'Time to check your meter reading.',
            scheduled,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: settings.frequency == 'Weekly'
                ? DateTimeComponents.dayOfWeekAndTime
                : DateTimeComponents.time,
            payload: 'meterpro_reminder',
          );
        }
      }

      return scheduled;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return DateTime.now();
    }
  }

  /// Schedules a real background alarm to fire after [seconds] seconds.
  /// Useful to immediately verify that background scheduled notifications work on this device.
  Future<void> scheduleQuickTest({int seconds = 10}) async {
    try {
      if (!_initialized) await initialize();
      await _ensureAndroidPermissions();

      final scheduled = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders',
        'MeterPro Reminders',
        channelDescription: 'Daily and weekly meter reading reminders.',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      try {
        await _localNotifications.zonedSchedule(
          999,
          'Meter Reading Reminder ⚡',
          'Scheduled alarm test succeeded! Time to check your meter.',
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          payload: 'quick_test_reminder',
        );
      } catch (_) {
        await _localNotifications.zonedSchedule(
          999,
          'Meter Reading Reminder ⚡',
          'Scheduled alarm test succeeded! Time to check your meter.',
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'quick_test_reminder',
        );
      }
    } catch (e) {
      debugPrint('Error in scheduleQuickTest: $e');
    }
  }

  Future<void> showTestNotification() async {
    try {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        try {
          await androidPlugin.requestExactAlarmsPermission();
        } catch (_) {
          debugPrint('Exact alarm permission not available for this device.');
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders',
        'MeterPro Reminders',
        channelDescription: 'Daily and weekly meter reading reminders.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotifications.show(
        99,
        'Check your meter reading',
        'Test reminder: Time to check your meter reading!',
        details,
        payload: 'test_notification',
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }
}
