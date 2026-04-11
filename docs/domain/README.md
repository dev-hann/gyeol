# Gyeol 도메인 문서

Gyeol 시스템의 도메인 개념, 용어, 아키텍처, 코드 매핑을 관리하는 문서 모음.

## 파일 구조

```
docs/domain/
├── README.md                # 이 파일. 문서 구조 안내
├── glossary.md              # 전체 용어 사전 (한/영 + 정의)
├── architecture.md          # 기술 아키텍처 (레이어 구조, 데이터 흐름, 엔진 컴포넌트)
├── conventions.md           # 코드 컨벤션 (린트, 네이밍, TDD, 테마)
├── code-reference.md        # 코드-도메인 빠른 매핑 참조
└── concepts/                # 개별 도메인 개념 정의
    ├── task.md              # Task — 최소 처리 단위
    ├── layer.md             # Layer — 처리 단계 (타입드 I/O)
    ├── worker.md            # Worker — AI 에이전트 (프롬프트 계층)
    ├── thread.md            # Thread — 실행 파이프라인 (파일 수집 + 순차 실행)
    ├── provider.md          # Provider — LLM 제공자 추상화
    ├── pipeline.md          # Pipeline — 스케줄러/큐/메시지버스 협업
    └── chat.md              # Chat — 대화형 AI 도구 호출
```

## 각 파일의 역할

| 파일 | 대상 독자 | 역할 |
|------|----------|------|
| `glossary.md` | 전체 | 시스템에서 사용하는 모든 용어의 한/영 사전. 새 사람이나 AI가 빠르게 용어를 파악할 때 사용 |
| `concepts/*.md` | 전체 | 각 도메인 개념을 비즈니스 관점에서 정의. 정의, 속성, 생명주기, 규칙, 관계, 코드 매핑 포함 |
| `architecture.md` | 개발자 | 기술 아키텍처. 디렉토리 구조, 데이터 흐름, 엔진 컴포넌트 상세 |
| `conventions.md` | 개발자 | 코드 컨벤션. 린트, 네이밍, TDD 규칙, 테마 토큰 매핑 |
| `code-reference.md` | 개발자 | 도메인 개념↔코드(클래스/enum/테이블) 빠른 매핑 테이블 |

## 업데이트 규칙

- 코드 변경 시 `sync-domain-docs` 스킬에 따라 관련 문서 업데이트
- 개념 파일(`concepts/*.md`)은 비즈니스 관점 우선, 코드 매핑은 맨 아래 "코드 매핑" 섹션만
- 새 파일이 추가되거나 제거되면 이 README.md도 함께 업데이트
