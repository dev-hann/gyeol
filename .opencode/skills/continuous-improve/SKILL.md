---
name: continuous-improve
description: Gyeol 프로젝트 무한 루프 지속 개선. Flutter/Dart + TDD(Red-Green-Refactor) 기반. 엔진+데이터+UI 교차 검증.
---

## 절대 규칙

1. Main은 Task 호출만 반복, 결과 수신 후 즉시 다시 Task 호출
2. 멈추지 않는다 — 커밋 후, 에러 후, 개선항목 없어도 계속
3. 정지: 사용자가 "stop"/"중지"/"잠깐" 명시 입력만
4. 1사이클 = 1개선, 같은 파일 연속 수정 금지
5. 포맷 외 출력 금지 — "요약", "총정리" 절대 출력 안 함
6. 서브태스크 30분 초과 시 중지 후 새 Task로 재시작 (N 유지)
7. 모든 수정은 TDD(Red-Green-Refactor) 순서 엄격 준수
8. 수정 영역에 따라 dart-engineer 또는 flutter-engineer 사용
9. 수정 후 반드시 quality-guard로 전체 검증

## TDD 순서

1. **Red** — 테스트 먼저 작성 → `flutter test` → 실패 확인
2. **Green** — 최소 구현 → `flutter test` → 통과 확인
3. **Refactor** — 정리 → `flutter test` + `flutter analyze` → 회귀/경고 없음 확인

테스트 파일은 `test/` 아래 `lib/` 구조를 미러링.

## 에이전트 분기

| 대상 | 에이전트 |
|------|----------|
| `lib/engine/`, `lib/data/`, `lib/providers/` | dart-engineer |
| `lib/features/`, `lib/shared/`, `lib/core/` | flutter-engineer |

## Main 루프

```
Task(
  subagent_type: "general",
  prompt: "Cycle N 실행. 아래 절차와 포맷 준수.

  Phase 1 — 분석:
  Task(analyzer) 호출하여 전체 코드베이스 분석.
  우선순위: P0(컴파일에러/런타임예외) > P1(테스트 없는 모듈) > P2(에러처리/dynamic) > P3(analyze경고/lint) > P4(스타일/포맷)

  Phase 2 — 선택:
  분석 결과에서 최우선 1개 선택. P0 없으면 P1(테스트 없음)이 항상 최우선.

  Phase 3 — 수정 (TDD):
  수정 영역에 따라 dart-engineer 또는 flutter-engineer 호출.
  Red-Green-Refactor 순서로 작업.
  수정 완료 후 Task(quality-guard) 호출하여 전체 검증. 회귀 시 즉시 원복.
  금지: pubspec.yaml 의존성 추가, .g.dart 수동 수정, Drift 스키마 변경.

  Phase 4 — 커밋:
  3사이클마다 git add + commit/push.

  Phase 5 — 완료:
  `date '+%Y-%m-%d %H:%M:%S'` 실행.

  출력 포맷:
  [Phase 1] {분석요약} | {후보수}개 | 테스트커버리지: {N}/{M}모듈
  [Phase 2] {파일} | {이슈} | P{등급}
  [Phase 3] {에이전트} | {TDD단계} | {변경내용} | analyze:{결과} test:{통과/총수}
  [Phase 4] C{N}: {WHAT} — {WHY}
  [DONE C{N}] {YYYY-MM-DD HH:MM:SS}
  "
)
```

Sub 결과 수신 → 즉시 같은 Task 다시 호출.

## 검증 체크리스트 (quality-guard)

1. `flutter analyze` — 정적 분석
2. `dart format --set-exit-if-changed lib/ test/` — 포맷팅
3. `flutter test` — 전체 테스트
4. `dart run build_runner build --delete-conflicting-outputs` — Drift 코드 생성
5. 하나라도 실패 시 즉시 `git checkout -- {파일}` 원복
