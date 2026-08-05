import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/checkin_provider.dart';
import '../services/version_check_service.dart';
import '../widgets/ansim_mascot.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // 스플래시 대기/온보딩 상태 로딩과 병렬로 진행해 전체 대기 시간을 늘리지 않는다.
    final versionCheck = VersionCheckService.checkForcedUpdateStoreUrl();

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final provider = context.read<CheckinProvider>();
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (provider.isLoading) {
      if (DateTime.now().isAfter(deadline)) break;
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    final storeUrl = await versionCheck;
    if (!mounted) return;

    if (storeUrl != null) {
      _showForceUpdateDialog(storeUrl);
      return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            provider.isOnboarded
                ? const HomeScreen()
                : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// 강제 업데이트 안내 — 닫을 수 없고, 확인을 누르면 스토어로 이동한다.
  void _showForceUpdateDialog(String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('업데이트가 필요해요'),
          content: const Text(
            '새 버전이 있어야 계속 사용할 수 있어요.\n지금 업데이트해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF1E3A8A), Color(0xFF172554)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnsimMascot(size: 100, color: Colors.white, showBadge: true),
              SizedBox(height: 20),
              Text(
                '안심시그널',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '매일 안부 신호를 보내주세요',
                style: TextStyle(
                  color: Color(0xBFFFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
