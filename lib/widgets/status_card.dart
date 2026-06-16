import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// 신호등 방식 상태 카드 (어르신 친화 — 큰 글씨, 명확한 색상)
class StatusCard extends StatelessWidget {
  final CheckinStatus status;
  final DateTime? lastCheckIn;
  final Duration timeRemaining;
  final double progress;
  final int intervalHours;

  const StatusCard({
    super.key,
    required this.status,
    required this.lastCheckIn,
    required this.timeRemaining,
    required this.progress,
    required this.intervalHours,
  });

  String get _badgeText => switch (status) {
        CheckinStatus.safe    => '안전',
        CheckinStatus.warning => '주의',
        CheckinStatus.overdue => '위급',
        CheckinStatus.unknown => '대기',
      };

  Color get _badgeBg => switch (status) {
        CheckinStatus.safe    => AppTheme.safeGreen,
        CheckinStatus.warning => AppTheme.warningYellow,
        CheckinStatus.overdue => AppTheme.dangerRed,
        CheckinStatus.unknown => AppTheme.surfaceMuted,
      };

  Color get _statusBg => switch (status) {
        CheckinStatus.safe    => AppTheme.safeBg,
        CheckinStatus.warning => AppTheme.warnBg,
        CheckinStatus.overdue => AppTheme.dangerBg,
        CheckinStatus.unknown => AppTheme.background,
      };

  Color get _badgeTextColor => status == CheckinStatus.unknown
      ? AppTheme.textMedium
      : Colors.white;

  Color get _accentColor => switch (status) {
        CheckinStatus.safe    => AppTheme.safeGreen,
        CheckinStatus.warning => AppTheme.warningYellow,
        CheckinStatus.overdue => AppTheme.dangerRed,
        CheckinStatus.unknown => AppTheme.textMedium,
      };

  String _formatRemaining() {
    if (status == CheckinStatus.unknown) return '버튼을 눌러 신호를 보내주세요';
    if (status == CheckinStatus.overdue) {
      final over = timeRemaining.abs();
      return '${over.inHours}시간 ${over.inMinutes.remainder(60)}분 초과';
    }
    if (timeRemaining.inHours > 0) {
      return '${timeRemaining.inHours}시간 ${timeRemaining.inMinutes.remainder(60)}분 남음';
    }
    return '${timeRemaining.inMinutes}분 남음';
  }

  String _lastSentText() {
    if (lastCheckIn == null) return '';
    final diff = DateTime.now().difference(lastCheckIn!);
    if (diff.inMinutes < 1) return '방금 전 전송';
    if (diff.inHours < 1)   return '${diff.inMinutes}분 전 전송';
    if (diff.inHours < 24)  return '${diff.inHours}시간 전 전송';
    return '${diff.inDays}일 전 전송';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _statusBg,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: AppTheme.surfaceMuted, width: 1),
        boxShadow: const [
          BoxShadow(color: AppTheme.glowColor, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── 신호등 배지 + 마지막 전송 시간 ──────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _badgeText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _badgeTextColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                _lastSentText(),
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 진행 바 ─────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.progressBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.ease,
                  height: 5,
                  width: constraints.maxWidth * remaining,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 남은 시간 텍스트 ─────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatRemaining(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
