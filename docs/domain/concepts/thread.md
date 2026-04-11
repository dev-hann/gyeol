# Thread (스레드)

## 정의

스레드는 **실행 파이프라인**입니다. 파일 시스템 경로에서 파일을 수집하여, 순서대로 여러 레이어에 통과시키는 실행 단위입니다.

단일 태스크가 하나의 레이어를 거치는 것과 달리, 스레드는 여러 레이어를 **순차적으로** 연결하여 복잡한 처리 흐름을 만듭니다. 각 레이어의 출력이 다음 레이어의 입력이 되는 방식으로 데이터가 변환되어 갑니다.

## 핵심 속성

### 이름 (Name)
스레드의 고유 식별자입니다. 시스템 전체에서 중복될 수 없습니다.

### 파일 경로 (Path)
스레드가 처리할 파일이 있는 파일 시스템 경로입니다. 실행 시 이 경로에서 지정된 확장자(.dart, .yaml, .md, .json, .txt)의 파일을 재귀적으로 수집합니다.

### 레이어 목록 (Layer Names)
스레드가 순서대로 실행할 레이어의 이름 목록입니다. 나열된 순서대로 실행됩니다.

### 컨텍스트 프롬프트 (Context Prompt)
스레드 전체에 적용되는 프롬프트입니다. 실행 컨텍스트를 제공하여 워커들이 일관된 관점에서 작업할 수 있게 합니다. 예: "이 프로젝트는 Flutter 앱입니다. Material Design 3 가이드라인을 따르세요."

## 실행 흐름

```
1. 파일 수집
   collectFilesFromPath(path) → [.dart, .yaml, .md, ...]

2. 첫 번째 레이어
   taskType = "raw" (항상 여기서 시작)
   payload = { thread, path, currentType, files }
   → Layer 매칭 → Workers 병렬 실행 → 결과 수집

3. 출력 타입 전달
   layer.outputTypes.first → 다음 taskType

4. 다음 레이어
   taskType = 이전 레이어의 출력 타입
   payload = { thread, path, currentType }
   → Layer 매칭 → Workers 병렬 실행 → 결과 수집

5. 레이어 목록 끝까지 반복
```

### 시작 타입
모든 스레드는 `taskType = "raw"`에서 시작합니다. 첫 번째 레이어는 `"raw"`를 입력 타입으로 받아야 합니다.

### 출력-입력 전달
각 레이어가 실행을 마치면, 해당 레이어의 첫 번째 출력 타입이 다음 레이어의 입력 타입(taskType)이 됩니다.

### 비활성 레이어 건너뛰기
레이어 목록에 있는 레이어가 비활성 상태이거나 존재하지 않으면 자동으로 건너뜁니다.

## 상태와 생명주기

```
  ┌───────┐
  │ Idle  │ ← 생성 시 기본 상태
  └───┬───┘
      │ 실행 시작
      ▼
  ┌─────────┐
  │ Running │ ← 레이어 순차 실행 중
  └───┬─────┘
      │
 ┌────┴─────┐
 ▼          ▼
┌───────────┐ ┌─────────┐
│ Completed │ │ Failed  │
└───────────┘ └─────────┘
```

## 활성화 상태

스레드는 활성/비활성 상태를 가집니다. `runAllThreads()` 실행 시 비활성 스레드는 제외됩니다.

## 다른 개념과의 관계

- **Layer**: 스레드는 실행할 레이어의 목록을 가짐. 순서대로 통과시키며 타입 체인을 형성
- **Worker**: 각 레이어 내의 워커들이 실제로 태스크를 수행. 스레드의 컨텍스트 프롬프트가 프롬프트 계층에 추가됨
- **Task**: 스레드 실행 시 각 레이어마다 내부적으로 태스크가 생성됨
- **Provider**: 워커 실행 시 제공자 설정을 사용하여 LLM API에 접근

## 코드 매핑

| 도메인 개념 | 코드 구현 | 위치 |
|------------|----------|------|
| Thread | `ThreadDefinition` 클래스 | `lib/data/models/app_models.dart` |
| Thread Status | `ThreadStatus` enum | `lib/data/models/app_models.dart` |
| DB 저장 | `Threads` 테이블 (PK: name) | `lib/data/database/app_database.dart` |
| 파일 수집 | `Scheduler.collectFilesFromPath()` | `lib/engine/scheduler.dart` |
| 스레드 실행 | `Scheduler.runThread()` | `lib/engine/scheduler.dart` |
