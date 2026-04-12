# 코드-도메인 매핑 참조

도메인 개념과 코드 구현 간의 빠른 매핑 참조.
개념 정의는 `glossary.md`와 `concepts/` 디렉토리를 참조하세요.

## Enum 매핑

| 도메인 개념 | Enum | 값 | 위치 |
|------------|------|-----|------|
| 우선순위 | `TaskPriority` | `low`, `medium`, `high` | `app_models.dart` |
| 태스크 상태 | `TaskStatus` | `pending`, `running`, `done`, `failed` | `app_models.dart` |
| 스레드 상태 | `ThreadStatus` | `idle`, `running`, `completed`, `failed` | `app_models.dart` |
| 제공자 유형 | `ProviderType` | `openAI`, `anthropic`, `ollama`, `custom` | `app_models.dart` |
| API 포맷 | `CustomApiFormat` | `openAICompatible`, `anthropicCompatible`, `ollamaCompatible` | `app_models.dart` |

## 클래스-개념 매핑

| 도메인 개념 | 클래스 | 소스 파일 | DB 테이블 |
|------------|--------|----------|----------|
| Task | `AppTask` | `lib/data/models/app_models.dart` | `Tasks` (PK: id) |
| Layer | `LayerDefinition` | `lib/data/models/app_models.dart` | `Layers` (PK: name) |
| Worker | `WorkerDefinition` | `lib/data/models/app_models.dart` | `Workers` (PK: name) |
| Thread | `ThreadDefinition` | `lib/data/models/app_models.dart` | `Threads` (PK: name) |
| Thread-Layer 조인 | `ThreadLayer` | `lib/data/database/app_database.dart` | `ThreadLayers` (PK: threadName, layerName) |
| Provider 설정 | `ProviderSettings` | `lib/data/models/app_models.dart` | `Settings` (key-value JSON) |
| UI 상태 | `UiStateRow` | `lib/data/database/app_database.dart` | `UiStates` (PK: key) |
| 워커 실행 결과 | `WorkerResult` | `lib/data/models/app_models.dart` | — |
| 평가 결과 | `EvaluationResult` | `lib/data/models/app_models.dart` | — |
| 대화 | `ChatConversation` | `lib/data/models/app_models.dart` | `ChatConversations` (PK: id) |
| 메시지 | `ChatMessage` | `lib/data/models/app_models.dart` | `ChatMessages` (PK: id) |

## 엔진 컴포넌트 매핑

| 도메인 개념 | 클래스 | 소스 파일 |
|------------|--------|----------|
| 스케줄러 | `Scheduler` | `lib/engine/scheduler.dart` |
| 큐 | `TaskQueue` | `lib/engine/queue/task_queue.dart` |
| 메시지 버스 | `MessageBus` | `lib/engine/message_bus.dart` |
| 레이어 레지스트리 | `LayerRegistry` | `lib/engine/layer_registry.dart` |
| 채팅 서비스 | `ChatService` | `lib/engine/chat/chat_service.dart` |
| 도구 레지스트리 | `ToolRegistry` | `lib/engine/chat/tool_registry.dart` |

## Provider 구현 매핑

| 도메인 개념 | 클래스 | 소스 파일 |
|------------|--------|----------|
| Provider 인터페이스 | `LlmProvider` | `lib/providers/llm_provider.dart` |
| OpenAI | `OpenAIProvider` | `lib/providers/openai_provider.dart` |
| Anthropic | `AnthropicProvider` | `lib/providers/anthropic_provider.dart` |
| Ollama | `OllamaProvider` | `lib/providers/ollama_provider.dart` |
| Custom | `CustomProvider` | `lib/providers/custom_provider.dart` |
| 모델 조회 | `ModelFetcher` | `lib/providers/model_fetcher.dart` |

## DB 스키마 버전 이력

| 버전 | 추가된 테이블 | 비고 |
|------|-------------|------|
| v1 | `Tasks`, `Layers`, `Workers`, `Settings`, `ExecutionLogs` | 초기 스키마 |
| v2 | `Threads` | 스레드 기능 추가 |
| v3 | — | `threads.context_prompt`, `layers.layer_prompt` 컬럼 추가 |
| v4 | `ChatConversations`, `ChatMessages` | 채팅 기능 추가 |
| v5 | — | `layers.worker_names` 컬럼 제거 (테이블 재생성) |
| v6 | `ThreadLayers`, `UiStates` | FK 제약조건, 인덱스, `ThreadLayers` 조인 테이블, `UiStates` 분리, 타임스탬프 일관성 |
