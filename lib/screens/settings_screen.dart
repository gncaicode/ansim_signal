import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/checkin_provider.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckinProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            centerTitle: true,
            title: const Text('설정'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // ── 내 정보 ───────────────────────────────────
              _SectionLabel(label: '내 정보'),
              _Card(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: '이름',
                      value: provider.userName.isEmpty
                          ? '이름 미설정'
                          : provider.userName,
                    ),
                    const Divider(height: 1, color: AppTheme.appInfoSep),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: '마지막 신호',
                      value: provider.lastCheckIn != null
                          ? _formatDateTime(provider.lastCheckIn!)
                          : '아직 신호 없음',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 체크인 방식 ───────────────────────────────
              _SectionLabel(label: '체크인 방식'),
              _CheckinModeCard(
                current: provider.checkinMode,
                onChanged: (mode) => provider.setCheckinMode(mode),
              ),
              const SizedBox(height: 24),

              // ── 체크인 주기 ───────────────────────────────
              _SectionLabel(label: '체크인 주기'),
              _IntervalCard(
                current: provider.intervalHours,
                onChanged: (h) => provider.setIntervalHours(h),
              ),
              const SizedBox(height: 24),

              // ── 담당 복지사 ───────────────────────────────
              _SectionLabel(label: '담당 복지사'),
              _Card(
                child: provider.careWorker != null
                    ? Column(
                        children: [
                          _InfoRow(
                            icon: Icons.health_and_safety_outlined,
                            label: '담당자 이름',
                            value: provider.careWorker!.name,
                          ),
                          const Divider(height: 1, color: AppTheme.appInfoSep),
                          _InfoRow(
                            icon: Icons.business_outlined,
                            label: '소속',
                            value: provider.careWorker!.organization,
                          ),
                          if (provider.careWorker!.phone.isNotEmpty) ...[
                            const Divider(height: 1, color: AppTheme.appInfoSep),
                            _CallRow(
                              phone: provider.careWorker!.phone,
                            ),
                          ],
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: AppTheme.textMedium),
                            const SizedBox(width: 10),
                            Text(
                              '담당자 정보가 등록되지 않았습니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // ── 앱 정보 ───────────────────────────────────
              _SectionLabel(label: '앱 정보'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceMuted, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTheme.glowColor,
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          const Text(
                            '버전',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.appInfoSep),
                    InkWell(
                      onTap: () => _showResetDialog(context),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            const Text(
                              '앱 초기화',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: AppTheme.textSubtle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showResetDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _ResetDialog(),
    );

    if (ok == true && context.mounted) {
      await context.read<CheckinProvider>().reset();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    }
  }

  static String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 섹션 레이블 ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMedium,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 카드 컨테이너 ───────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceMuted, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glowColor,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── 정보 행 (읽기 전용) ────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 전화하기 행 ────────────────────────────────────────────────
class _CallRow extends StatelessWidget {
  final String phone;
  const _CallRow({required this.phone});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _call,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.phone_rounded, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            const Text(
              '전화하기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
            const Spacer(),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 초기화 확인 다이얼로그 ───────────────────────────────────
class _ResetDialog extends StatelessWidget {
  const _ResetDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '앱 초기화',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '모든 데이터가 삭제되고 처음 화면으로 돌아갑니다.\n계속하시겠습니까?',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '초기화',
                    style: TextStyle(
                      color: AppTheme.dangerRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 체크인 방식 선택 카드 ───────────────────────────────────
class _CheckinModeCard extends StatelessWidget {
  final CheckinMode current;
  final ValueChanged<CheckinMode> onChanged;

  const _CheckinModeCard({
    required this.current,
    required this.onChanged,
  });

  static const _modes = [
    (
      mode: CheckinMode.manual,
      icon: Icons.touch_app_rounded,
      title: '직접 누르기',
      desc: '홈화면의 버튼을 눌렀을 때만 신호를 보냅니다.',
    ),
    (
      mode: CheckinMode.appOpen,
      icon: Icons.phone_android_rounded,
      title: '앱을 열 때 자동',
      desc: '앱을 실행하거나 화면에 띄울 때 자동으로 신호를 보냅니다.',
    ),
    (
      mode: CheckinMode.passive,
      icon: Icons.sensors_rounded,
      title: '핸드폰 사용 시 자동',
      desc: '백그라운드에서 폰 사용을 감지하여 자동으로 신호를 보냅니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceMuted, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glowColor,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _modes.indexed.map((entry) {
          final i = entry.$1;
          final item = entry.$2;
          final selected = current == item.mode;
          final isLast = i == _modes.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(item.mode),
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: selected
                              ? Colors.white
                              : AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.desc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSubtle,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 22,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textSubtle,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: AppTheme.appInfoSep),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── 체크인 주기 선택 카드 ───────────────────────────────────
class _IntervalCard extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _IntervalCard({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceMuted, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glowColor,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _IntervalOption(
            hours: 12,
            label: '12시간',
            desc: '하루 2회',
            selected: current == 12,
            isFirst: true,
            onTap: () => onChanged(12),
          ),
          Container(width: 1, height: 72, color: AppTheme.appInfoSep),
          _IntervalOption(
            hours: 24,
            label: '24시간',
            desc: '하루 1회',
            selected: current == 24,
            isFirst: false,
            onTap: () => onChanged(24),
          ),
        ],
      ),
    );
  }
}

class _IntervalOption extends StatelessWidget {
  final int hours;
  final String label;
  final String desc;
  final bool selected;
  final bool isFirst;
  final VoidCallback onTap;

  const _IntervalOption({
    required this.hours,
    required this.label,
    required this.desc,
    required this.selected,
    required this.isFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(16) : Radius.zero,
          right: isFirst ? Radius.zero : const Radius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? AppTheme.iconBg : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(16) : Radius.zero,
              right: isFirst ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.primary : AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppTheme.primary : AppTheme.textSubtle,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppTheme.primary : AppTheme.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
