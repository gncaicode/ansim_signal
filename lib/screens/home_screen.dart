import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart'; // CheckinStatus, CheckinMode
import '../providers/checkin_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ansim_mascot.dart';
import '../widgets/status_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;

  // Glow ring
  late AnimationController _glowCtrl;
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  // Ripple ring
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  // Checkmark pop
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkRotate;

  bool _isPressed = false;
  bool _isChecked = false;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    // 최초 진입(콜드 스타트) 시에도 서버 동기화 + appOpen 자동 체크인
    WidgetsBinding.instance.addPostFrameCallback((_) => _onResume());

    // Glow ring breathe
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.30, end: 0.55).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Ripple ring expand
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _rippleScale = Tween<double>(begin: 0.85, end: 1.4).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    // Checkmark pop
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.4, end: 1.15)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 65),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
    ]).animate(_checkCtrl);
    _checkRotate = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: -10 * pi / 180, end: 3 * pi / 180)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 65),
      TweenSequenceItem(
          tween: Tween<double>(begin: 3 * pi / 180, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
    ]).animate(_checkCtrl);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _glowCtrl.dispose();
    _rippleCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _syncData() async {
    if (!mounted) return;
    final provider = context.read<CheckinProvider>();
    await provider.syncFromPrefs();
    await provider.syncFromServer();
  }


  Future<void> _onResume() async {
    if (!mounted) return;
    setState(() => _isChecked = false);
    await _syncData();

    // appOpen 모드: 앱 포그라운드 진입 시 자동 체크인
    final provider = context.read<CheckinProvider>();
    if (provider.checkinMode == CheckinMode.appOpen) {
      await provider.autoCheckIn();
      if (mounted) setState(() => _isChecked = true);
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) setState(() => _isChecked = false);
    }
  }

  Future<void> _handleCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    HapticFeedback.mediumImpact();

    final provider = context.read<CheckinProvider>();
    await provider.checkIn();
    await NotificationService.showCheckInSuccessNotification();

    if (!mounted) return;
    setState(() {
      _isChecked = true;
      _isCheckingIn = false;
    });
    _checkCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _isChecked = false);
  }

  Future<void> _callCareWorker(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) {
      if (mounted) setState(() => _isChecked = false);
    });
  }

  void _showCareWorkersSheet(List<CareWorker> workers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CareWorkersBottomSheet(
        workers: workers,
        onCall: _callCareWorker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckinProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const AnsimMascot(size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text('안심시그널'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 24,
                  color: AppTheme.primary,
                ),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── 상태 카드 ───────────────────────────────
                StatusCard(
                  status: provider.status,
                  lastCheckIn: provider.lastCheckIn,
                  timeRemaining: provider.timeRemaining,
                  progress: provider.progress,
                  intervalHours: provider.intervalHours,
                ),

                // ── 위급 배너 ────────────────────────────────
                if (provider.status == CheckinStatus.overdue && provider.alertSent)
                  _OverdueBanner(
                    workerName: provider.careWorker?.name ?? '담당 복지사',
                  ),

                const Spacer(),

                // ── 메인 안부 신호 버튼 ─────────────────────
                _CheckinButton(
                  isChecked: _isChecked,
                  isPressed: _isPressed,
                  glowScale: _glowScale,
                  glowOpacity: _glowOpacity,
                  rippleScale: _rippleScale,
                  rippleOpacity: _rippleOpacity,
                  checkScale: _checkScale,
                  checkRotate: _checkRotate,
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapUp: (_) {
                    setState(() => _isPressed = false);
                    _handleCheckIn();
                  },
                  onTapCancel: () => setState(() => _isPressed = false),
                ),

                const Spacer(),

                // ── 담당 복지사 정보 필 ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: provider.careWorkers.length >= 2
                      ? _CareWorkerSummaryPill(
                          workers: provider.careWorkers,
                          onTap: () =>
                              _showCareWorkersSheet(provider.careWorkers),
                        )
                      : provider.careWorkers.isEmpty
                          ? _CareWorkerPill(
                              careWorker: null,
                              onCall: null,
                              onTap: _openSettings,
                            )
                          : _CareWorkerPill(
                              careWorker: provider.careWorkers.first,
                              onCall: provider.careWorkers.first.phone.isNotEmpty
                                  ? () => _callCareWorker(
                                      provider.careWorkers.first.phone)
                                  : null,
                              onTap: _openSettings,
                            ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// 안부 신호 버튼 (어르신 친화 — 200×200px)
// ────────────────────────────────────────────────────────────
class _CheckinButton extends StatelessWidget {
  final bool isChecked;
  final bool isPressed;
  final Animation<double> glowScale;
  final Animation<double> glowOpacity;
  final Animation<double> rippleScale;
  final Animation<double> rippleOpacity;
  final Animation<double> checkScale;
  final Animation<double> checkRotate;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onTapCancel;

  const _CheckinButton({
    required this.isChecked,
    required this.isPressed,
    required this.glowScale,
    required this.glowOpacity,
    required this.rippleScale,
    required this.rippleOpacity,
    required this.checkScale,
    required this.checkRotate,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        scale: isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              AnimatedOpacity(
                opacity: isChecked ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedBuilder(
                  animation: Listenable.merge([glowScale, glowOpacity]),
                  builder: (context, child) => Opacity(
                    opacity: glowOpacity.value,
                    child: Transform.scale(
                      scale: glowScale.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x201E3A8A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Ripple ring
              AnimatedOpacity(
                opacity: isChecked ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedBuilder(
                  animation: Listenable.merge([rippleScale, rippleOpacity]),
                  builder: (context, child) => Opacity(
                    opacity: rippleOpacity.value,
                    child: Transform.scale(
                      scale: rippleScale.value,
                      child: Container(
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryLight,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Main button (200×200) — navy gradient
              Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x401E3A8A),
                      blurRadius: 32,
                      offset: Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: isChecked
                      ? _CheckedContent(
                          key: const ValueKey('checked'),
                          scaleAnim: checkScale,
                          rotateAnim: checkRotate,
                        )
                      : const _UncheckedContent(key: ValueKey('unchecked')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UncheckedContent extends StatelessWidget {
  const _UncheckedContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnsimMascot(size: 80, color: Colors.white),
        SizedBox(height: 10),
        Text(
          '나 괜찮아요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _CheckedContent extends StatelessWidget {
  final Animation<double> scaleAnim;
  final Animation<double> rotateAnim;
  const _CheckedContent(
      {super.key, required this.scaleAnim, required this.rotateAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scaleAnim, rotateAnim]),
      builder: (context, child) => Transform.rotate(
        angle: rotateAnim.value,
        child: Transform.scale(
          scale: scaleAnim.value,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CheckmarkIcon(size: 72),
              SizedBox(height: 10),
              Text(
                '전송 완료!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckmarkIcon extends StatelessWidget {
  final double size;
  const _CheckmarkIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CheckmarkPainter()),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.42,
      paint,
    );

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.50)
      ..lineTo(size.width * 0.44, size.height * 0.65)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// 위급 배너
// ────────────────────────────────────────────────────────────
class _OverdueBanner extends StatelessWidget {
  final String workerName;

  const _OverdueBanner({required this.workerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 22, color: AppTheme.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$workerName님께 알림을 발송했습니다.',
              style: const TextStyle(
                color: AppTheme.dangerFg,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 담당 복지사 정보 필
// ────────────────────────────────────────────────────────────
class _CareWorkerPill extends StatelessWidget {
  final dynamic careWorker;
  final VoidCallback? onCall;
  final VoidCallback onTap;

  const _CareWorkerPill({
    required this.careWorker,
    required this.onCall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasWorker = careWorker != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: AppTheme.surfaceMuted, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.glowColor,
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: hasWorker
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '담당: ${careWorker.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (careWorker.phone.isNotEmpty)
                          Text(
                            careWorker.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSubtle,
                            ),
                          ),
                      ],
                    )
                  : const Text(
                      '담당 복지사 정보가 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMedium,
                      ),
                    ),
            ),
            if (hasWorker && onCall != null)
              GestureDetector(
                onTap: onCall,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 18, color: Colors.white),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppTheme.textSubtle,
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 담당 복지사 요약 필 (2명 이상)
// ────────────────────────────────────────────────────────────
class _CareWorkerSummaryPill extends StatelessWidget {
  final List<CareWorker> workers;
  final VoidCallback onTap;

  const _CareWorkerSummaryPill({
    required this.workers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: AppTheme.surfaceMuted, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.glowColor,
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '담당 복지사 ${workers.length}명',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded,
                size: 20, color: AppTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 담당 복지사 목록 바텀 시트
// ────────────────────────────────────────────────────────────
class _CareWorkersBottomSheet extends StatelessWidget {
  final List<CareWorker> workers;
  final void Function(String phone) onCall;

  const _CareWorkersBottomSheet({
    required this.workers,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '담당 복지사',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...workers.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CareWorkerPill(
                  careWorker: w,
                  onCall: w.phone.isNotEmpty ? () => onCall(w.phone) : null,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
