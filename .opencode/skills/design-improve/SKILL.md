---
name: design-improve
description: Gyeol 프로젝트 UI/UX 지속 개선. Material Design 3 + flutter_flow_chart 기반. TDD 위젯 테스트 동반.
---

## 절대 규칙

1. Main은 Task 호출만 반복, 결과 수신 후 즉시 다시 Task 호출
2. 멈추지 않는다 — 커밋 후, 에러 후, 개선항목 없어도 계속
3. 정지: 사용자가 "stop"/"중지"/"잠깐" 명시 입력만
4. 1사이클 = 1개선, 같은 파일 연속 수정 금지
5. 포맷 외 출력 금지 — "요약", "총정리" 절대 출력 안 함
6. 서브태스크 30분 초과 시 중지 후 새 Task로 재시작 (N 유지)
7. 모든 UI 수정은 위젯 테스트 동반 (TDD)
8. 수정 대상이 lib/features/ 또는 lib/shared/ 이면 flutter-engineer 사용
9. 수정 후 반드시 quality-guard로 빌드 검증

## 디자인 시스템 아키텍처

### 테마 계층
```
MaterialApp.theme (lib/core/theme/app_theme.dart)
  ├── ColorScheme (Seed color 기반 자동 생성)
  │   ├── primary / onPrimary / primaryContainer
  │   ├── secondary / onSecondary / secondaryContainer
  │   ├── tertiary / onTertiary / tertiaryContainer
  │   ├── error / onError / errorContainer
  │   ├── surface / onSurface / surfaceVariant
  │   ├── outline / outlineVariant
  │   └── inverseSurface / inversePrimary
  ├── TextTheme (google_fonts 기반)
  │   ├── headlineLarge/Medium/Small
  │   ├── titleLarge/Medium/Small
  │   ├── bodyLarge/Medium/Small
  │   └── labelLarge/Medium/Small
  └── Component themes (CardTheme, AppBarTheme, etc.)
```

### 컴포넌트 계층
```
공통 위젯 (lib/shared/widgets/)
  ├── AppShell — 앱 셸 (BottomNavigationBar + 라우팅)
  ├── StatusBadge — 상태 뱃지 (Pending=warning, Running=info, Done=success, Failed=error)
  ├── EmptyState — 빈 상태 (icon + title + description + action)
  ├── PageHeader — 페이지 공통 헤더 (icon + title + description + action)
  └── StatCard — 통계 카드 (label + value + icon + trend)

그래프 위젯 (lib/features/layers/graph/)
  ├── FlowCanvas — flutter_flow_chart 메인 캔버스
  ├── LayerNodeWidget — 커스텀 노드 (상태 표시, 워커 수, 타입 뱃지)
  ├── NodeDetailPanel — 노드 상세 패널 (편집, 워커 목록)
  └── graph_utils — Layer[] → 노드/엣지 변환 유틸리티
```

## Main 루프

반복해서 Task 호출:

```
Task(
  subagent_type: "general",
  prompt: "Cycle N 실행. 아래 절차와 포맷 준수.

  Phase 1 — 분석:
  아래 탐지 명령어로 디자인 편차 탐지:

  탐지 명령어 (순서대로 실행):
  1. rg 'Colors\.' lib/ --line-number -n | rg -v ' Colors\.transparent| Colors\.white| Colors\.black|app_theme'
     → 하드코딩 Material Colors (Theme.of(context).colorScheme 사용 필요)
  2. rg 'TextStyle\(' lib/ --line-number -n | rg -v 'context'
     → Theme 없는 직접 TextStyle 생성 (Theme.of(context).textTheme 사용 필요)
  3. rg 'EdgeInsets\.(all|symmetric|only)\(' lib/ --line-number -c | sort -t: -k3 -n
     → 반복 패딩 패턴 (상수 또는 공통 위젯 추출 후보)
  4. rg 'SizedBox\(' lib/ --line-number -c | sort -t: -k3 -n
     → 반복 간격 패턴
  5. flutter analyze 2>&1
  6. flutter test 2>&1

  우선순위:
  P0: 하드코딩 색상 (Colors.xxx 직접 사용)
  P1: 테스트 없는 위젯 (위젯 테스트 작성 필요 — TDD)
  P2: 반복 패턴 (동일 위젯 조합 3회 이상 → 공통 위젯 추출)
  P3: 접근성 (Semantics, tooltip, label 누락)
  P4: 마이크로 인터랙션 (애니메이션, 트랜지션)

  Phase 2 — 선택:
  분석 결과에서 최우선 1개 선택.

  Phase 3 — 수정 (TDD):
  수정 대상이 lib/ 이면 Task(flutter-engineer) 호출.

  수정 원칙:
  - 색상: 항상 Theme.of(context).colorScheme.* 사용 — Colors.xxx 직접 사용 금지
  - 타이포그래피: 항상 Theme.of(context).textTheme.* 사용 — TextStyle() 직접 생성 금지
  - 간격: 반복 패턴은 상수 또는 공통 위젯으로 추출
  - 상태색: StatusBadge 위젯 사용 (success/warning/error/info)
  - 새 위젯: lib/shared/widgets/에만 생성, Material Design 3 스타일 준수
  - 그래프: LayerNodeWidget도 테마 토큰 사용

  반드시 Red-Green-Refactor 순서:
  1. Red: 위젯 테스트 먼저 작성 → flutter test → 실패 확인
  2. Green: 최소 위젯 코드 작성 → flutter test → 통과 확인
  3. Refactor: 정리 → flutter test → 회귀 없음 확인

  수정 완료 후 Task(quality-guard) 호출하여 빌드 검증.
  회귀 발생 시 즉시 원복.
  금지: pubspec.yaml 의존성 추가, .g.dart 수동 수정, Drift 스키마 변경.

  Phase 4 — 커밋:
  3사이클마다 git add + commit/push.

  Phase 5 — 완료:
  완료 시간 출력. `date '+%Y-%m-%d %H:%M:%S'` 실행 후 아래 포맷으로 출력.

  출력 포맷 (이 형식 외 출력 금지):
  [Phase 1] {분석요약} | {편차수}개 | 위젯테스트커버리지: {N}/{M}
  [PROCEED TO Phase 2]
  [Phase 2] {파일} | {이슈} | P{등급}
  [PROCEED TO Phase 3]
  [Phase 3] {에이전트} | {TDD단계} | {변경내용} | analyze:{결과} test:{통과/총수}
  [PROCEED TO Phase 4]
  [Phase 4] C{N}: {WHAT} — {WHY}
  [PROCEED TO Phase 5]
  [DONE C{N}] {YYYY-MM-DD HH:MM:SS}
  "
)
```

Sub 결과 수신 → 즉시 같은 Task 다시 호출.

## 색상 매핑 참조

`docs/domain/conventions.md`의 색상 매핑 테이블 참조.

## 검증 체크리스트 (quality-guard)

수정 후 반드시 순서대로 실행:
1. `flutter analyze` — 정적 분석
2. `dart format --set-exit-if-changed lib/ test/` — 포맷팅
3. `flutter test` — 전체 테스트
4. 하나라도 실패 시 즉시 `git checkout -- {파일}` 원복

## 타임아웃 처리

서브태스크가 30분(1,800,000ms) 이상 실행되면:
1. Task 호출 시 `timeout: 1800000` 설정
2. 타임아웃/에러 발생 시 동일 N으로 새 Task 즉시 재시작
3. 이전 사이클에서 수정 중이던 내용은 무시하고 깨끗한 상태에서 시작
4. 재시작 프롬프트에 "이전 C{N} 타임아웃으로 재시작" 명시
