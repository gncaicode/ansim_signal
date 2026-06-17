import 'dart:io';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.widgetClicked.listen(_onWidgetClicked);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetClicked);
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'checkin') {
      final provider = context.read<CheckinProvider>();
      if (provider.isOnboarded) provider.checkIn();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '안심시그널',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
