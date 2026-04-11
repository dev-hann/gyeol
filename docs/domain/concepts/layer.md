# Layer (레이어)

## 정의

레이어는 Gyeol 파이프라인에서 **데이터를 변환하는 처리 단계**입니다.

각 레이어는 자신이 수용할 수 있는 **입력 타입**과 생성하는 **출력 타입**을 선언합니다. 스케줄러는 태스크의 타입과 레이어의 입력 타입을 매칭하여 어떤 레이어가 해당 태스크를 처리할지 결정합니다. 하나의 레이어는 여러 워커를 포함하며, 레이어 내의 워커들은 병렬로 실행됩니다.

## 핵심 속성

### 이름 (Name)
레이어의 고유 식별자입니다. 시스템 전체에서 중복될 수 없습니다.

### 입력 타입 (Input Types)
이 레이어가 수용할 수 있는 데이터 유형의 목록입니다. 스케줄러가 태스크를 매칭할 때 사용합니다. 예: `["raw"]`, `["analysis_result", "review_result"]`

### 출력 타입 (Output Types)
이 레이어가 생성하는 데이터 유형의 목록입니다. 파이프라인에서 다음 레이어의 입력 타입과 연결되는 고리 역할을 합니다.

### 순서 (Order)
파이프라인 내에서 레이어의 실행 순서입니다. 낮은 값이 먼저 실행됩니다. 스레드가 레이어를 순차 실행할 때 참조합니다.

## 타입 연결 메커니즘

레이어 간의 연결은 **타입 매칭**으로 이루어집니다:

```
Layer A:  inputTypes=["raw"]           outputTypes=["analysis_result"]
                                        │
                                        ▼ (타입 매칭)
Layer B:  inputTypes=["analysis_result"] outputTypes=["review_result"]
                                        │
                                        ▼ (타입 매칭)
Layer C:  inputTypes=["review_result"]  outputTypes=["final_output"]
```

이 방식으로 레이어 간의 **느슨한 결합**을 유지합니다. 레이어는 자신의 입력/출력 타입만 알 뿐, 다른 레이어의 존재를 알지 못합니다.

## 레이어 프롬프트

레이어에 공통 지침을 부여할 수 있습니다. 이 프롬프트는 해당 레이어의 모든 워커에게 추가됩니다. 예를 들어 "결과는 반드시 JSON 형식으로 출력하라" 같은 공통 규칙을 설정할 수 있습니다.

## 활성화 상태

레이어는 활성/비활성 상태를 가집니다. 비활성 레이어는 스케줄러의 매칭 대상에서 제외되어 실행되지 않습니다.

## 다른 개념과의 관계

- **Worker**: 레이어는 1개 이상의 워커를 포함함. 레이어로 라우팅된 태스크는 소속 워커들에게 병렬로 전달됨
- **Task**: 태스크의 taskType과 레이어의 inputTypes가 매칭되면 연결됨
- **Thread**: 스레드는 실행할 레이어의 이름 목록을 가짐. 순서대로 통과시키며, 각 단계에서 outputTypes → 다음 inputTypes로 타입을 전달
- **LayerRegistry**: 모든 레이어의 등록부. 스케줄러가 레이어를 찾을 때 사용

## 코드 매핑

| 도메인 개념 | 코드 구현 | 위치 |
|------------|----------|------|
| Layer | `LayerDefinition` 클래스 | `lib/data/models/app_models.dart` |
| Layer Registry | `LayerRegistry` 클래스 | `lib/engine/scheduler.dart` |
| DB 저장 | `Layers` 테이블 (PK: name) | `lib/data/database/app_database.dart` |
