import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/models.dart';

/// 홈 화면 위젯 데이터/갱신 관리.
/// Android: FlutterSharedPreferences 직접 읽음 → updateWidget 브로드캐스트만 전송.
/// iOS: UserDefaults(App Group)에 데이터 저장 → CheckinIntent가 읽어 사용.
class WidgetService {
  static const _appGroupId = 'group.com.gncaitech.ansim_signal';
  static const _androidSmallName = 'AnsimWidgetProvider';
  static const _androidMediumName = 'AnsimWidgetMediumProvider';
  static const _iosName = 'AnsimWidget';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// iOS 위젯에서 체크인 시 사용할 서버 토큰 저장 (App Group UserDefaults)
  static Future<void> saveToken(String token) async {
    try {
      await HomeWidget.saveWidgetData('ansim_server_token', token);
    } catch (e) {
      debugPrint('[Widget] saveToken failed: $e');
    }
  }

  static Future<void> update({
    required CheckinStatus status,
    required DateTime? lastCheckIn,
    required Duration timeRemaining,
    int intervalHours = 24,
  }) async {
    try {
      final statusStr = switch (status) {
        CheckinStatus.safe => 'safe',
        CheckinStatus.warning => 'warning',
        CheckinStatus.overdue => 'overdue',
        CheckinStatus.unknown => 'unknown',
      };
      final lastCheckinStr = lastCheckIn != null ? _formatTime(lastCheckIn) : '--';
      final timeRemainingStr = _formatRemaining(timeRemaining, status);

      // iOS: App Group UserDefaults에 저장 (CheckinIntent가 읽어 사용)
      await HomeWidget.saveWidgetData('ansim_status', statusStr);
      await HomeWidget.saveWidgetData('ansim_last_checkin', lastCheckinStr);
      await HomeWidget.saveWidgetData('ansim_time_remaining', timeRemainingStr);
      await HomeWidget.saveWidgetData('ansim_interval_hours', intervalHours);
      if (lastCheckIn != null) {
        await HomeWidget.saveWidgetData(
            'ansim_last_checkin_ms', lastCheckIn.millisecondsSinceEpoch);
      }

      // 위젯 갱신 트리거
      await HomeWidget.updateWidget(androidName: _androidSmallName, iOSName: _iosName);
      await HomeWidget.updateWidget(androidName: _androidMediumName, iOSName: _iosName);
    } catch (e) {
      debugPrint('[Widget] update failed: $e');
    }
  }

  static String _formatTime(DateTime dt) {
    final period = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  static String _formatRemaining(Duration remaining, CheckinStatus status) {
    if (status == CheckinStatus.unknown) return '신호 없음';
    if (remaining.isNegative) {
      final hours = remaining.inHours.abs();
      return hours > 0 ? '$hours시간 초과' : '초과됨';
    }
    if (remaining.inHours >= 1) return '${remaining.inHours}시간 남음';
    return '${remaining.inMinutes}분 남음';
  }
}
