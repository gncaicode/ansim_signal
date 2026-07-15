import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'http://ansim.gncaitech.com/api';

  static const _timeout = Duration(seconds: 10);

  static Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// 초대코드로 신규 등록 → 서버 토큰 반환
  /// 서버 응답에 care_worker 정보가 포함될 수 있음
  static Future<Map<String, dynamic>> register(
    String inviteCode, {
    String lang = 'ko',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: _headers(),
          body: jsonEncode({
            'invite_code': inviteCode,
            'lang': lang,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final token = body['token'];
      if (token == null || token is! String || token.isEmpty) {
        throw Exception('register: invalid token in response');
      }
      return body; // { token, user: { name }, care_worker: { name, phone, organization } }
    }
    throw Exception('register failed: ${res.statusCode}');
  }

  /// 안부 신호 전송 → { message, checked_at }
  static Future<Map<String, dynamic>> checkIn(String token) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/checkin'),
          headers: _headers(token),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('checkIn failed: ${res.statusCode}');
  }

  /// 안부 신호 상태 조회
  static Future<Map<String, dynamic>> getStatus(String token) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/checkin/status'),
          headers: _headers(token),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('getStatus failed: ${res.statusCode}');
  }

  /// 연결 확인 — 실제 체크인과 무관한 테스트 신호 (last_checkin_at에 영향 없음)
  static Future<void> testConnection(String token) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/checkin/test-connection'),
          headers: _headers(token),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('testConnection failed: ${res.statusCode}');
    }
  }

  /// 회원 탈퇴
  static Future<void> withdraw(String token) async {
    final res = await http
        .delete(
          Uri.parse('$baseUrl/auth/withdraw'),
          headers: _headers(token),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('withdraw failed: ${res.statusCode}');
    }
  }
}
