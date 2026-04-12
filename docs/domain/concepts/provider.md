# Provider (제공자)

## 정의

제공자는 **LLM(대형 언어 모델) 서비스에 대한 추상화**입니다.

Gyeol은 여러 LLM 서비스(OpenAI, Anthropic, Ollama, 커스텀 엔드포인트)를 동일한 방식으로 사용할 수 있어야 합니다. 제공자는 각 서비스의 API 차이를 숨기고 통일된 인터페이스를 제공합니다.

## 지원 제공자

### OpenAI
OpenAI의 API를 사용합니다. API 키가 필요합니다.
- 기본 모델: `gpt-4o`
- 엔드포인트: `https://api.openai.com/v1/chat/completions`

### Anthropic
Anthropic의 API를 사용합니다. API 키가 필요합니다.
- 기본 모델: `claude-sonnet-4-20250514`
- 엔드포인트: `https://api.anthropic.com/v1/messages`

### Ollama
로컬에서 실행되는 Ollama 서버를 사용합니다. API 키가 필요 없습니다.
- 기본 모델: `llama3`
- 기본 URL: `http://localhost:11434`

### Custom
임의의 엔드포인트를 사용합니다. 세 가지 API 포맷 중 선택할 수 있습니다:
- **OpenAI 호환**: OpenAI와 동일한 요청/응답 형식
- **Anthropic 호환**: Anthropic과 동일한 요청/응답 형식
- **Ollama 호환**: Ollama와 동일한 요청/응답 형식

기본 URL과 API 키, 모델명을 직접 설정합니다.

## 핵심 속성

### API 키 (API Key)
OpenAI, Anthropic, Custom 제공자는 API 키가 필요합니다. Ollama는 로컬 실행이므로 키가 필요 없습니다.

### 모델 (Model)
사용할 LLM의 버전입니다. 각 제공자마다 사용 가능한 모델이 다릅니다.

### 생성 온도 (Temperature)
LLM 응답의 무작위성을 조절합니다 (0.0 ~ 1.0).
- 낮은 값(0.0~0.3): 결정적, 일관된 응답. 분석/분류 작업에 적합
- 중간 값(0.4~0.7): 균형잡힌 응답. 일반적인 작업에 적합
- 높은 값(0.8~1.0): 창의적, 다양한 응답. 브레인스토밍에 적합

### 최대 토큰 (Max Tokens)
LLM 한 번의 응답에 허용하는 최대 토큰 수입니다. 응답 길이를 제한하여 비용과 시간을 관리합니다.

## 설정 계층

설정은 두 수준에서 관리됩니다:

```
시스템 기본값 (ProviderSettings)
  ├── defaultTemperature: 0.7
  └── defaultMaxTokens: 4096
         │
         ▼ 워커별 오버라이드
WorkerDefinition
  ├── temperature: null → 기본값 사용
  ├── temperature: 0.2 → 오버라이드
  ├── maxTokens: null → 기본값 사용
  └── maxTokens: 8192 → 오버라이드
```

워커에 개별 temperature/maxTokens가 설정되어 있으면 그 값을 사용하고, 없으면 시스템 기본값을 사용합니다.

## 검증

`createLlmProvider()`는 활성 제공자가 구성되지 않은 경우(`apiKey` 또는 `baseUrl`이 비어 있음) `StateError`를 발생시킵니다. 이 검증은 실제 API 호출 전에 수행되어 잘못된 설정으로 인한 런타임 오류를 방지합니다.

## 모델 목록 조회

시스템은 각 제공자에서 사용 가능한 모델 목록을 동적으로 조회할 수 있습니다:
- OpenAI: API를 통해 모델 목록 조회
- Anthropic: 하드코딩된 모델 목록 사용
- Ollama: 로컬 API를 통해 설치된 모델 조회
- Custom: 설정된 API 포맷에 따라 적절한 방식으로 조회

## 다른 개념과의 관계

- **Worker**: 워커가 실행될 때 제공자 설정을 사용하여 LLM API에 접근
- **Thread**: 스레드 실행 시 각 워커가 제공자를 통해 LLM을 호출
- **Task**: 워커가 제공자를 통해 얻은 LLM 응답이 새 태스크의 페이로드가 됨

## 코드 매핑

| 도메인 개념 | 코드 구현 | 위치 |
|------------|----------|------|
| Provider | `LlmProvider` 추상 클래스 | `lib/providers/llm_provider.dart` |
| OpenAI | `OpenAIProvider` | `lib/providers/openai_provider.dart` |
| Anthropic | `AnthropicProvider` | `lib/providers/anthropic_provider.dart` |
| Ollama | `OllamaProvider` | `lib/providers/ollama_provider.dart` |
| Custom | `CustomProvider` | `lib/providers/custom_provider.dart` |
| Provider 설정 | `ProviderSettings` 클래스 | `lib/data/models/app_models.dart` |
| API 포맷 | `CustomApiFormat` enum | `lib/data/models/app_models.dart` |
| 모델 조회 | `ModelFetcher` | `lib/providers/model_fetcher.dart` |
| Provider 생성 | `createLlmProvider()` | `lib/providers/provider_factory.dart` |
