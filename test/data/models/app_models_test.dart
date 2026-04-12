import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('AppTask', () {
    test('create factory sets timestamps and pending status', () {
      final task = AppTask.create('parse', {'text': 'hi'}, TaskPriority.high);

      expect(task.id, 0);
      expect(task.uuid, isNotEmpty);
      expect(task.taskType, 'parse');
      expect(task.payload, {'text': 'hi'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.retryCount, 0);
      expect(task.maxRetries, 3);
      expect(task.depth, 0);
      expect(task.parentTaskId, isNull);
      expect(task.createdAt, task.updatedAt);
    });

    test('copyWith overrides only specified fields', () {
      final original = AppTask.create('parse', null, TaskPriority.medium);
      final copied = original.copyWith(status: TaskStatus.running, workerId: 1);

      expect(copied.id, original.id);
      expect(copied.uuid, original.uuid);
      expect(copied.taskType, original.taskType);
      expect(copied.status, TaskStatus.running);
      expect(copied.workerId, 1);
      expect(copied.priority, TaskPriority.medium);
    });

    test('priorityLabel returns correct labels', () {
      expect(
        const AppTask(
          id: 0,
          uuid: 'a',
          taskType: 't',
          payload: null,
          priority: TaskPriority.high,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'High',
      );
      expect(
        const AppTask(
          id: 0,
          uuid: 'a',
          taskType: 't',
          payload: null,
          priority: TaskPriority.medium,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'Medium',
      );
      expect(
        const AppTask(
          id: 0,
          uuid: 'a',
          taskType: 't',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'Low',
      );
    });

    test('statusLabel returns correct labels', () {
      for (final entry in {
        TaskStatus.pending: 'Pending',
        TaskStatus.running: 'Running',
        TaskStatus.done: 'Done',
        TaskStatus.failed: 'Failed',
      }.entries) {
        expect(
          AppTask(
            id: 0,
            uuid: 'a',
            taskType: 't',
            payload: null,
            priority: TaskPriority.low,
            status: entry.key,
            createdAt: 0,
            updatedAt: 0,
          ).statusLabel,
          entry.value,
        );
      }
    });
  });

  group('AppTask payload type safety', () {
    test('payload accepts Map<String, Object>', () {
      final task = AppTask.create('parse', <String, Object>{
        'text': 'hi',
        'count': 42,
      }, TaskPriority.high);
      expect(task.payload, isA<Map<String, Object>>());
    });

    test('payload accepts null', () {
      final task = AppTask.create('parse', null, TaskPriority.low);
      expect(task.payload, isNull);
    });

    test('payload accepts List<String>', () {
      final task = AppTask.create('batch', <String>[
        'a',
        'b',
      ], TaskPriority.medium);
      expect(task.payload, isA<List<String>>());
    });

    test('copyWith preserves payload type', () {
      final task = AppTask.create('parse', <String, dynamic>{
        'key': 'val',
      }, TaskPriority.high);
      final copied = task.copyWith(status: TaskStatus.done);
      expect(copied.payload, isA<Map<String, dynamic>>());
      expect(copied.payload, task.payload);
    });
  });

  group('AppTask equality', () {
    test('tasks with same id are equal', () {
      final a = AppTask.create('parse', {'x': 1}, TaskPriority.high);
      final b = a.copyWith(status: TaskStatus.running);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('tasks with different uuid are not equal', () {
      final a = AppTask.create('parse', null, TaskPriority.low);
      final b = AppTask.create('parse', null, TaskPriority.low);
      expect(a, isNot(equals(b)));
    });

    test('can be used in Set', () {
      final a = AppTask.create('parse', null, TaskPriority.low);
      final set = {a, a.copyWith(status: TaskStatus.running)};
      expect(set, hasLength(1));
    });
  });

  group('WorkerResult', () {
    test('defaults to empty outputTasks', () {
      const result = WorkerResult(success: true);
      expect(result.outputTasks, isEmpty);
      expect(result.error, isNull);
      expect(result.metadata, isNull);
    });

    test('holds all fields', () {
      final result = WorkerResult(
        success: false,
        outputTasks: [AppTask.create('x', null, TaskPriority.low)],
        error: 'oops',
        metadata: {'code': 500},
      );
      expect(result.success, false);
      expect(result.outputTasks, hasLength(1));
      expect(result.error, 'oops');
      expect(result.metadata!['code'], 500);
    });
  });

  group('EvaluationResult', () {
    test('holds passed, score, and reasons', () {
      const result = EvaluationResult(
        passed: true,
        score: 0.95,
        reasons: ['good', 'complete'],
      );
      expect(result.passed, true);
      expect(result.score, 0.95);
      expect(result.reasons, ['good', 'complete']);
    });
  });

  group('LayerDefinition', () {
    test('defaults order=0 enabled=true', () {
      const layer = LayerDefinition(
        id: 1,
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
      );
      expect(layer.order, 0);
      expect(layer.enabled, true);
      expect(layer.layerPrompt, isNull);
    });

    test('holds layerPrompt', () {
      const layer = LayerDefinition(
        id: 2,
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
        layerPrompt: 'Extract key clauses',
      );
      expect(layer.layerPrompt, 'Extract key clauses');
    });

    test('copyWith overrides specified fields only', () {
      const layer = LayerDefinition(
        id: 3,
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
        order: 1,
        layerPrompt: 'old prompt',
      );
      final copied = layer.copyWith(order: 5, enabled: false);

      expect(copied.name, 'test');
      expect(copied.inputTypes, ['a']);
      expect(copied.order, 5);
      expect(copied.enabled, false);
      expect(copied.layerPrompt, 'old prompt');
    });

    test('copyWith can update layerPrompt', () {
      const layer = LayerDefinition(
        id: 4,
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
        layerPrompt: 'old',
      );
      final copied = layer.copyWith(layerPrompt: 'new');
      expect(copied.layerPrompt, 'new');
    });
  });

  group('WorkerDefinition', () {
    test('defaults enabled=true and optional fields null', () {
      const worker = WorkerDefinition(
        id: 1,
        name: 'w',
        layerId: 1,
        systemPrompt: 'prompt',
      );
      expect(worker.model, isNull);
      expect(worker.temperature, isNull);
      expect(worker.maxTokens, isNull);
      expect(worker.enabled, true);
    });

    test('copyWith overrides specified fields only', () {
      const worker = WorkerDefinition(
        id: 2,
        name: 'w',
        layerId: 1,
        systemPrompt: 'prompt',
        model: 'gpt-4',
      );
      final copied = worker.copyWith(model: 'claude', enabled: false);

      expect(copied.name, 'w');
      expect(copied.layerId, 1);
      expect(copied.model, 'claude');
      expect(copied.enabled, false);
    });
  });

  group('ProviderSettings', () {
    test('defaults match expected values', () {
      const settings = ProviderSettings();
      expect(settings.activeProvider, ProviderType.openAI);
      final openai = settings.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, '');
      expect(openai.model, 'gpt-4o');
      final anthropic =
          settings.configs[ProviderType.anthropic]! as AnthropicConfig;
      expect(anthropic.apiKey, '');
      expect(anthropic.model, 'claude-sonnet-4-20250514');
      final ollama = settings.configs[ProviderType.ollama]! as OllamaConfig;
      expect(ollama.baseUrl, '');
      expect(ollama.model, 'llama3');
      final custom = settings.configs[ProviderType.custom]! as CustomConfig;
      expect(custom.baseUrl, '');
      expect(custom.apiKey, '');
      expect(custom.model, '');
      expect(custom.apiFormat, CustomApiFormat.openAICompatible);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
      expect(settings.defaultTopP, 1.0);
      expect(settings.defaultFrequencyPenalty, 0.0);
      expect(settings.defaultPresencePenalty, 0.0);
      expect(settings.defaultStopSequences, <String>[]);
      expect(settings.defaultTimeout, 60000);
    });

    test('fromJson defaults on empty map', () {
      final settings = ProviderSettings.fromJson({});
      expect(settings.activeProvider, ProviderType.openAI);
      final openai = settings.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.model, 'gpt-4o');
    });

    test('fromJson with new configs format', () {
      final settings = ProviderSettings.fromJson({
        'activeProvider': 'Anthropic',
        'configs': {
          'openAI': {'type': 'openai', 'apiKey': 'k1', 'model': 'gpt-4o'},
          'anthropic': {
            'type': 'anthropic',
            'apiKey': 'k2',
            'model': 'claude-3-opus',
          },
          'ollama': {
            'type': 'ollama',
            'baseUrl': 'http://host:1234',
            'model': 'mistral',
          },
          'custom': {
            'type': 'custom',
            'baseUrl': '',
            'apiKey': '',
            'model': '',
            'apiFormat': 'openai',
          },
        },
        'default_temperature': 0.5,
        'default_max_tokens': 2048,
        'default_top_p': 0.9,
        'default_frequency_penalty': 0.5,
        'default_presence_penalty': 0.3,
        'default_stop_sequences': ['\n', 'END'],
        'default_timeout': 30000,
      });
      expect(settings.activeProvider, ProviderType.anthropic);
      final openai = settings.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, 'k1');
      final anthropic =
          settings.configs[ProviderType.anthropic]! as AnthropicConfig;
      expect(anthropic.model, 'claude-3-opus');
      final ollama = settings.configs[ProviderType.ollama]! as OllamaConfig;
      expect(ollama.baseUrl, 'http://host:1234');
      expect(settings.defaultTemperature, 0.5);
      expect(settings.defaultMaxTokens, 2048);
      expect(settings.defaultTopP, 0.9);
      expect(settings.defaultFrequencyPenalty, 0.5);
      expect(settings.defaultPresencePenalty, 0.3);
      expect(settings.defaultStopSequences, ['\n', 'END']);
      expect(settings.defaultTimeout, 30000);
    });

    test('toJson round-trips through fromJson', () {
      const original = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'abc', model: 'gpt-4'),
          ProviderType.anthropic: AnthropicConfig(
            apiKey: 'def',
            model: 'claude-3',
          ),
          ProviderType.ollama: OllamaConfig(
            baseUrl: 'http://x:1',
            model: 'llama2',
          ),
          ProviderType.custom: CustomConfig(
            baseUrl: 'http://custom:9999',
            apiKey: 'ck',
            model: 'cm',
            apiFormat: CustomApiFormat.ollamaCompatible,
          ),
        },
        defaultTemperature: 0.3,
        defaultMaxTokens: 1024,
        defaultTopP: 0.85,
        defaultFrequencyPenalty: 0.4,
        defaultPresencePenalty: 0.2,
        defaultStopSequences: ['\n', 'STOP'],
        defaultTimeout: 45000,
      );
      final json = original.toJson();
      final restored = ProviderSettings.fromJson(json);

      expect(restored.activeProvider, original.activeProvider);
      expect(restored.defaultTemperature, original.defaultTemperature);
      expect(restored.defaultMaxTokens, original.defaultMaxTokens);
      expect(restored.defaultTopP, original.defaultTopP);
      expect(
        restored.defaultFrequencyPenalty,
        original.defaultFrequencyPenalty,
      );
      expect(restored.defaultPresencePenalty, original.defaultPresencePenalty);
      expect(restored.defaultStopSequences, original.defaultStopSequences);
      expect(restored.defaultTimeout, original.defaultTimeout);

      final origOpenai = original.configs[ProviderType.openAI]! as OpenAIConfig;
      final restOpenai = restored.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(restOpenai.apiKey, origOpenai.apiKey);
      expect(restOpenai.model, origOpenai.model);

      final origAnthropic =
          original.configs[ProviderType.anthropic]! as AnthropicConfig;
      final restAnthropic =
          restored.configs[ProviderType.anthropic]! as AnthropicConfig;
      expect(restAnthropic.apiKey, origAnthropic.apiKey);
      expect(restAnthropic.model, origAnthropic.model);

      final origOllama = original.configs[ProviderType.ollama]! as OllamaConfig;
      final restOllama = restored.configs[ProviderType.ollama]! as OllamaConfig;
      expect(restOllama.baseUrl, origOllama.baseUrl);
      expect(restOllama.model, origOllama.model);

      final origCustom = original.configs[ProviderType.custom]! as CustomConfig;
      final restCustom = restored.configs[ProviderType.custom]! as CustomConfig;
      expect(restCustom.baseUrl, origCustom.baseUrl);
      expect(restCustom.apiKey, origCustom.apiKey);
      expect(restCustom.model, origCustom.model);
      expect(restCustom.apiFormat, origCustom.apiFormat);
    });

    test('copyWith overrides specified fields only', () {
      const original = ProviderSettings();
      final copied = original.copyWith(
        activeProvider: ProviderType.ollama,
        configs: {
          ...original.configs,
          ProviderType.ollama: const OllamaConfig(model: 'mistral'),
        },
      );
      expect(copied.activeProvider, ProviderType.ollama);
      final ollama = copied.configs[ProviderType.ollama]! as OllamaConfig;
      expect(ollama.model, 'mistral');
      final openai = copied.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.model, 'gpt-4o');
    });

    test('withConfig updates single provider config', () {
      const original = ProviderSettings();
      final updated = original.withConfig(
        const OpenAIConfig(apiKey: 'sk-test'),
      );
      final openai = updated.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, 'sk-test');
      expect(openai.model, 'gpt-4o');
      final anthropic =
          updated.configs[ProviderType.anthropic]! as AnthropicConfig;
      expect(anthropic.apiKey, '');
    });

    test('isProviderConfigured returns false for unconfigured defaults', () {
      const settings = ProviderSettings();
      expect(settings.isProviderConfigured(ProviderType.openAI), isFalse);
      expect(settings.isProviderConfigured(ProviderType.anthropic), isFalse);
      expect(settings.isProviderConfigured(ProviderType.ollama), isFalse);
      expect(settings.isProviderConfigured(ProviderType.custom), isFalse);
    });

    test('isProviderConfigured returns true when config is set', () {
      final settings = const ProviderSettings().withConfig(
        const OpenAIConfig(apiKey: 'sk-test'),
      );
      expect(settings.isProviderConfigured(ProviderType.openAI), isTrue);
    });

    test('active returns config for activeProvider', () {
      const settings = ProviderSettings(activeProvider: ProviderType.ollama);
      expect(settings.active, isA<OllamaConfig>());
    });
  });
}
