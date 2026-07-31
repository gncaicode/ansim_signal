import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'package:workmanager/workmanager.dart';
import 'providers/checkin_provider.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';

/// 앱 전역 Navigator — 딥링크 수신 시 현재 화면과 무관하게 라우팅하기 위해 사용.
final navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'ansim-widget-checkin') {
        return await BackgroundService.widgetCheckIn();
      }
      return await BackgroundService.performCheckIn();
    } catch (e) {
      debugPrint('[Background] task failed: $e');
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await NotificationService.initialize();
  await WidgetService.initialize();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  if (Platform.isAndroid) {
    // Android: 주기적 백그라운드 체크 (최소 15분 간격, OS가 1시간으로 조정)
    await Workmanager().registerPeriodicTask(
      'ansim-signal-check',
      'checkInTask',
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  } else if (Platform.isIOS) {
    // iOS: BGProcessingTask — 등록만 하고 시스템이 적절한 시점에 실행
    await Workmanager().registerOneOffTask(
      'ansim-signal-check',
      'checkInTask',
      initialDelay: const Duration(hours: 1),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => CheckinProvider()..initialize(),
      child: const AnsimSignalApp(),
    ),
  );
}

class AnsimSignalApp extends StatefulWidget {
  const AnsimSignalApp({super.key});

  @override
  State<AnsimSignalApp> createState() => _AnsimSignalAppState();
}

class _AnsimSignalAppState extends State<AnsimSignalApp>
    with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.widgetClicked.listen(_onWidgetClicked);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetClicked);
    _initDeepLinks();
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'checkin') {
      final provider = context.read<CheckinProvider>();
      if (provider.isOnboarded) provider.checkIn();
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleInviteLink(initialUri);
    } catch (e) {
      debugPrint('[DeepLink] initial link 처리 실패: $e');
    }
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleInviteLink,
      onError: (e) => debugPrint('[DeepLink] 수신 실패: $e'),
    );
  }

  /// https://www.edcsystem.kr/ansimsignal_open/?code=XXXXXXXX 형태의
  /// 초대코드 딥링크 처리. 코드는 온보딩 화면에 채우기만 하고 자동 제출은 하지 않는다.
  Future<void> _handleInviteLink(Uri uri) async {
    if (!uri.path.contains('ansimsignal_open')) return;

    final code = uri.queryParameters['code']?.trim().toUpperCase();
    if (code == null || code.length != 8) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final provider = ctx.read<CheckinProvider>();

    // CheckinProvider.initialize()가 SharedPreferences를 아직 다 읽기 전이면
    // isOnboarded가 기본값(false)일 수 있으므로, 스플래시 화면과 동일하게 로딩 완료를 기다린다.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (provider.isLoading) {
      if (DateTime.now().isAfter(deadline)) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!ctx.mounted) return;

    if (provider.isOnboarded) {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('이미 등록되어 있어요'),
          content: const Text('이 기기는 이미 안심시그널에 등록되어 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(initialInviteCode: code),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '안심시그널',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
