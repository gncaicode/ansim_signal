/// 담당 복지사 / 공무원 정보 (서버에서 초대코드로 자동 설정, 읽기 전용)
class CareWorker {
  final String name;
  final String phone;
  final String organization;

  const CareWorker({
    required this.name,
    required this.phone,
    required this.organization,
  });

  factory CareWorker.fromJson(Map<String, dynamic> json) => CareWorker(
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        organization: json['organization']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'organization': organization,
      };
}

enum CheckinStatus { safe, warning, overdue, unknown }

enum CheckinMode {
  manual,   // 버튼을 직접 누를 때
  appOpen,  // 앱을 열 때 자동
  passive,  // 폰 사용 시 자동 (백그라운드 감지)
}
