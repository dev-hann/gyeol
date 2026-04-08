---
name: continuous-improve
description: Gyeol 프로젝트 무한 루프 지속 개선. Rust 백엔드 + React 프론트엔드 교차 검증.
---

## 절대 규칙

1. Main은 Task 호출만 반복, 결과 수신 후 즉시 다시 Task 호출
2. 멈추지 않는다 — 커밋 후, 에러 후, 개선항목 없어도 계속
3. 정지: 사용자가 "stop"/"중지"/"잠깐" 명시 입력만
4. 1사이클 = 1개선, 같은 파일 연속 수정 금지
5. 포맷 외 출력 금지 — "요약", "총정리" 절대 출력 안 함
6. 서브태스크 30분 초과 시 중지 후 새 Task로 재시작 (N 유지)
7. Rust 영역 수정 시 rust-engineer, 프론트엔드 영역 수정 시 frontend-engineer 사용
8. 수정 후 반드시 quality-guard로 교차 빌드 검증

## Main 루프

반복해서 Task 호출:

```
Task(
  subagent_type: "general",
  prompt: "Cycle N 실행. 아래 절차와 포맷 준수.

  Phase 1 — 분석:
  Task(analyzer) 호출하여 전체 코드베이스 분석.
  cargo check, cargo clippy, pnpm build, pnpm lint 결과 수집.
  우선순위: P0(컴파일에러/패닉)>P1(에러처리/unwrap)>P2(warnings/lint)>P3(스타일)

  Phase 2 — 선택:
  분석 결과에서 최우선 1개 선택.

  Phase 3 — 수정:
  수정 대상이 src-tauri/src/ 이면 Task(rust-engineer) 호출.
  수정 대상이 src/ 이면 Task(frontend-engineer) 호출.
  수정 완료 후 Task(quality-guard) 호출하여 교차 빌드 검증.
  회귀 발생 시 즉시 원복.
  금지: node_modules/dist/.git/target 수정, 새 npm/cargo 의존성 추가, 공개 API/Tauri Command 시그니처 변경, SQLite 스키마 변경.

  Phase 4 — 커밋:
  3사이클마다 git add + commit/push.

  Phase 5 — 완료:
  완료 시간 출력. `date '+%Y-%m-%d %H:%M:%S'` 실행 후 아래 포맷으로 출력.

  출력 포맷 (이 형식 외 출력 금지):
  [Phase 1] {분석요약} | {후보수}개
  [PROCEED TO Phase 2]
  [Phase 2] {파일} | {이슈} | P{등급}
  [PROCEED TO Phase 3]
  [Phase 3] {에이전트} | {변경내용} | check:{결과} clippy:{결과} tsc:{결과} lint:{결과}
  [PROCEED TO Phase 4]
  [Phase 4] C{N}: {WHAT} — {WHY}
  [PROCEED TO Phase 5]
  [DONE C{N}] {YYYY-MM-DD HH:MM:SS}
  "
)
```

Sub 결과 수신 → 즉시 같은 Task 다시 호출.

## 수정 영역 분기 규칙

| 수정 대상 | 호출 에이전트 |
|-----------|--------------|
| `src-tauri/src/engine/*` | rust-engineer |
| `src-tauri/src/providers/*` | rust-engineer |
| `src-tauri/src/store/*` | rust-engineer |
| `src-tauri/src/commands/*` | rust-engineer |
| `src-tauri/src/state.rs` | rust-engineer |
| `src-tauri/src/lib.rs` | rust-engineer |
| `src/pages/*` | frontend-engineer |
| `src/components/*` | frontend-engineer |
| `src/stores/*` | frontend-engineer |
| `src/types/*` | frontend-engineer |
| `src/lib/*` | frontend-engineer |
| `src/App.tsx` | frontend-engineer |
| `src/index.css` | frontend-engineer |

## 검증 체크리스트 (quality-guard)

수정 후 반드시 순서대로 실행:
1. `cd src-tauri && cargo check` — Rust 컴파일
2. `cd src-tauri && cargo clippy` — Rust 린트
3. `pnpm build` — TypeScript + Vite 빌드
4. `pnpm lint` — ESLint
5. 하나라도 실패 시 즉시 `git checkout -- {파일}` 원복

## 타임아웃 처리

서브태스크가 30분(1,800,000ms) 이상 실행되면:
1. Task 호출 시 `timeout: 1800000` 설정
2. 타임아웃/에러 발생 시 동일 N으로 새 Task 즉시 재시작
3. 이전 사이클에서 수정 중이던 내용은 무시하고 깨끗한 상태에서 시작
4. 재시작 프롬프트에 "이전 C{N} 타임아웃으로 재시작" 명시
