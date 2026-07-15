import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          body: SafeArea(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // ── 체크인 방식 ───────────────────────────────
              _SectionLabel(label: '체크인 방식'),
              _CheckinModeCard(current: provider.checkinMode),
              const _AdminManagedNote(),
              const SizedBox(height: 24),

              // ── 체크인 주기 ───────────────────────────────
              _SectionLabel(label: '체크인 주기'),
              _IntervalCard(current: provider.intervalHours),
              const _AdminManagedNote(),
              const SizedBox(height: 24),

              // ── 담당 복지사 ───────────────────────────────
              _SectionLabel(label: '담당 복지사'),
              if (provider.careWorkers.isEmpty)
                _Card(
                  child: Padding(
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
                )
              else
                ...provider.careWorkers.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Card(
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.health_and_safety_outlined,
                              label: '담당자 이름',
                              value: w.name,
                            ),
                            if (w.organization.isNotEmpty) ...[
                              const Divider(height: 1, color: AppTheme.appInfoSep),
                              _InfoRow(
                                icon: Icons.business_outlined,
                                label: '소속',
                                value: w.organization,
                              ),
                            ],
                            if (w.phone.isNotEmpty) ...[
                              const Divider(height: 1, color: AppTheme.appInfoSep),
                              _CallRow(phone: w.phone),
                            ],
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 24),

              // ── 설정 확인 ─────────────────────────────────
              _SectionLabel(label: '설정 확인'),
              const _TestConnectionCard(),
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

// ── 관리자 설정 안내 문구 ───────────────────────────────────
class _AdminManagedNote extends StatelessWidget {
  const _AdminManagedNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.textSubtle),
          const SizedBox(width: 4),
          Text(
            '담당 기관에서 설정합니다.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSubtle),
          ),
        ],
      ),
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

// ── 설정 확인 카드 ───────────────────────────────────────────
class _TestConnectionCard extends StatefulWidget {
  const _TestConnectionCard();

  @override
  State<_TestConnectionCard> createState() => _TestConnectionCardState();
}

class _TestConnectionCardState extends State<_TestConnectionCard> {
  bool _isSending = false;

  Future<void> _send() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    final provider = context.read<CheckinProvider>();
    final success = await provider.sendTestConnection();

    if (!mounted) return;
    setState(() => _isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '테스트 신호를 보냈습니다. 관리자 화면에서 확인해보세요.'
            : '전송에 실패했습니다. 네트워크 연결을 확인해주세요.'),
        backgroundColor: success ? AppTheme.primary : AppTheme.dangerRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '서버 연결 상태를 확인합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '관리자 화면에 확인 시각이 표시됩니다.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '설정 확인',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

// ── iOS passive 모드 안내 ────────────────────────────────────
class _IosPassiveNote extends StatelessWidget {
  const _IosPassiveNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'iPhone에서는 백그라운드 폰 사용 감지가 시스템에 의해 제한될 수 있습니다. '
              '안정적인 자동 신호 전송을 위해 "앱을 열 때 자동" 모드를 권장합니다.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 체크인 방식 표시 카드 (읽기 전용, 관리자가 설정) ─────────
class _CheckinModeCard extends StatelessWidget {
  final CheckinMode current;

  const _CheckinModeCard({required this.current});

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
    final item = _modes.firstWhere((m) => m.mode == current);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
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
            Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}

// ── 체크인 주기 선택 카드 ───────────────────────────────────
class _IntervalCard extends StatelessWidget {
  final int current;
  const _IntervalCard({required this.current});

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
            label: '12시간',
            desc: '하루 2회',
            selected: current == 12,
            isFirst: true,
          ),
          Container(width: 1, height: 72, color: AppTheme.appInfoSep),
          _IntervalOption(
            label: '24시간',
            desc: '하루 1회',
            selected: current == 24,
            isFirst: false,
          ),
        ],
      ),
    );
  }
}

class _IntervalOption extends StatelessWidget {
  final String label;
  final String desc;
  final bool selected;
  final bool isFirst;

  const _IntervalOption({
    required this.label,
    required this.desc,
    required this.selected,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? AppTheme.primary : AppTheme.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
