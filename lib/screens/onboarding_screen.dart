import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/checkin_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ansim_mascot.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isProcessing = false;

  // Page 1 – 초대코드
  final _inviteCodeCtrl = TextEditingController();
  final _inviteFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.ease,
    );
  }

  Future<void> _complete() async {
    if (!_inviteFormKey.currentState!.validate()) return;
    if (_isProcessing) return;

    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);

    final provider = context.read<CheckinProvider>();
    final inviteCode = _inviteCodeCtrl.text.trim().toUpperCase();

    await NotificationService.requestPermissions();
    final success = await provider.completeOnboarding(inviteCode);

    if (!mounted) return;
    if (!success) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('초대코드가 올바르지 않거나 서버 연결에 실패했습니다.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── 진행 도트 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Dot(active: _currentPage == 0),
                  const SizedBox(width: 6),
                  _Dot(active: _currentPage == 1),
                ],
              ),
            ),

            // ── 페이지 ────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _next),
                  _InviteCodePage(
                    formKey: _inviteFormKey,
                    codeCtrl: _inviteCodeCtrl,
                    onComplete: _complete,
                    isProcessing: _isProcessing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 진행 도트 ───────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 22 : 8,
      height: 5,
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ── 공통 primary 버튼 ────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

// ── 공통 입력 데코레이션 ──────────────────────────────────────
InputDecoration _inputDecor({
  required String label,
  required IconData icon,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textSubtle),
    prefixIcon: Icon(icon, color: AppTheme.textMedium, size: 20),
    filled: true,
    fillColor: AppTheme.background,
  );
}

// ────────────────────────────────────────────────────────────
// 페이지 0: 서비스 소개
// ────────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnsimMascot(size: 88, color: AppTheme.primaryLight),
          const SizedBox(height: 24),
          const Text(
            '안심시그널',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '매일 버튼 한 번으로\n담당자에게 안부를 전합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textMedium,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 40),

          // 기능 설명
          ...[
            ('🟢', '매일 안부 신호', '버튼 한 번으로 오늘 건강함을 알립니다'),
            ('🔔', '자동 알림', '미확인 시 담당 복지사에게 즉시 알림 전송'),
            ('🔒', '개인정보 최소화', '이름과 연락처만 사용, 위치 추적 없음'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(item.$1, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSubtle,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(label: '시작하기', onPressed: onNext),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 페이지 1: 초대코드 입력
// ────────────────────────────────────────────────────────────
class _InviteCodePage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController codeCtrl;
  final VoidCallback onComplete;
  final bool isProcessing;

  const _InviteCodePage({
    required this.formKey,
    required this.codeCtrl,
    required this.onComplete,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(Icons.key_rounded, size: 28, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '초대코드를\n입력해 주세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                  letterSpacing: -0.8,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '담당 공무원 또는 복지사에게\n받은 6자리 코드를 입력하세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 36),

              // 초대코드 입력 (6자리, 대문자)
              TextFormField(
                controller: codeCtrl,
                decoration: _inputDecor(
                  label: '초대코드',
                  icon: Icons.key_rounded,
                  hint: 'A1B2C3',
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '초대코드를 입력해 주세요';
                  if (v.trim().length != 6) return '6자리 코드를 입력해 주세요';
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onComplete(),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '초대코드는 담당 공무원·복지사가 발급합니다.\n코드가 없으시면 담당자에게 문의해 주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _PrimaryButton(
                label: '등록하기',
                onPressed: isProcessing ? null : onComplete,
                loading: isProcessing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
