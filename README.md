# 용의 전설 - 이무기의 탄생 (Legend of Imugi: Rise of the Dragon)

조선시대와 한국 설화를 배경으로 한 3D 모바일 육성 어드벤처 RPG입니다.
작은 동굴에서 태어난 이무기가 음양의 기운과 오행 보주를 모아 다양한 용으로 진화합니다.

- 엔진: Godot 4
- 플랫폼: Android (로컬 싱글 플레이)

## 기획 문서

전체 기획 구조는 [`docs/design/`](docs/design/00_개요와_시스템구조.md)에 있습니다.

## 개발 시작하기

- 엔진: **Godot 4.7.2-stable** (Compatibility 렌더러, 가로 모드, arm64 Android)
- 설치, 테스트 명령, Android 빌드와 기기 확인 방법: [`docs/dev/개발환경_가이드.md`](docs/dev/개발환경_가이드.md)
- PR마다 GitHub Actions가 데이터 검증, 세이브 테스트, 디버그 APK 빌드를 실행하고 APK를 아티팩트로 올린다.
