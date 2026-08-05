import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_service.dart';

class VersionCheckService {
  VersionCheckService._();

  /// 강제 업데이트가 필요하면 이동할 스토어 URL을, 필요 없거나
  /// 서버 확인에 실패하면 null을 반환한다. 네트워크 오류 등으로 확인이
  /// 안 되는 경우 앱 사용을 막지 않기 위해 항상 null(업데이트 불필요)로
  /// 처리한다(fail open).
  static Future<String?> checkForcedUpdateStoreUrl() async {
    try {
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : null;
      if (platform == null) return null;

      final data = await ApiService.getAppVersion(platform);
      final minVersion = data['min_version']?.toString();
      final storeUrl = data['store_url']?.toString();
      if (minVersion == null || storeUrl == null || storeUrl.isEmpty) {
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isLower(currentVersion, minVersion)) {
        return storeUrl;
      }
      return null;
    } catch (e) {
      debugPrint('[VersionCheck] 확인 실패, 업데이트 체크 건너뜀: $e');
      return null;
    }
  }

  /// current < min 이면 true. "1.0.3" 같은 점(.) 구분 숫자 버전을 비교한다.
  static bool _isLower(String current, String min) {
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final m = min.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = c.length > m.length ? c.length : m.length;

    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv != mv) return cv < mv;
    }
    return false;
  }
}
