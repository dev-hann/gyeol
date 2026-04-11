# Gyeol 아키텍처

## 프로젝트 개요

Gyeol — AI Multi-Layer Worker System
Flutter/Dart 데스크톱 애플리케이션. 다중 LLM 제공자를 사용한 AI 처리 파이프라인 오케스트레이션.

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter/Dart (^3.11.3) |
| 데이터베이스 | Drift ORM (SQLite), `gyeol.db`, schema v6 |
| 상태관리 | Riverpod (`flutter_riverpod`) |
| 그래프 에디터 | `vyuh_node_flow` |
| LLM 통신 | `http` 패키지 |
| 테스트 | `flutter_test`, `mockito` |
| ID 생성 | `uuid` |
| 린트 | `very_good_analysis` (strict) |

## 레이어 구조

```
┌─────────────────────────────────────────┐
│  UI Layer (lib/features/, lib/shared/)  │
│  Flutter 위젯 + Riverpod 소비           │
├─────────────────────────────────────────┤
│  State Layer (lib/data/providers/)      │
│  Riverpod Providers + Notifiers         │
├─────────────────────────────────────────┤
│  Data Layer (lib/data/)                 │
│  Repository + Database + Models         │
├─────────────────────────────────────────┤
│  Engine Layer (lib/engine/)             │
│  Scheduler + TaskQueue + MessageBus     │
├─────────────────────────────────────────┤
│  Provider Layer (lib/providers/)        │
│  LLM Provider 인터페이스 + 구현체       │
└─────────────────────────────────────────┘
```

## 디렉토리 구조

```
lib/
├── main.dart                              # 진입점 (ProviderScope > GyeolApp > AppShell)
├── core/
│   └── theme/
│       └── app_theme.dart                 # AppColors + buildAppTheme() (다크 테마, seed #6d5acf)
├── data/
│   ├── database/
│   │   ├── app_database.dart              # Drift 테이블 정의 (10개)
│   │   ├── database.dart                  # AppDatabase 클래스 (schema v6, migrations, CRUD)
│   │   └── database.g.dart                # 자동 생성
│   ├── models/
│   │   └── app_models.dart                # 전체 도메인 모델 (486줄)
│   ├── repositories/
│   │   └── app_repository.dart            # DB 래퍼 (매퍼 메서드 포함)
│   └── providers/
│       └── app_providers.dart             # Riverpod providers + notifiers (421줄)
├── engine/
│   ├── scheduler.dart                     # Scheduler, LayerRegistry, MessageBus
│   ├── queue/
│   │   └── task_queue.dart                # 우선순위 큐 (이진 삽입 정렬)
│   └── chat/
│       ├── chat_service.dart              # 멀티턴 채팅 + 도구 호출 루프 (최대 5회)
│       └── tool_registry.dart             # 12개 AI 도구 정의
├── providers/
│   ├── llm_provider.dart                  # LlmProvider 추상 인터페이스 + 데이터 클래스
│   ├── openai_provider.dart               # OpenAI 구현
│   ├── anthropic_provider.dart            # Anthropic 구현
│   ├── ollama_provider.dart               # Ollama 구현
│   ├── custom_provider.dart               # 커스텀 API 구현 (멀티 포맷)
│   ├── model_fetcher.dart                 # 모델 목록 조회 + 프로토콜 감지
│   └── providers.dart                     # 배럴 익스포트
├── features/
│   ├── chat/chat_panel.dart               # 채팅 UI (오버레이 사이드바)
│   ├── dashboard/pages/dashboard_page.dart # 대시보드 (통계 카드 + 태스크 목록)
│   ├── layers/
│   │   ├── pages/layers_page.dart         # 레이어 관리 (그래프 에디터)
│   │   └── graph/
│   │       ├── flow_canvas.dart           # NodeFlowEditor 래퍼
│   │       ├── layer_node_widget.dart     # 커스텀 노드 위젯
│   │       ├── node_detail_panel.dart     # 노드 상세 사이드바
│   │       └── graph_utils.dart           # 노드/연결 빌더 + 레이아웃 알고리즘
│   ├── workers/pages/workers_page.dart    # 워커 개요 (읽기 전용)
│   ├── monitoring/pages/monitoring_page.dart # 실시간 실행 + 로그 뷰어
│   ├── threads/pages/threads_page.dart    # 스레드 CRUD + 실행
│   └── settings/settings_page.dart        # 제공자 설정 (PlatformConfig + 다이얼로그)
├── shared/widgets/
│   ├── app_shell.dart                     # 메인 셸 (사이드바 네비 + 페이지 + 채팅 오버레이)
│   ├── status_badge.dart                  # 상태 뱃지
│   ├── page_header.dart                   # 페이지 헤더
│   ├── stat_card.dart                     # 통계 카드
│   └── empty_state.dart                   # 빈 상태 플레이스홀더

test/                                       # lib/ 구조 미러링 (35개 테스트 파일)
```

## 핵심 데이터 흐름

### 1. 태스크 실행 흐름

```
submit(AppTask)
    │
    ▼
TaskQueue.push (우선순위 기반 정렬 삽입)
    │
    ▼
runOnce() — 최대 maxConcurrent(4)개 병렬
    │
    ├── LayerRegistry.findByInputType(taskType) → 레이어 매칭
    │
    ├── task.copyWith(status: running)
    │
    └── _executeWorker(task, workerName)
         │
         ├── DB에서 WorkerDefinition 조회
         ├── ProviderSettings로 LlmProvider 생성
         ├── 시스템 프롬프트 조합 (threadPrompt + layerPrompt + workerPrompt)
         ├── provider.generateWithSystem(system, user)
         │
         └── WorkerResult
              ├── success → outputTasks → 큐 재진입 → MessageBus.publish
              └── failure → 에러 로그 기록
```

### 2. 스레드 실행 흐름

```
runThread(ThreadDefinition)
    │
    ├── collectFilesFromPath(thread.path) → 파일 목록 수집
    │
    └── layerNames 순차 실행:
         │
         ├── 현재 taskType으로 레이어 매칭
         ├── 파일 목록 + 컨텍스트를 페이로드로 태스크 생성
         ├── 레이어 내 워커 병렬 실행
         │
         └── outputTypes.first → 다음 레이어의 taskType 갱신
              (초기 taskType = 'raw')
```

### 3. 채팅 도구 호출 흐름

```
ChatService.sendMessage(userInput)
    │
    └── 도구 호출 루프 (최대 5회 반복):
         │
         ├── LLM 응답에 tool_call 포함 여부 확인
         │
         ├── 포함 시: ToolRegistry에서 도구 실행 → 결과를 메시지에 추가 → 루프 계속
         │   도구: create/update/delete/list layers, workers, threads
         │         run_thread, get_status
         │
         └── 미포함 시: 최종 응답 반환
```

## 엔진 컴포넌트

### Scheduler (`lib/engine/scheduler.dart`)
- `submit(AppTask)` → 큐에 푸시
- `runOnce()` → 최대 4개 태스크 병렬 처리
- `runThread(ThreadDefinition)` → 순차 레이어 실행
- `runAllThreads(List<ThreadDefinition>)` → 활성 스레드 순회
- `_executeWorker()` → LLM 호출 + 결과 태스크 생성
- 최대 실행 깊이: 10레벨 (무한 재귀 방지)

### TaskQueue (`lib/engine/queue/task_queue.dart`)
- 이진 검색 기반 정렬 삽입
- 높은 우선순위(높은 enum 인덱스) 먼저 처리
- 동일 우선순위 내 FIFO

### LayerRegistry (`lib/engine/scheduler.dart`)
- 활성화된 레이어 목록 관리
- inputType으로 레이어 조회
- order 기반 정렬

### MessageBus (`lib/engine/scheduler.dart`)
- 타입별 + 와일드카드(`*`) 구독 지원
- 태스크 이벤트 발행

### ChatService (`lib/engine/chat/chat_service.dart`)
- 멀티턴 대화 + 도구 호출 루프
- Gyeol AI 어시스턴트로서의 시스템 프롬프트
- `onRunThread` 콜백으로 스레드 실행 트리거

### ToolRegistry (`lib/engine/chat/tool_registry.dart`)
- 12개 AI 도구 정의: 레이어/워커/스레드 CRUD + 실행 + 상태 조회
