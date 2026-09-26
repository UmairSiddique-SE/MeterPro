import 'dart:convert';

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

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
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

    // Explicitly create notification channel for Android 8.0+
    const androidChannel = AndroidNotificationChannel(
      'meterpro_reminders',
      'MeterPro Reminders',
      description: 'Daily and weekly meter reading reminders.',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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

  Future<void> scheduleReminder(ReminderSettings settings) async {
    try {
      if (!_initialized) await initialize();
      await _localNotifications.cancelAll();

      if (!settings.enabled) {
        return;
      }

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        settings.reminderTime.hour,
        settings.reminderTime.minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(
          Duration(days: settings.frequency == 'Weekly' ? 7 : 1),
        );
      }

      const androidDetails = AndroidNotificationDetails(
        'meterpro_reminders',
        'MeterPro Reminders',
        channelDescription: 'Daily and weekly meter reading reminders.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        ticker: 'MeterPro reminder',
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _localNotifications.zonedSchedule(
          1,
          'Check your meter reading',
          settings.billReminders && settings.highUsageAlert
              ? 'Your meter reminder is ready. Check reading and usage.'
              : 'Time to check your meter reading.',
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
      } catch (_) {
        await _localNotifications.zonedSchedule(
          1,
          'Check your meter reading',
          settings.billReminders && settings.highUsageAlert
              ? 'Your meter reminder is ready. Check reading and usage.'
              : 'Time to check your meter reading.',
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
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> showTestNotification() async {
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
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
