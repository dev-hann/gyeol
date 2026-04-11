# Gyeol 코드 컨벤션

## 린트

- `very_good_analysis` strict 모드
- `implicit-casts: false`, `implicit-dynamic: false`
- 제외: `*.g.dart`, `*.freezed.dart`

## 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| 파일 | `snake_case.dart` | `task_queue.dart` |
| 클래스 | `PascalCase` | `AppTask`, `Scheduler` |
| 프로바이더 | `camelCaseProvider` | `tasksProvider` |
| 노티파이어 | `PascalCaseNotifier` | `TasksNotifier` |
| DB 테이블 클래스 | `PascalCase` (Table 확장) | `Tasks`, `Layers` |
| 생성된 데이터 클래스 | `PascalCase` 단수형 | `Task`, `Layer` |

## 모델 작성 규칙

- 수작성 모델 — `freezed`, `json_serializable` 미사용
- 모든 모델에 `const` 생성자 + `copyWith()` 메서드
- JSON 직렬화 필요 시 수동 `fromJson`/`toJson` 구현
- ID 생성: `Uuid().v4()`
- 타임스탬프: `DateTime.now().millisecondsSinceEpoch` (int)

## TDD

- Red-Green-Refactor 순서 엄격 준수
- `test/` 아래 `lib/` 구조 미러링
  - `lib/engine/scheduler.dart` → `test/engine/scheduler_test.dart`
- mockito로 외부 의존성 Mock
- HTTP 테스트: 실제 API 호출 금지, MockClient 사용
- Drift DB 테스트: `AppDatabase.forTesting()` (인메모리)
- `group()` / `test()` 구조, describe-it 스타일
- 예외 케이스 반드시 테스트

## 주석

- 주석 추가 금지 (사용자 요청 시 제외)
- `// ignore_for_file` 지시어만 예외

## 테마/디자인

- 다크 테마 단일 테마 (seed color `#6d5acf`)
- 모든 색상: `Theme.of(context).colorScheme.*` 사용
- `Colors.xxx` 직접 사용 금지
- `AppColors` 상수 또는 `colorScheme` 토큰만 허용

### 색상 매핑

| 하드코딩 | 올바른 사용 |
|----------|-------------|
| `Colors.red` | `colorScheme.error` |
| `Colors.green` | `colorScheme.primary` |
| `Colors.blue` | `colorScheme.primary` |
| `Colors.grey` | `colorScheme.outline` / `colorScheme.onSurfaceVariant` |
| `Colors.amber` | `colorScheme.tertiary` |

## 에이전트 분기

| 수정 영역 | 담당 에이전트 |
|-----------|--------------|
| `lib/engine/`, `lib/data/`, `lib/providers/` | dart-engineer |
| `lib/features/`, `lib/shared/`, `lib/core/` | flutter-engineer |

## 금지 사항

- pubspec.yaml 의존성 추가 (명시적 요청 없이)
- `.g.dart` 파일 수동 수정
- Drift 스키마(테이블 정의) 임의 변경
- 테스트에서 실제 HTTP API 호출
- 같은 파일 연속 수정 (1회 TDD 사이클 후 검증 필수)

## 문서 업데이트 규칙

- 도메인 모델(`lib/data/models/`) 변경 시 → `docs/domain/models.md` 동기화
- 아키텍처 구조 변경 시 → `docs/domain/architecture.md` 동기화
- 컨벤션 규칙 변경 시 → `docs/domain/conventions.md` 동기화
- 동기화는 `sync-domain-docs` 스킬 또는 `continuous-improve` 사이클에서 자동 수행
