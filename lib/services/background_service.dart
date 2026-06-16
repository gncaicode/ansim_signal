import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../utils/prefs_keys.dart';

/// 백그라운드 작업 (WorkManager).
/// - passive 모드: 서버에 자동 체크인
/// - 그 외: 로컬 알림만 처리
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
          // 다음 마감 전까지 중복 방지
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

    return true;
  }
}
