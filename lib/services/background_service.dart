import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';
import '../models/models.dart';
import '../utils/prefs_keys.dart';

/// - 그 외: 로컬 알림만 처리₩₩
/// 백그라운드 작업 (WorkManager).
/// - passive 모드: 서버에 자동 체크인
class BackgroundService {
  static const _kServerToken = 'server_token';

  static Future<bool> performCheckIn() async {
    await NotificationService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(PrefsKeys.checkinMode) ?? 'manual';

    // ── passive 모드: 백그라운드에서 자동 체크인 ──────────────
    if (mode == 'passive') {
      const secure = FlutterSecureStorage();
      final token = await secure.read(key: _kServerToken);
      if (token != null) {
        try {
          final ms = prefs.getInt(PrefsKeys.lastCheckIn);
          final lastCheckIn = ms != null
              ? DateTime.fromMillisecondsSinceEpoch(ms)
              : null;
          final intervalHours2 = prefs.getInt(PrefsKeys.intervalHours) ?? 24;
          final tooRecent = lastCheckIn != null &&
              lastCheckIn.add(Duration(hours: intervalHours2)).isAfter(DateTime.now());

          if (!tooRecent) {
            final res = await ApiService.checkIn(token);
            final checkedAt = res['checked_at']?.toString();
            final ts = checkedAt != null
                ? DateTime.parse(checkedAt).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;
            await prefs.setInt(PrefsKeys.lastCheckIn, ts);
            await prefs.setBool(PrefsKeys.alertSent, false);
          }
        } catch (e) {
          // 네트워크 실패 시 무시
        }
      }
    }

    // ── 알림 처리 (모든 모드 공통) ───────────────────────────
    final ms = prefs.getInt(PrefsKeys.lastCheckIn);
    if (ms == null) return true;

    final lastCheckIn = DateTime.fromMillisecondsSinceEpoch(ms);
    final intervalHours = prefs.getInt(PrefsKeys.intervalHours) ?? 24;
    final elapsed = DateTime.now().difference(lastCheckIn);
    final remaining = Duration(hours: intervalHours) - elapsed;

    if (remaining.isNegative) {
      final hoursOverdue = elapsed.inHours - intervalHours;
      final lastOverdueNotif = prefs.getInt(PrefsKeys.lastOverdueNotif) ?? 0;
      final sinceLastNotif = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastOverdueNotif));
      if (sinceLastNotif.inHours >= 6) {
        await NotificationService.showOverdueReminderNotification(
            hoursOverdue: hoursOverdue);
        await prefs.setInt(
            PrefsKeys.lastOverdueNotif, DateTime.now().millisecondsSinceEpoch);
      }
    } else if (remaining.inHours <= 6) {
      await NotificationService.showReminderNotification(remaining.inHours);
    }

    // ── 위젯 업데이트 ───────────────────────────────────────────
    await WidgetService.initialize();
    final wMs = prefs.getInt(PrefsKeys.lastCheckIn);
    if (wMs != null) {
      final wLastCheckIn = DateTime.fromMillisecondsSinceEpoch(wMs);
      final wIntervalHours = prefs.getInt(PrefsKeys.intervalHours) ?? 24;
      final wElapsed = DateTime.now().difference(wLastCheckIn);
      final wRemaining = Duration(hours: wIntervalHours) - wElapsed;
      final wStatus = wRemaining.isNegative
          ? CheckinStatus.overdue
          : wRemaining.inHours < 8
              ? CheckinStatus.warning
              : CheckinStatus.safe;
      await WidgetService.update(
        status: wStatus,
        lastCheckIn: wLastCheckIn,
        timeRemaining: wRemaining,
      );
    }

    return true;
  }

  /// 홈 위젯 버튼 탭 시 백그라운드 체크인.
  /// 앱을 열지 않고 API 호출 후 위젯 갱신.
  static Future<bool> widgetCheckIn() async {
    await NotificationService.initialize();

    const secure = FlutterSecureStorage();
    final token = await secure.read(key: _kServerToken);
    if (token == null) return false;

    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await ApiService.checkIn(token);
      final checkedAt = res['checked_at']?.toString();
      final ts = checkedAt != null
          ? DateTime.parse(checkedAt).millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(PrefsKeys.lastCheckIn, ts);
      await prefs.setBool(PrefsKeys.alertSent, false);

      final lastCheckIn = DateTime.fromMillisecondsSinceEpoch(ts);
      final intervalHours = prefs.getInt(PrefsKeys.intervalHours) ?? 24;
      final remaining = Duration(hours: intervalHours);

      await WidgetService.initialize();
      await WidgetService.update(
        status: CheckinStatus.safe,
        lastCheckIn: lastCheckIn,
        timeRemaining: remaining,
      );

      NotificationService.scheduleExpirationReminder(
        lastCheckIn: lastCheckIn,
        intervalHours: intervalHours,
      );
    } catch (e) {
      return false;
    }

    return true;
  }
}
