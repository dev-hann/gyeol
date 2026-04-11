# Chat (채팅)

## 정의

채팅은 사용자가 **자연어로 시스템과 상호작용하는 인터페이스**입니다.

사용자가 텍스트로 요청하면 AI 어시스턴트가 이해하고, 필요할 경우 직접 도구를 호출하여 레이어를 생성하거나 워커를 설정하거나 스레드를 실행합니다. 사용자는 코드나 UI를 직접 조작하지 않고도 대화를 통해 전체 시스템을 제어할 수 있습니다.

## 핵심 개념

### 대화 (Conversation)
하나의 채팅 세션입니다. 제목을 가지며, 여러 메시지를 포함합니다. 대화는 독립적으로 존재하며 서로 격리됩니다.

### 메시지 (Message)
대화 내의 개별 발화입니다. 세 가지 역할(Role)을 가집니다:

| 역할 | 설명 |
|------|------|
| `user` | 사용자가 보낸 메시지 |
| `assistant` | AI 어시스턴트의 응답 |
| `tool` | 도구 실행의 결과 |

### 도구 (Tool)
AI 어시스턴트가 호출할 수 있는 기능입니다. AI가 사용자의 요청을 분석하여 필요한 도구를 스스로 선택합니다.

## 도구 목록

### 레이어 관리
| 도구 | 기능 |
|------|------|
| `create_layer` | 새 레이어 생성 (이름, 입력 타입, 출력 타입) |
| `update_layer` | 기존 레이어 설정 변경 |
| `delete_layer` | 레이어 삭제 |
| `list_layers` | 전체 레이어 목록 조회 |

### 워커 관리
| 도구 | 기능 |
|------|------|
| `create_worker` | 새 워커 생성 (이름, 소속 레이어, 시스템 프롬프트) |
| `update_worker` | 기존 워커 설정 변경 |
| `delete_worker` | 워커 삭제 |
| `list_workers` | 전체 워커 목록 조회 (레이어별 필터링 가능) |

### 스레드 관리
| 도구 | 기능 |
|------|------|
| `create_thread` | 새 스레드 생성 (이름, 파일 경로, 레이어 목록) |
| `list_threads` | 전체 스레드 목록 조회 |

### 실행 및 상태
| 도구 | 기능 |
|------|------|
| `run_thread` | 지정한 스레드 실행 |
| `get_status` | 시스템 상태 또는 특정 스레드 상태 조회 |

## 도구 호출 루프

AI 어시스턴트는 사용자의 요청을 처리하기 위해 여러 단계로 나누어 도구를 호출할 수 있습니다:

```
사용자: "코드 리뷰 파이프라인을 만들어줘"
    │
    ▼ AI 분석
┌─────────────────────────────────────────────┐
│ 반복 1: create_layer("review", ["raw"], ["review_result"])  │
│ 반복 1: create_worker("reviewer", "review", "당신은 코드 리뷰어...") │
│ 반복 1: create_thread("code-review", "./src", ["review"])    │
│ 반복 2: 최종 응답 생성                                        │
└─────────────────────────────────────────────┘
    │
    ▼
AI: "코드 리뷰 파이프라인을 생성했습니다.
     - review 레이어 (raw → review_result)
     - reviewer 워커
     - code-review 스레드 (./src 경로)
     실행하시겠습니까?"
```

**최대 도구 호출 반복**: 5회 — AI가 무한히 도구를 호출하는 것을 방지합니다.

## 다른 개념과의 관계

- **Layer**: 채팅을 통해 레이어 생성/수정/삭제/조회
- **Worker**: 채팅을 통해 워커 생성/수정/삭제/조회
- **Thread**: 채팅을 통해 스레드 생성/조회/실행
- **Pipeline**: `run_thread` 도구로 파이프라인 실행 트리거
- **Provider**: 채팅 AI 자체가 제공자를 통해 LLM 서비스를 사용

## 코드 매핑

| 도메인 개념 | 코드 구현 | 위치 |
|------------|----------|------|
| Chat Service | `ChatService` 클래스 | `lib/engine/chat/chat_service.dart` |
| Tool Registry | `ToolRegistry` 클래스 | `lib/engine/chat/tool_registry.dart` |
| Conversation | `ChatConversation` 클래스 | `lib/data/models/app_models.dart` |
| Message | `ChatMessage` 클래스 | `lib/data/models/app_models.dart` |
| Tool Definition | `ToolDefinition` 클래스 | `lib/providers/llm_provider.dart` |
| DB — 대화 | `ChatConversations` 테이블 | `lib/data/database/app_database.dart` |
| DB — 메시지 | `ChatMessages` 테이블 | `lib/data/database/app_database.dart` |
