---
name: sync-domain-docs
description: 코드 변경 시 도메인 문서 자동 동기화. docs/domain/ 단일 소스 기반.
---

## 절대 규칙

1. 코드를 수정하지 않음 — 오직 `docs/domain/` 문서만 업데이트
2. 문서 내용은 실제 코드 기반 — 추측 금지
3. 변경된 부분만 정확히 반영 — 불필요한 전체 재작성 금지
4. 문서 포맷 일관성 유지 — 기존 구조/스타일 준수
5. 비즈니스 개념 먼저, 코드 매핑은 나중에 — 개념 문서에서 Dart 필드 명세에 치우치지 않음

## 대상 문서

### 개념 문서 (docs/domain/concepts/)
도메인 개념을 비즈니스 관점에서 정의. 코드 구현 세부는 "코드 매핑" 섹션에만 기록.

| 문서 | 담당 개념 | 동기화 트리거 |
|------|----------|--------------|
| `concepts/task.md` | Task (태스크) | `app_models.dart`의 AppTask/TaskPriority/TaskStatus 변경 |
| `concepts/layer.md` | Layer (레이어) | `app_models.dart`의 LayerDefinition 변경, scheduler.dart의 LayerRegistry 변경 |
| `concepts/worker.md` | Worker (워커) | `app_models.dart`의 WorkerDefinition/WorkerResult 변경 |
| `concepts/thread.md` | Thread (스레드) | `app_models.dart`의 ThreadDefinition/ThreadStatus 변경, scheduler.dart의 runThread 변경 |
| `concepts/provider.md` | Provider (제공자) | `app_models.dart`의 ProviderSettings 변경, `lib/providers/*.dart` 변경 |
| `concepts/pipeline.md` | Pipeline (파이프라인) | `lib/engine/scheduler.dart`, `lib/engine/queue/task_queue.dart` 변경 |
| `concepts/chat.md` | Chat (채팅) | `lib/engine/chat/*.dart` 변경, `app_models.dart`의 ChatConversation/ChatMessage 변경 |

### 용어 및 참조 문서

| 문서 | 역할 | 동기화 트리거 |
|------|------|--------------|
| `glossary.md` | 전체 용어 사전 | 개념 추가/제거/명칭 변경 시 |
| `code-reference.md` | 코드-도메인 빠른 매핑 | 클래스/enum/테이블 추가/제거 시 |
| `architecture.md` | 기술 아키텍처 | 디렉토리 구조/컴포넌트 변경 시 |
| `conventions.md` | 코드 컨벤션 | 린트 규칙/네이밍/테마 변경 시 |

## 동기화 절차

### Step 1: 변경 감지

```bash
git diff --name-only HEAD~1 HEAD
```

변경된 파일에서 동기화 대상 판별:

| 변경 파일 | 동기화 대상 문서 |
|-----------|----------------|
| `lib/data/models/app_models.dart` | 관련 concepts/*.md + glossary.md + code-reference.md |
| `lib/data/database/app_database.dart` | 관련 concepts/*.md + code-reference.md |
| `lib/engine/scheduler.dart` | concepts/pipeline.md, concepts/thread.md |
| `lib/engine/queue/task_queue.dart` | concepts/pipeline.md |
| `lib/engine/chat/*.dart` | concepts/chat.md |
| `lib/providers/*.dart` | concepts/provider.md |
| `lib/features/**/*.dart` (신규 디렉토리) | architecture.md |
| `analysis_options.yaml` | conventions.md |
| `lib/core/theme/*.dart` | conventions.md |

### Step 2: 개념 분석

변경 감지된 파일을 읽고 **비즈니스 개념 수준**에서 파악:

- 새로운 개념이 추가되었는가? → glossary.md + 새 concepts/*.md
- 기존 개념의 핵심 속성이 변경되었는가? → 해당 concepts/*.md
- 개념 간 관계가 변경되었는가? → 관련 concepts/*.md들
- 상태/생명주기가 변경되었는가? → 해당 concepts/*.md
- 규칙이나 제약이 변경되었는가? → 해당 concepts/*.md
- 코드 매핑이 변경되었는가? → code-reference.md

### Step 3: 문서 업데이트

감지된 변경만 정확히 반영:

1. 기존 문서 읽기 (해당 docs/domain/ 파일)
2. 개념 정의(Definition), 핵심 속성, 상태/생명주기, 규칙/제약, 관계 섹션 중 변경된 부분만 수정
3. 코드 매핑 섹션은 각 개념 파일 맨 아래에 유지
4. glossary.md는 용어가 추가/변경된 경우에만 업데이트
5. docs/domain/README.md는 파일이 추가/제거된 경우에만 업데이트 (기존 파일 내용 수정만으로는 README 변경 불필요)

### Step 4: 일관성 검증

```bash
# 에이전트 파일에서 참조하는 구조가 docs/ 와 일치하는지 확인
rg 'docs/domain/' .opencode/agents/ --no-filename
rg 'docs/domain/' .opencode/skills/ --no-filename
```

## 출력 포맷

```
[Domain Sync]
Triggered by: {변경 파일 목록}
Updated:
  - {문서명}: {변경 내용 요약}
Unchanged:
  - {문서명}: 변경 없음
```

## 수동 실행

사용자가 직접 호출 시 전체 동기화 수행:

```
Task(
  subagent_type: "general",
  prompt: "sync-domain-docs 스킬 실행.
  1. 전체 lib/ 구조를 분석하여 docs/domain/ 문서 동기화
  2. 개념 문서(concepts/*.md)는 비즈니스 관점 우선, 코드 매핑은 맨 아래 섹션만
  3. glossary.md와 code-reference.md 일관성 확인
  "
)
```
