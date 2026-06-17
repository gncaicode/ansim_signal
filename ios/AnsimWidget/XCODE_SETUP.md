# iOS AnsimWidget Xcode 설정 가이드

## 1. Widget Extension 타겟 추가

1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. `File > New > Target...` 선택
3. **Widget Extension** 선택 → Next
4. Product Name: `AnsimWidget`
5. Bundle Identifier: `com.gncaitech.ansim_signal.AnsimWidget`
6. **Include Configuration Intent: 체크 해제**
7. Finish → "Activate scheme?" → Cancel

## 2. Swift 파일 교체

Xcode가 자동 생성한 파일 삭제 후 이 폴더의 파일로 교체:
- `AnsimWidget.swift` → 기존 파일과 교체
- `AnsimWidgetBundle.swift` → 기존 파일과 교체

## 3. App Groups 설정

**Runner 타겟:**
1. Runner 타겟 선택 → Signing & Capabilities
2. `+ Capability` → App Groups
3. `group.com.gncaitech.ansim_signal` 추가

**AnsimWidget 타겟:**
1. AnsimWidget 타겟 선택 → Signing & Capabilities
2. `+ Capability` → App Groups
3. `group.com.gncaitech.ansim_signal` 추가

## 4. Runner Entitlements 확인

`ios/Runner/Runner.entitlements`에 아래 항목이 있는지 확인:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.gncaitech.ansim_signal</string>
</array>
```

## 5. Build Settings

AnsimWidget 타겟 → Build Settings:
- `SWIFT_VERSION`: 5.0
- `IPHONEOS_DEPLOYMENT_TARGET`: 16.0 이상

## 6. home_widget 패키지 Swift 파일 포함

`Podfile`에 아래 추가 (이미 있으면 생략):
```ruby
target 'AnsimWidget' do
  use_frameworks!
  pod 'home_widget', :path => '../.pub-cache/hosted/pub.dev/home_widget-0.6.0/ios'
end
```

또는 간단히 UserDefaults suiteName으로 직접 읽으므로 별도 의존성 불필요.
