import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 안부 신호 마감 임박 알림 (24시간 기준 6시간 전)
  static Future<void> showReminderNotification(int hoursLeft) async {
    await _plugin.show(
      1,
      '오늘 안부 신호를 보내주세요',
      '$hoursLeft시간 안에 안부 신호를 전송해 주세요.',
      _notificationDetails(
        channelId: 'reminder',
        channelName: '안부 알림',
        color: const Color(0xFF4CAF50),
        importance: Importance.high,
      ),
    );
  }

  /// 담당 복지사에게 알림 발송됨
  static Future<void> showAlertSentNotification(String workerName) async {
    await _plugin.show(
      2,
      '담당 복지사에게 알림이 발송되었습니다',
      '$workerName님께 미확인 알림을 보냈습니다.',
      _notificationDetails(
        channelId: 'alert',
        channelName: '긴급 알림',
        color: const Color(0xFFE53935),
        importance: Importance.max,
      ),
    );
  }

  /// 초과 후 6시간마다 반복 경고
  static Future<void> showOverdueReminderNotification({
    required int hoursOverdue,
  }) async {
    await _plugin.show(
      6,
      '안부 신호 미확인 중',
      '$hoursOverdue시간째 안부 신호가 없습니다. 지금 바로 전송해 주세요.',
      _notificationDetails(
        channelId: 'alert',
        channelName: '긴급 알림',
        color: const Color(0xFFE53935),
        importance: Importance.max,
      ),
    );
  }

  static NotificationDetails _notificationDetails({
    required String channelId,
    required String channelName,
    required Color color,
    required Importance importance,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: importance == Importance.max ? Priority.max : Priority.high,
        color: color,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();

  static Future<void> cancel(int id) async => _plugin.cancel(id);

  /// 안부 신호 만료 5분 전 예약 알림 (ID: 7)
  static Future<void> scheduleExpirationReminder({
    required DateTime lastCheckIn,
    required int intervalHours,
  }) async {
    await _plugin.cancel(7);

    final expiresAt = lastCheckIn.add(Duration(hours: intervalHours));
    final notifyAt = expiresAt.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    if (expiresAt.isBefore(now)) return;

    if (notifyAt.isBefore(now)) {
      await _plugin.show(
        7,
        '곧 안부 신호 마감이에요',
        '5분 후 마감됩니다. 지금 바로 신호를 보내주세요.',
        _notificationDetails(
          channelId: 'reminder',
          channelName: '안부 알림',
          color: const Color(0xFF4CAF50),
          importance: Importance.high,
        ),
      );
      return;
    }

    try {
      await _plugin.zonedSchedule(
        7,
        '곧 안부 신호 마감이에요',
        '5분 후 마감됩니다. 지금 바로 신호를 보내주세요.',
        tz.TZDateTime.from(notifyAt, tz.local),
        _notificationDetails(
          channelId: 'reminder',
          channelName: '안부 알림',
          color: const Color(0xFF4CAF50),
          importance: Importance.high,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notification] 만료 5분 전 알림 예약: $notifyAt');
    } catch (e) {
      debugPrint('[Notification] 예약 실패: $e');
    }
  }
}
