import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../database/database.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _logNowAction = 'log_now';
  static const _hydrationBaseId = 90000;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onResponse(NotificationResponse response) {
    if (response.actionId == _logNowAction) _acknowledgeLog();
  }

  /// "Log Now" tapped in the notification shade: records acknowledgement.
  static Future<void> _acknowledgeLog() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.insert('daily_logs', {
      'date': date,
      'meal_slot': 'Supplements',
      'source_type': 'None',
      'source_id': 0,
      'grams_consumed': 0,
    });
  }

  static const _mealChannel = NotificationDetails(
    android: AndroidNotificationDetails(
      'meals',
      'Meals & Supplements',
      channelDescription: 'Fixed-time meal and supplement reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [AndroidNotificationAction(_logNowAction, 'Log Now')],
    ),
  );

  static tz.TZDateTime _nextInstanceOfDay(int weekday, int hour, int minute) {
    var t = tz.TZDateTime(tz.local, tz.TZDateTime.now(tz.local).year,
        tz.TZDateTime.now(tz.local).month, tz.TZDateTime.now(tz.local).day,
        hour, minute);
    while (t.weekday != weekday || !t.isAfter(tz.TZDateTime.now(tz.local))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  /// Fixed-time reminder, one notification per active weekday.
  /// [days]: 1=Mon ... 7=Sun (DateTime.weekday convention).
  static Future<void> scheduleFixed(
      int dbId, String title, int hour, int minute, List<int> days) async {
    for (final d in days) {
      await _plugin.zonedSchedule(
        dbId * 10 + d,
        title,
        'Tap "Log Now" when done',
        _nextInstanceOfDay(d, hour, minute),
        _mealChannel,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> cancelReminder(int dbId, List<int> days) async {
    for (final d in days) {
      await _plugin.cancel(dbId * 10 + d);
    }
  }

  /// Hydration pings between [startHour] and [endHour], every [intervalMin].
  /// Re-schedules daily when the app opens.
  static Future<void> scheduleHydration(
      int startHour, int endHour, int intervalMin) async {
    for (var i = 0; i < 60; i++) {
      await _plugin.cancel(_hydrationBaseId + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, startHour);
    var i = 0;
    while (t.hour < endHour && i < 60) {
      if (t.isAfter(now)) {
        await _plugin.zonedSchedule(
          _hydrationBaseId + i,
          '💧 Hydration',
          'Time for a glass of water',
          t,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'water', 'Hydration',
              importance: Importance.defaultImportance,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        i++;
      }
      t = t.add(Duration(minutes: intervalMin));
    }
  }
}
