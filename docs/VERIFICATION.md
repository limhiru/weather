# 구현 검증 기록

2026-10-05, macOS 15.8.1 (Intel), Flutter 3.44.1 / Dart 3.12.1, Xcode 16.0.

| 검증 | 결과 |
|---|---|
| Python 기상청 어댑터 및 HTTP 테스트 | 11개 통과 |
| 실제 기상청 API | 서울·부산 초단기실황과 단기예보 수신 성공; 로컬 HTTP 서버 응답도 확인 |
| macOS 로컬 서비스 | LaunchAgent 실행, `/health`와 서울 실황·24시간 예보 응답 확인 |
| Git 버전/태그 회귀 테스트 | 초기 1.0.0 → 두 번째 1.0.1 및 미스테이징 방지 통과 |
| Flutter 정적 분석 | 문제 없음 |
| Flutter 테스트 | 5개 통과: KST, 서버 URL 검증, 미리보기 구분, 도시 선택, 작은 화면 배치 |
| Android debug APK | 빌드 성공 |
| SwiftUI iOS Simulator 앱 | Xcode build 성공 |
| GitHub Actions | v1.0.0·v1.0.1 서버·Android·iOS 검사 모두 성공 |
| Swift 모델 별도 실행 | URL 검증, KST 자정 전환, 예시 구분, Codable 직렬화 통과 |
| Flutter 화면 렌더링 | docs/android-preview.png로 캡처 후 시각 확인 |

## 검증 범위

- 제공된 인증키는 Git에 무시되는 로컬 `server/.env`에만 저장하고, 실제 기상청 서울·부산 관측/예보 응답을 확인했습니다. 인증키 없는 서버가 503 안내를 반환하는 동작도 검증했습니다.
- 로컬 iOS Simulator 서비스 응답이 지연되어 XCTest를 로컬에서는 완료하지 못했습니다. GitHub Actions의 iOS Simulator XCTest는 통과했습니다.
- 로컬 Xcode 16은 iOS 26 SDK를 포함하지 않으므로 네이티브 Liquid Glass 분기는 로컬에서 실행하지 않았습니다. 기존 iOS의 반투명 머티리얼 분기를 빌드했습니다.
- Android 에뮬레이터의 ADB 인증이 완료되지 않아 실제 에뮬레이터 탭 검증 대신 Flutter 위젯 테스트와 렌더링으로 도시 선택·미리보기·작은 화면을 검증했습니다.
- 실기기 GPS 권한, 장시간 GPU/배터리, 릴리스 서명 및 스토어 배포는 별도 검증이 필요합니다.
- [GitHub Actions](https://github.com/limhiru/weather/actions)에서 각 커밋의 서버·Android·iOS 원격 검증 결과를 확인할 수 있습니다.

## 빌드 환경 복구

로컬 Android SDK Platform 36에 `android.jar`가 누락되어 있었습니다. Google 공식 `platform-36_r02.zip`의 SHA-1을 저장소 메타데이터와 대조한 후 누락된 파일만 복구했고, 이후 APK 빌드가 성공했습니다. SDK 파일은 앱 저장소에 포함하지 않았습니다.
