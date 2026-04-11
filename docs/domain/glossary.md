# Gyeol 도메인 용어 사전

Gyeol 시스템에서 사용하는 모든 도메인 용어를 모은 사전입니다.
각 용어의 비즈니스적 의미를 정의하며, 코드 구현 세부는 각 개념 문서를 참조하세요.

## 핵심 개념

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 태스크 | Task | 시스템이 처리하는 최소 단위의 작업. 하나의 입력과 우선순위를 가지며, 스케줄러에 의해 큐에 들어가 적절한 레이어로 라우팅됨 | [concepts/task.md](concepts/task.md) |
| 레이어 | Layer | 데이터를 변환하는 처리 단계. 입력 타입을 받아 출력 타입을 생성하며, 하나 이상의 워커를 포함함 | [concepts/layer.md](concepts/layer.md) |
| 워커 | Worker | 레이어에 소속된 AI 에이전트. 시스템 프롬프트와 모델 설정을 가지며, 태스크를 실제로 수행함 | [concepts/worker.md](concepts/worker.md) |
| 스레드 | Thread | 파일 시스템 경로의 파일들을 순서대로 여러 레이어에 통과시키는 실행 파이프라인 | [concepts/thread.md](concepts/thread.md) |
| 제공자 | Provider | LLM(대형 언어 모델) 서비스에 대한 추상화. OpenAI, Anthropic, Ollama, 커스텀 엔드포인트를 동일한 방식으로 사용 | [concepts/provider.md](concepts/provider.md) |
| 파이프라인 | Pipeline | 태스크가 큐에 들어가부터 실행 완료까지 거치는 전체 흐름. 스케줄러, 큐, 메시지 버스의 협업 | [concepts/pipeline.md](concepts/pipeline.md) |
| 채팅 | Chat | 사용자가 자연어로 시스템과 상호작용하는 인터페이스. AI가 도구를 호출하여 레이어/워커/스레드를 관리 | [concepts/chat.md](concepts/chat.md) |

## 실행 흐름 용어

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 스케줄러 | Scheduler | 태스크를 큐에서 꺼내 적절한 레이어에 매칭하고 워커를 실행하는 오케스트레이터 | [concepts/pipeline.md](concepts/pipeline.md) |
| 큐 | Queue | 우선순위 기반으로 태스크를 정렬 보관하는 대기열. 높은 우선순위가 먼저 처리됨 | [concepts/pipeline.md](concepts/pipeline.md) |
| 메시지 버스 | Message Bus | 태스크 이벤트를 구독자에게 전달하는 발행/구독 시스템 | [concepts/pipeline.md](concepts/pipeline.md) |
| 실행 깊이 | Execution Depth | 하나의 태스크가 파생시킨 후속 태스크의 중첩 수준. 무한 재귀를 방지하기 위해 최대 10으로 제한 | [concepts/task.md](concepts/task.md) |
| 실행 로그 | Execution Log | 워커 실행의 성공/실패 기록. 디버깅과 모니터링에 사용 | [concepts/pipeline.md](concepts/pipeline.md) |

## 타입 시스템 용어

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 입력 타입 | Input Type | 레이어가 수용할 수 있는 데이터 유형의 식별자. 문자열로 표현됨 (예: "raw", "analysis_result") | [concepts/layer.md](concepts/layer.md) |
| 출력 타입 | Output Type | 레이어가 생성하는 데이터 유형의 식별자. 다음 레이어의 입력 타입과 연결됨 | [concepts/layer.md](concepts/layer.md) |
| 태스크 타입 | Task Type | 태스크의 유형을 나타내는 문자열. 스케줄러가 이 값으로 레이어를 매칭함. 입력 타입과 동일한 개념 | [concepts/task.md](concepts/task.md) |
| 페이로드 | Payload | 태스크에 실려가는 실제 데이터. 어떤 형태든 가능함 (맵, 리스트, 문자열 등) | [concepts/task.md](concepts/task.md) |

## 상태 용어

| 용어 (한) | 용어 (영) | 대상 | 정의 |
|-----------|----------|------|------|
| 대기 | Pending / Idle | Task, Thread | 큐에 들어가 실행을 기다리는 상태 |
| 실행 중 | Running | Task, Thread | 현재 처리되고 있는 상태 |
| 완료 | Done / Completed | Task, Thread | 처리가 성공적으로 끝난 상태 |
| 실패 | Failed | Task, Thread | 처리 중 에러가 발생한 상태 |
| 활성 | Enabled | Layer, Worker, Thread | 실행 대상에 포함된 상태 |
| 비활성 | Disabled | Layer, Worker, Thread | 실행 대상에서 제외된 상태 |

## 프롬프트 용어

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 시스템 프롬프트 | System Prompt | 워커의 역할과 지침을 정의하는 프롬프트. 모든 실행에 적용됨 | [concepts/worker.md](concepts/worker.md) |
| 레이어 프롬프트 | Layer Prompt | 레이어 전체에 적용되는 공통 프롬프트. 해당 레이어의 모든 워커에 추가됨 | [concepts/layer.md](concepts/layer.md) |
| 컨텍스트 프롬프트 | Context Prompt | 스레드 전체에 적용되는 프롬프트. 실행 컨텍스트를 제공함 | [concepts/thread.md](concepts/thread.md) |
| 프롬프트 계층 | Prompt Hierarchy | 실행 시 Thread Prompt → Layer Prompt → Worker Prompt 순서로 조합되는 계층 구조 | [concepts/worker.md](concepts/worker.md) |

## 우선순위 용어

| 용어 (한) | 용어 (영) | 정의 |
|-----------|----------|------|
| 낮음 | Low | 일반적인 처리. 높은 우선순위 태스크가 없을 때 실행 |
| 보통 | Medium | 기본 우선순위 |
| 높음 | High | 즉시 처리가 필요한 태스크. 스레드 실행 시 자동 부여 |

## 제공자 관련 용어

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 모델 | Model | LLM의 특정 버전 (예: gpt-4o, claude-sonnet-4, llama3) | [concepts/provider.md](concepts/provider.md) |
| 생성 온도 | Temperature | LLM 응답의 무작위성 조절값. 0에 가까울수록 결정적, 1에 가까울수록 창의적 | [concepts/provider.md](concepts/provider.md) |
| 최대 토큰 | Max Tokens | LLM 응답의 최대 길이 제한 | [concepts/provider.md](concepts/provider.md) |
| API 포맷 | API Format | 커스텀 엔드포인트가 호환하는 프로토콜 형식 (OpenAI/Anthropic/Ollama 호환) | [concepts/provider.md](concepts/provider.md) |

## 채팅 관련 용어

| 용어 (한) | 용어 (영) | 정의 | 상세 문서 |
|-----------|----------|------|----------|
| 대화 | Conversation | 하나의 채팅 세션. 여러 메시지를 포함 | [concepts/chat.md](concepts/chat.md) |
| 메시지 | Message | 대화 내 개별 발화. 사용자, AI 어시스턴트, 도구 응답 세 가지 역할 | [concepts/chat.md](concepts/chat.md) |
| 도구 | Tool | AI가 호출할 수 있는 기능. 레이어/워커/스레드 관리 및 실행 | [concepts/chat.md](concepts/chat.md) |
| 도구 호출 | Tool Call | AI가 자발적으로 도구를 실행하는 행위. 최대 5회 반복 가능 | [concepts/chat.md](concepts/chat.md) |

## 평가 용어

| 용어 (한) | 용어 (영) | 정의 |
|-----------|----------|------|
| 평가 | Evaluation | 워커 결과의 품질을 점검하는 과정 |
| 평가 점수 | Score | 평가 결과의 수치화된 점수 |
| 평가 사유 | Reasons | 평가 통과/실패의 이유 목록 |
