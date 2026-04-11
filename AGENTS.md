# Gyeol 프로젝트 룰

## 프로젝트 개요

Gyeol — AI Multi-Layer Worker System. Flutter/Dart 데스크톱 애플리케이션.
다중 LLM 제공자를 사용한 AI 처리 파이프라인 오케스트레이션.

## 프로젝트 구조

```
lib/
├── core/theme/          # 앱 테마 (다크 테마, seed #6d5acf)
├── data/
│   ├── database/        # Drift ORM (SQLite, schema v4)
│   ├── models/          # 전체 도메인 모델 (app_models.dart)
│   ├── repositories/    # DB 래퍼 (app_repository.dart)
│   └── providers/       # Riverpod Providers + Notifiers
├── engine/
│   ├── scheduler.dart   # Scheduler, LayerRegistry, MessageBus
│   ├── queue/           # TaskQueue (우선순위 큐)
│   └── chat/            # ChatService, ToolRegistry
├── providers/           # LLM Provider (OpenAI, Anthropic, Ollama, Custom)
├── features/            # UI 페이지 (layers, dashboard, workers, monitoring, threads, settings, chat)
├── shared/widgets/      # 공통 위젯 (AppShell, StatusBadge, PageHeader, StatCard, EmptyState)
└── main.dart

test/                    # lib/ 구조 미러링
docs/domain/             # 도메인 문서 (개념, 용어사전, 코드 매핑)
```

상세 아키텍처: `docs/domain/architecture.md`

## 빌드/테스트 명령

```bash
flutter analyze                                    # 정적 분석
flutter test                                       # 전체 테스트
dart format --set-exmit-if-changed lib/ test/       # 포맷 검사
dart run build_runner build --delete-conflicting-outputs  # Drift 코드 생성
```

코드 수정 후 반드시 `flutter analyze` + `flutter test` 실행하여 회귀 확인.

## 코드 스타일

- 린트: `very_good_analysis` strict 모드 (`implicit-casts: false`, `implicit-dynamic: false`)
- 파일: `snake_case.dart`, 클래스: `PascalCase`, 프로바이더: `camelCaseProvider`
- 모델: 수작성 `const` 생성자 + `copyWith()`, `freezed` 미사용
- 색상: 항상 `Theme.of(context).colorScheme.*` — `Colors.xxx` 직접 사용 금지
- 주석: 추가 금지 (사용자 요청 시 제외)

상세 컨벤션: `docs/domain/conventions.md`

## 워크플로우 규칙

### 코드 수정 후 필수 확인

1. `flutter analyze` + `flutter test` 실행하여 회귀 확인
2. 변경이 도메인 개념에 영향을 주면 `docs/domain/` 문서 업데이트
   - 동기화 기준과 절차: `.opencode/skills/sync-domain-docs/SKILL.md` 참조
   - 도메인 개념 문서: `docs/domain/concepts/*.md`

### 금지 사항

- `pubspec.yaml` 의존성 추가 (명시적 요청 없이)
- `.g.dart` 파일 수동 수정
- Drift 스키마(테이블 정의) 임의 변경
- 테스트에서 실제 HTTP API 호출

### 에이전트 분기

| 수정 영역 | 에이전트 |
|-----------|----------|
| `lib/engine/`, `lib/data/`, `lib/providers/` | dart-engineer |
| `lib/features/`, `lib/shared/`, `lib/core/` | flutter-engineer |

## 도메인 문서

`docs/domain/` — 프로젝트의 도메인 개념, 용어, 아키텍처, 코드 매핑.
`docs/domain/README.md`에서 전체 문서 목록과 구조를 확인할 것.
