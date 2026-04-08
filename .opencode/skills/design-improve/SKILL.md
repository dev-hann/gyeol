---
name: design-improve
description: Gyeol 프로젝트 UI/UX 지속 개선. shadcn/ui + React Flow 그래프 에디터 기반 디자인 시스템 준수.
---

## 절대 규칙

1. Main은 Task 호출만 반복, 결과 수신 후 즉시 다시 Task 호출
2. 멈추지 않는다 — 커밋 후, 에러 후, 개선항목 없어도 계속
3. 정지: 사용자가 "stop"/"중지"/"잠깐" 명시 입력만
4. 1사이클 = 1개선, 같은 파일 연속 수정 금지
5. 포맷 외 출력 금지 — "요약", "총정리" 절대 출력 안 함
6. 서브태스크 30분 초과 시 중지 후 새 Task로 재시작 (N 유지)
7. 수정 대상이 src/ 영역이면 frontend-engineer 사용
8. 수정 후 반드시 quality-guard로 빌드 검증

## 디자인 시스템 아키텍처

### 색상 토큰 계층
```
:root CSS 변수 (src/index.css)
  ├── 배경: --background, --card, --popover, --muted, --secondary
  ├── 전경: --foreground, --card-foreground, --muted-foreground
  ├── 주색: --primary, --primary-foreground
  ├── 상태: --success, --warning, --error, --info
  ├── 보더: --border, --input, --ring
  └── 파괴: --destructive, --destructive-foreground
```

### 컴포넌트 계층
```
shadcn/ui 컴포넌트 (src/components/ui/)
  ├── 원시: Button, Input, Select, Textarea, Switch, Label
  ├── 구조: Card, Separator, ScrollArea, Sheet, Skeleton
  ├── 표시: Badge, Tooltip
  └── 각각 variant 시스템 보유 (cva 기반)

앱 컴포넌트 (src/components/app/)
  ├── PageHeader — 페이지 공통 헤더 (icon + title + description + action)
  ├── StatusBadge — 상태 뱃지 (Pending=warning, Running=info, Done=success, Failed=error)
  └── EmptyState — 빈 상태 (icon + title + description + action)

그래프 컴포넌트 (src/components/graph/)
  ├── FlowCanvas — React Flow 메인 캔버스 (MiniMap, Controls, Background)
  ├── LayerNode — 커스텀 노드 (상태 표시, 워커 수, 타입 뱃지)
  ├── TypeEdge — 커스텀 엣지 (타입 라벨, 실행 애니메이션)
  ├── NodeDetailSheet — 노드 상세 사이드시트 (편집, 워커 목록)
  └── graph-utils — Layer[] → Node[]+Edge[] 변환 (dagre 레이아웃)
```

### 그래프 노드-엣지 매핑 규칙
```
Layer → React Flow Node (type: "layerNode")
  position: dagre 자동 배치 (rankdir: LR)
  handles: target=Left, source=Right
  data: name, enabled, workerNames, inputTypes, outputTypes, runningTasks

Layer 간 연결 → React Flow Edge (type: "typeEdge")
  조건: A.output_types ∩ B.input_types 교집합 존재 시 엣지 생성
  label: 연결된 타입명
  animated: 실행 중인 태스크가 관련 레이어에 있으면 true
```

## Main 루프

반복해서 Task 호출:

```
Task(
  subagent_type: "general",
  prompt: "Cycle N 실행. 아래 절차와 포맷 준수.

  Phase 1 — 분석:
  아래 grep 패턴으로 디자인 편차 탐지:

  탐지 명령어 (순서대로 실행):
  1. rg 'text-(red|green|blue|yellow|purple|zinc|orange|pink|cyan|teal)-[0-9]{3}' src/ --line-number
     → 하드코딩 Tailwind 색상 (shadcn 토큰으로 교체 필요)
  2. rg 'bg-\[var\(--' src/ --line-number | rg -v 'node_modules|dist'
     → CSS 변수 직접 참조 (컴포넌트 variant/prop 사용 권장)
  3. rg '(className|class)=".{' src/ -l | xargs -I{} sh -c 'grep -oP \"className=\\\\\"[^\\\\\"]{100,}\" {} > /dev/null && echo {}'
     → 100자 초과 인라인 className (컴포넌트 추출 후보)
  4. rg 'focus:' src/ --line-number -c | sort -t: -k3 -n
     → focus 스타일 없는 인터랙티브 요소 확인
  5. rg 'aria-|role=' src/ --line-number -c
     → 접근성 속성 사용 현황
  6. pnpm build 2>&1 | tail -5
  7. pnpm lint 2>&1

  우선순위:
  P0: 하드코딩 색상 (Tailwind 유틸리티 색상 직접 사용)
  P1: 반복 패턴 (동일 className 조합 3회 이상 → 컴포넌트 추출)
  P2: 접근성 (focus, aria, role 누락)
  P3: 그래프 인터랙션/애니메이션 개선
  P4: 마이크로 인터랙션 (트랜지션, 호버 효과)

  Phase 2 — 선택:
  분석 결과에서 최우선 1개 선택.

  Phase 3 — 수정:
  수정 대상이 src/ 이면 Task(frontend-engineer) 호출.

  수정 원칙:
  - 색상: 항상 shadcn CSS 변수(--background, --primary 등) 또는 Tailwind 토큰(text-foreground, bg-card 등) 사용
  - 상태색: Badge variant 사용 (success/warning/error/info)
  - 컴포넌트: 항상 src/components/ui/ 또는 src/components/app/의 기존 컴포넌트 사용
  - 그래프: LayerNode, TypeEdge 컴포넌트 내부도 shadcn 토큰 사용
  - 새 파일: src/components/ui/에만 생성, shadcn/ui 스타일 준수

  수정 완료 후 Task(quality-guard) 호출하여 빌드 검증.
  회귀 발생 시 즉시 원복.
  금지: node_modules/dist/.git/target 수정, 새 npm/cargo 의존성 추가, 공개 API/Tauri Command 시그니처 변경, SQLite 스키마 변경.

  Phase 4 — 커밋:
  3사이클마다 git add + commit/push.

  Phase 5 — 완료:
  완료 시간 출력. `date '+%Y-%m-%d %H:%M:%S'` 실행 후 아래 포맷으로 출력.

  출력 포맷 (이 형식 외 출력 금지):
  [Phase 1] {분석요약} | {편차수}개
  [PROCEED TO Phase 2]
  [Phase 2] {파일} | {이슈} | P{등급}
  [PROCEED TO Phase 3]
  [Phase 3] {에이전트} | {변경내용} | build:{결과} lint:{결과}
  [PROCEED TO Phase 4]
  [Phase 4] C{N}: {WHAT} — {WHY}
  [PROCEED TO Phase 5]
  [DONE C{N}] {YYYY-MM-DD HH:MM:SS}
  "
)
```

Sub 결과 수신 → 즉시 같은 Task 다시 호출.

## 색상 매핑 참조

| 이전 (하드코딩) | 이후 (shadcn 토큰) |
|-----------------|-------------------|
| `text-yellow-400` | `text-warning` 또는 `<Badge variant="warning">` |
| `text-green-400` | `text-success` 또는 `<Badge variant="success">` |
| `text-red-400` | `text-error` 또는 `<Badge variant="error">` |
| `text-blue-400` | `text-info` 또는 `<Badge variant="info">` |
| `text-purple-400` | `text-primary` |
| `text-zinc-400` | `text-muted-foreground` |
| `text-zinc-500` | `text-muted-foreground` |
| `bg-green-500/10` | `bg-success/10` 또는 `<Badge variant="success">` |
| `bg-red-500/10` | `bg-error/10` 또는 `<Badge variant="error">` |
| `bg-yellow-500/10` | `bg-warning/10` 또는 `<Badge variant="warning">` |
| `bg-blue-500/10` | `bg-info/10` 또는 `<Badge variant="info">` |
| `bg-[var(--bg-secondary)]` | `bg-card` |
| `bg-[var(--bg-tertiary)]` | `bg-secondary` |
| `bg-[var(--bg-hover)]` | `bg-accent` |
| `bg-[var(--bg-primary)]` | `bg-background` |
| `border-[var(--border)]` | `border-border` |
| `text-[var(--text-primary)]` | `text-foreground` |
| `text-[var(--text-secondary)]` | `text-muted-foreground` |
| `text-[var(--text-muted)]` | `text-muted-foreground` |

## 검증 체크리스트 (quality-guard)

수정 후 반드시 순서대로 실행:
1. `pnpm build` — TypeScript + Vite 빌드
2. `pnpm lint` — ESLint
3. 하나라도 실패 시 즉시 `git checkout -- {파일}` 원복

## 타임아웃 처리

서브태스크가 30분(1,800,000ms) 이상 실행되면:
1. Task 호출 시 `timeout: 1800000` 설정
2. 타임아웃/에러 발생 시 동일 N으로 새 Task 즉시 재시작
3. 이전 사이클에서 수정 중이던 내용은 무시하고 깨끗한 상태에서 시작
4. 재시작 프롬프트에 "이전 C{N} 타임아웃으로 재시작" 명시
