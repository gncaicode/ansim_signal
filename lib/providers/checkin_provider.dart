import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/prefs_keys.dart';
import '../utils/app_config.dart';
import '../services/widget_service.dart';

class CheckinProvider extends ChangeNotifier {
  static const _kServerToken = 'server_token';

  final _secure = const FlutterSecureStorage();

  DateTime? _lastCheckIn;
  List<CareWorker> _careWorkers = [];
  bool _isOnboarded = false;
  int _intervalHours = 24; // 안심시그널 기본값: 24시간
  bool _alertSent = false;
  String _userName = '';
  bool _isLoading = true;
  String? _serverToken;
  CheckinMode _checkinMode = CheckinMode.manual;

  // Getters
  DateTime? get lastCheckIn => _lastCheckIn;
  List<CareWorker> get careWorkers => _careWorkers;
  CareWorker? get careWorker => _careWorkers.isNotEmpty ? _careWorkers.first : null;
  bool get isOnboarded => _isOnboarded;
  int get intervalHours => _intervalHours;
  bool get alertSent => _alertSent;
  String get userName => _userName;
  bool get isLoading => _isLoading;
  String? get serverToken => _serverToken;
  CheckinMode get checkinMode => _checkinMode;

  Duration get interval => Duration(hours: _intervalHours);

  /// 마감까지 남은 시간 (음수면 초과)
  Duration get timeRemaining {
    if (_lastCheckIn == null) return Duration.zero;
    final deadline = _lastCheckIn!.add(interval);
    return deadline.difference(DateTime.now());
  }

  /// 0.0 ~ 1.0 진행도
  double get progress {
    if (_lastCheckIn == null) return 0.0;
    final elapsed = DateTime.now().difference(_lastCheckIn!);
    return (elapsed.inSeconds / interval.inSeconds).clamp(0.0, 1.0);
  }

  CheckinStatus get status {
    if (_lastCheckIn == null) return CheckinStatus.unknown;
    final remaining = timeRemaining;
    if (remaining.isNegative) return CheckinStatus.overdue;
    // 안심시그널: 24시간 기준 → 남은 시간 8시간 이하면 주의
    if (remaining.inHours < _intervalHours / 3) return CheckinStatus.warning;
    return CheckinStatus.safe;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _serverToken = await _secure.read(key: _kServerToken);
    _isOnboarded = prefs.getBool(PrefsKeys.isOnboarded) ?? false;

    // iOS 재설치 복구
    if (!_isOnboarded && _serverToken != null) {
      final recovered = await _tryRecoverSession(prefs);
      if (recovered) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      await _secure.delete(key: _kServerToken);
      _serverToken = null;
    }

    _intervalHours = prefs.getInt(PrefsKeys.intervalHours) ?? 24;
    _alertSent = prefs.getBool(PrefsKeys.alertSent) ?? false;
    _userName = prefs.getString(PrefsKeys.userName) ?? '';
    _checkinMode = _modeFromString(prefs.getString(PrefsKeys.checkinMode));

    final ms = prefs.getInt(PrefsKeys.lastCheckIn);
    if (ms != null) _lastCheckIn = DateTime.fromMillisecondsSinceEpoch(ms);

    _careWorkers = _loadCareWorkersFromPrefs(prefs);

    _isLoading = false;
    notifyListeners();

    // iOS 위젯용 토큰을 App Group UserDefaults에 저장
    if (_serverToken != null) {
      await WidgetService.saveToken(_serverToken!);
    }

    await WidgetService.update(
      status: status,
      lastCheckIn: _lastCheckIn,
      timeRemaining: timeRemaining,
      intervalHours: _intervalHours,
    );

    await syncFromServer();
  }

  Future<bool> _tryRecoverSession(SharedPreferences prefs) async {
    try {
      final data = await ApiService.getStatus(_serverToken!);
      if (data['status'] == null || data['status'] == 'error') return false;

      _isOnboarded = true;
      await prefs.setBool(PrefsKeys.isOnboarded, true);

      final serverInterval = _parseInt(data['interval_hours']);
      _intervalHours = serverInterval ?? 24;
      await prefs.setInt(PrefsKeys.intervalHours, _intervalHours);

      final serverCheckinStr = data['last_checkin_at']?.toString();
      if (serverCheckinStr != null) {
        _lastCheckIn = DateTime.parse(serverCheckinStr).toLocal();
        await prefs.setInt(PrefsKeys.lastCheckIn, _lastCheckIn!.millisecondsSinceEpoch);
      }

      _alertSent = _parseBool(data['alert_sent']);
      await prefs.setBool(PrefsKeys.alertSent, _alertSent);

      final serverName = data['user_name']?.toString();
      if (serverName != null && serverName.isNotEmpty) {
        _userName = serverName;
        await prefs.setString(PrefsKeys.userName, serverName);
      }

      await _saveCareWorkersFromData(prefs, data['care_workers']);

      debugPrint('[Provider] 재설치 세션 복구 완료 (iOS Keychain)');
      await WidgetService.saveToken(_serverToken!);
      await WidgetService.update(
        status: status,
        lastCheckIn: _lastCheckIn,
        timeRemaining: timeRemaining,
        intervalHours: _intervalHours,
      );
      return true;
    } catch (e) {
      debugPrint('[Provider] 세션 복구 실패: $e');
      return false;
    }
  }

  Future<void> checkIn() async {
    // 낙관적 업데이트 — 서버 응답 전 즉시 UI 반영
    final prefs = await SharedPreferences.getInstance();
    _lastCheckIn = DateTime.now();
    _alertSent = false;
    await prefs.setInt(PrefsKeys.lastCheckIn, _lastCheckIn!.millisecondsSinceEpoch);
    await prefs.setBool(PrefsKeys.alertSent, false);
    notifyListeners();

    NotificationService.scheduleExpirationReminder(
      lastCheckIn: _lastCheckIn!,
      intervalHours: _intervalHours,
    );

    if (_serverToken != null) {
      try {
        final res = await ApiService.checkIn(_serverToken!);
        // 서버 응답의 checked_at으로 정확한 시간 동기화
        final checkedAt = res['checked_at']?.toString();
        if (checkedAt != null) {
          final serverTime = DateTime.parse(checkedAt).toLocal();
          _lastCheckIn = serverTime;
          await prefs.setInt(PrefsKeys.lastCheckIn, serverTime.millisecondsSinceEpoch);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[API] checkIn failed: $e');
      }
    }

    await WidgetService.update(
      status: status,
      lastCheckIn: _lastCheckIn,
      timeRemaining: timeRemaining,
      intervalHours: _intervalHours,
    );
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    await prefs.setString(PrefsKeys.userName, name);
    notifyListeners();
  }

  /// 온보딩 완료. 초대코드로 서버 등록 후 담당자 정보 수신.
  /// 성공 시 true, 실패 시 false 반환.
  Future<bool> completeOnboarding(String inviteCode) async {
    try {
      final result = await ApiService.register(
        inviteCode,
        lang: AppConfig.lang,
      );

      final token = result['token'] as String;
      _serverToken = token;
      await _secure.write(key: _kServerToken, value: token);
      await WidgetService.saveToken(token);

      // 서버에서 이름 수신
      final prefs = await SharedPreferences.getInstance();
      final serverName = (result['user'] as Map<String, dynamic>?)?['name']?.toString();
      if (serverName != null && serverName.isNotEmpty) {
        _userName = serverName;
        await prefs.setString(PrefsKeys.userName, serverName);
      }

      // 담당자 정보 저장
      await _saveCareWorkersFromData(prefs, result['care_workers']);
    } catch (e) {
      debugPrint('[API] onboarding register failed: $e');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = true;
    await prefs.setBool(PrefsKeys.isOnboarded, true);
    notifyListeners();

    await checkIn();
    return true;
  }

  /// 앱 포그라운드 복귀 시 SharedPreferences 동기화
  Future<void> syncFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ms = prefs.getInt(PrefsKeys.lastCheckIn);
    if (ms != null) {
      final fromPrefs = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_lastCheckIn == null || fromPrefs.isAfter(_lastCheckIn!)) {
        _lastCheckIn = fromPrefs;
        _alertSent = prefs.getBool(PrefsKeys.alertSent) ?? false;
        notifyListeners();
      }
    }
  }

  /// 서버 상태로 로컬 동기화
  Future<void> syncFromServer() async {
    if (_serverToken == null) return;
    try {
      final data = await ApiService.getStatus(_serverToken!);
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      // interval_hours — 사용자가 직접 설정한 경우 서버 값 무시
      final userSetInterval = prefs.getBool(PrefsKeys.intervalSetByUser) ?? false;
      if (!userSetInterval) {
        final serverInterval = _parseInt(data['interval_hours']);
        if (serverInterval != null && serverInterval != _intervalHours) {
          _intervalHours = serverInterval;
          await prefs.setInt(PrefsKeys.intervalHours, serverInterval);
          changed = true;
        }
      }

      // care_workers — 서버에 등록된 담당자 정보 갱신
      final cwData = data['care_workers'];
      if (cwData != null) {
        await _saveCareWorkersFromData(prefs, cwData);
        changed = true;
      }

      // status == 'unknown' 이면 체크인 이력 없음, 이하 skip
      if (data['status'] == 'unknown') {
        if (changed) notifyListeners();
        return;
      }

      // last_checkin_at — 서버가 더 최신이면 업데이트
      final serverCheckinStr = data['last_checkin_at']?.toString();
      if (serverCheckinStr != null) {
        final serverCheckin = DateTime.parse(serverCheckinStr).toLocal();
        if (_lastCheckIn == null || serverCheckin.isAfter(_lastCheckIn!)) {
          _lastCheckIn = serverCheckin;
          await prefs.setInt(PrefsKeys.lastCheckIn, serverCheckin.millisecondsSinceEpoch);
          changed = true;
        }
      }

      // alert_sent
      final serverAlertSent = _parseBool(data['alert_sent']);
      if (serverAlertSent && !_alertSent) {
        _alertSent = true;
        await prefs.setBool(PrefsKeys.alertSent, true);
        changed = true;
      }

      if (changed) notifyListeners();
      await WidgetService.update(
        status: status,
        lastCheckIn: _lastCheckIn,
        timeRemaining: timeRemaining,
        intervalHours: _intervalHours,
      );
    } catch (e) {
      debugPrint('[API] syncFromServer failed: $e');
    }
  }

  /// care_worker 필드: 단일 객체 또는 배열 모두 처리
  Future<void> _saveCareWorkersFromData(
      SharedPreferences prefs, dynamic careWorkerData) async {
    if (careWorkerData == null) return;

    List<CareWorker> workers;
    if (careWorkerData is List) {
      workers = careWorkerData
          .whereType<Map<String, dynamic>>()
          .map(CareWorker.fromJson)
          .where((w) => w.name.isNotEmpty)
          .toList();
    } else if (careWorkerData is Map<String, dynamic>) {
      final w = CareWorker.fromJson(careWorkerData);
      workers = w.name.isNotEmpty ? [w] : [];
    } else {
      return;
    }

    if (workers.isEmpty) return;
    _careWorkers = workers;
    await prefs.setString(
      PrefsKeys.careWorkers,
      jsonEncode(workers.map((w) => w.toJson()).toList()),
    );
    notifyListeners();
  }

  /// SharedPreferences에서 담당자 목록 로드 (신규 키 → 레거시 키 순서로 시도)
  List<CareWorker> _loadCareWorkersFromPrefs(SharedPreferences prefs) {
    final json = prefs.getString(PrefsKeys.careWorkers);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(CareWorker.fromJson)
            .where((w) => w.name.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    // 레거시 단일 키 마이그레이션
    final name = prefs.getString(PrefsKeys.careWorkerName);
    final phone = prefs.getString(PrefsKeys.careWorkerPhone) ?? '';
    final org = prefs.getString(PrefsKeys.careWorkerOrg) ?? '';
    if (name != null && name.isNotEmpty) {
      return [CareWorker(name: name, phone: phone, organization: org)];
    }
    return [];
  }

  /// 체크인 모드 변경
  Future<void> setCheckinMode(CheckinMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    _checkinMode = mode;
    await prefs.setString(PrefsKeys.checkinMode, mode.name);
    notifyListeners();
  }

  /// 체크인 주기 변경 (12 or 24시간)
  Future<void> setIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    _intervalHours = hours;
    await prefs.setInt(PrefsKeys.intervalHours, hours);
    await prefs.setBool(PrefsKeys.intervalSetByUser, true);
    notifyListeners();

    if (_serverToken != null) {
      try {
        await ApiService.updateSettings(_serverToken!, hours);
      } catch (e) {
        debugPrint('[API] updateSettings failed: $e');
      }
    }
  }

  /// 앱 열 때 / 폰 사용 시 자동 체크인 (다음 마감 전까지 중복 방지)
  Future<void> autoCheckIn() async {
    if (_serverToken == null) return;
    if (_lastCheckIn != null && !timeRemaining.isNegative) return;
    await checkIn();
  }

  static CheckinMode _modeFromString(String? value) => switch (value) {
        'appOpen' => CheckinMode.appOpen,
        'passive' => CheckinMode.passive,
        _ => CheckinMode.manual,
      };

  Future<void> markAlertSent() async {
    final prefs = await SharedPreferences.getInstance();
    _alertSent = true;
    await prefs.setBool(PrefsKeys.alertSent, true);
    notifyListeners();
  }

  /// [테스트용] 마지막 체크인 시간을 지정한 시간 전으로 설정
  Future<void> setLastCheckInHoursAgo(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    _lastCheckIn = DateTime.now().subtract(Duration(hours: hours));
    _alertSent = false;
    await prefs.setInt(PrefsKeys.lastCheckIn, _lastCheckIn!.millisecondsSinceEpoch);
    await prefs.setBool(PrefsKeys.alertSent, false);
    notifyListeners();
    await WidgetService.update(
      status: status,
      lastCheckIn: _lastCheckIn,
      timeRemaining: timeRemaining,
      intervalHours: _intervalHours,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secure.deleteAll();
    _isOnboarded = false;
    _lastCheckIn = null;
    _careWorkers = [];
    _intervalHours = 24;
    _alertSent = false;
    _userName = '';
    _serverToken = null;
    notifyListeners();
  }
}
