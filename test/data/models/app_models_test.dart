import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('AppTask', () {
    test('create factory sets id, timestamps, and pending status', () {
      final task = AppTask.create('parse', {'text': 'hi'}, TaskPriority.high);

      expect(task.id, isNotEmpty);
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
      final copied = original.copyWith(
        status: TaskStatus.running,
        workerName: 'w1',
      );

      expect(copied.id, original.id);
      expect(copied.taskType, original.taskType);
      expect(copied.status, TaskStatus.running);
      expect(copied.workerName, 'w1');
      expect(copied.priority, TaskPriority.medium);
    });

    test('priorityLabel returns correct labels', () {
      expect(
        const AppTask(
          id: 'a',
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
          id: 'a',
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
          id: 'a',
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
            id: 'a',
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

    test('tasks with different id are not equal', () {
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
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
        workerNames: ['w'],
      );
      expect(layer.order, 0);
      expect(layer.enabled, true);
    });

    test('copyWith overrides specified fields only', () {
      const layer = LayerDefinition(
        name: 'test',
        inputTypes: ['a'],
        outputTypes: ['b'],
        workerNames: ['w'],
        order: 1,
      );
      final copied = layer.copyWith(order: 5, enabled: false);

      expect(copied.name, 'test');
      expect(copied.inputTypes, ['a']);
      expect(copied.order, 5);
      expect(copied.enabled, false);
    });
  });

  group('WorkerDefinition', () {
    test('defaults enabled=true and optional fields null', () {
      const worker = WorkerDefinition(
        name: 'w',
        layerName: 'l',
        systemPrompt: 'prompt',
      );
      expect(worker.model, isNull);
      expect(worker.temperature, isNull);
      expect(worker.maxTokens, isNull);
      expect(worker.enabled, true);
    });

    test('copyWith overrides specified fields only', () {
      const worker = WorkerDefinition(
        name: 'w',
        layerName: 'l',
        systemPrompt: 'prompt',
        model: 'gpt-4',
      );
      final copied = worker.copyWith(model: 'claude', enabled: false);

      expect(copied.name, 'w');
      expect(copied.layerName, 'l');
      expect(copied.model, 'claude');
      expect(copied.enabled, false);
    });
  });

  group('ProviderSettings', () {
    test('defaults match expected values', () {
      const settings = ProviderSettings();
      expect(settings.provider, ProviderType.openAI);
      expect(settings.openaiApiKey, '');
      expect(settings.openaiModel, 'gpt-4o');
      expect(settings.anthropicApiKey, '');
      expect(settings.anthropicModel, 'claude-sonnet-4-20250514');
      expect(settings.ollamaBaseUrl, 'http://localhost:11434');
      expect(settings.ollamaModel, 'llama3');
      expect(settings.customBaseUrl, 'http://localhost:8080');
      expect(settings.customApiKey, '');
      expect(settings.customModel, '');
      expect(settings.customApiFormat, CustomApiFormat.openAICompatible);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
    });

    test('fromJson with all fields', () {
      final settings = ProviderSettings.fromJson({
        'provider': 'Anthropic',
        'openai_api_key': 'key1',
        'openai_model': 'gpt-4o-mini',
        'anthropic_api_key': 'key2',
        'anthropic_model': 'claude-3-opus',
        'ollama_base_url': 'http://host:1234',
        'ollama_model': 'mistral',
        'default_temperature': 0.5,
        'default_max_tokens': 2048,
      });
      expect(settings.provider, ProviderType.anthropic);
      expect(settings.openaiApiKey, 'key1');
      expect(settings.anthropicModel, 'claude-3-opus');
      expect(settings.defaultTemperature, 0.5);
      expect(settings.defaultMaxTokens, 2048);
    });

    test('fromJson defaults on empty map', () {
      final settings = ProviderSettings.fromJson({});
      expect(settings.provider, ProviderType.openAI);
      expect(settings.openaiModel, 'gpt-4o');
    });

    test('fromJson Ollama provider', () {
      final settings = ProviderSettings.fromJson({'provider': 'Ollama'});
      expect(settings.provider, ProviderType.ollama);
    });

    test('fromJson Custom provider', () {
      final settings = ProviderSettings.fromJson({
        'provider': 'Custom',
        'custom_base_url': 'http://my-server:1234',
        'custom_api_key': 'my-key',
        'custom_model': 'my-model',
        'custom_api_format': 'anthropic',
      });
      expect(settings.provider, ProviderType.custom);
      expect(settings.customBaseUrl, 'http://my-server:1234');
      expect(settings.customApiKey, 'my-key');
      expect(settings.customModel, 'my-model');
      expect(settings.customApiFormat, CustomApiFormat.anthropicCompatible);
    });

    test('fromJson Custom provider defaults', () {
      final settings = ProviderSettings.fromJson({'provider': 'Custom'});
      expect(settings.provider, ProviderType.custom);
      expect(settings.customApiFormat, CustomApiFormat.openAICompatible);
      expect(settings.customBaseUrl, 'http://localhost:8080');
    });

    test('toJson round-trips through fromJson', () {
      const original = ProviderSettings(
        provider: ProviderType.anthropic,
        openaiApiKey: 'abc',
        openaiModel: 'gpt-4',
        anthropicApiKey: 'def',
        anthropicModel: 'claude-3',
        ollamaBaseUrl: 'http://x:1',
        ollamaModel: 'llama2',
        customBaseUrl: 'http://custom:9999',
        customApiKey: 'ck',
        customModel: 'cm',
        customApiFormat: CustomApiFormat.ollamaCompatible,
        defaultTemperature: 0.3,
        defaultMaxTokens: 1024,
      );
      final json = original.toJson();
      final restored = ProviderSettings.fromJson(json);

      expect(restored.provider, original.provider);
      expect(restored.openaiApiKey, original.openaiApiKey);
      expect(restored.openaiModel, original.openaiModel);
      expect(restored.anthropicApiKey, original.anthropicApiKey);
      expect(restored.anthropicModel, original.anthropicModel);
      expect(restored.ollamaBaseUrl, original.ollamaBaseUrl);
      expect(restored.ollamaModel, original.ollamaModel);
      expect(restored.customBaseUrl, original.customBaseUrl);
      expect(restored.customApiKey, original.customApiKey);
      expect(restored.customModel, original.customModel);
      expect(restored.customApiFormat, original.customApiFormat);
      expect(restored.defaultTemperature, original.defaultTemperature);
      expect(restored.defaultMaxTokens, original.defaultMaxTokens);
    });

    test('copyWith overrides specified fields only', () {
      const original = ProviderSettings();
      final copied = original.copyWith(
        provider: ProviderType.ollama,
        ollamaModel: 'mistral',
      );
      expect(copied.provider, ProviderType.ollama);
      expect(copied.ollamaModel, 'mistral');
      expect(copied.openaiModel, 'gpt-4o');
    });
  });
}
