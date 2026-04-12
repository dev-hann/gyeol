import 'dart:io';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/layer_registry.dart';
import 'package:gyeol/engine/message_bus.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';

const _maxExecutionDepth = 10;

class Scheduler {
  Scheduler({
    required TaskQueue queue,
    required LayerRegistry layerRegistry,
    required MessageBus messageBus,
    required AppRepository repo,
    this.maxConcurrent = 4,
  }) : _queue = queue,
       _layerRegistry = layerRegistry,
       _messageBus = messageBus,
       _repo = repo;
  final TaskQueue _queue;
  final LayerRegistry _layerRegistry;
  final MessageBus _messageBus;
  final AppRepository _repo;
  final int maxConcurrent;

  Future<int> submit(AppTask task) async {
    final id = await _repo.tasks.createTask(
      task.taskType,
      task.payload,
      task.priority,
    );
    _queue.push(task.copyWith(id: id));
    return id;
  }

  Future<List<WorkerResult>> runOnce() async {
    final results = <WorkerResult>[];
    final futures = <Future<WorkerResult>>[];
    var taken = 0;

    while (taken < maxConcurrent) {
      final task = _queue.pop();
      if (task == null) break;

      if (task.depth > _maxExecutionDepth) continue;

      final layers = _layerRegistry.findByInputType(task.taskType);
      if (layers.isEmpty) continue;

      final layer = layers.first;
      final updatedTask = task.copyWith(
        status: TaskStatus.running,
        layerId: layer.id,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.tasks.saveTask(updatedTask);
      final savedTask = await _repo.tasks.getTask(updatedTask.uuid);
      final resolvedTask = savedTask ?? updatedTask;

      final layerWorkers = (await _repo.workers.listWorkers())
          .where((w) => w.layerId == layer.id)
          .toList();

      for (final worker in layerWorkers) {
        taken++;
        futures.add(
          _executeWorker(resolvedTask, worker, layerPrompt: layer.layerPrompt),
        );
      }
    }

    final workerResults = await Future.wait(futures);

    for (final result in workerResults) {
      if (result.success) {
        for (final outputTask in result.outputTasks) {
          _queue.push(outputTask);
          _messageBus.publish(outputTask);
        }
      }
      results.add(result);
    }

    return results;
  }

  int get queueLength => _queue.length;

  static const _sourceExtensions = ['.dart', '.yaml', '.md', '.json', '.txt'];

  static Future<List<String>> collectFilesFromPath(
    String path, {
    List<String> extensions = _sourceExtensions,
  }) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];

    final files = <String>[];
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          if (extensions.any((ext) => entity.path.endsWith(ext))) {
            files.add(entity.path);
          }
        }
      }
    } on PathAccessException {
      return files;
    }
    return files..sort();
  }

  Future<List<WorkerResult>> runThread(ThreadDefinition thread) async {
    if (thread.layerIds.isEmpty) return [];

    final allResults = <WorkerResult>[];
    final files = await collectFilesFromPath(thread.path);

    var currentType = 'raw';

    final allLayers = await _repo.layers.listLayers();
    final layerById = <int, LayerDefinition>{
      for (final l in allLayers) l.id: l,
    };

    for (final layerId in thread.layerIds) {
      final layer = layerById[layerId];
      if (layer == null) continue;

      final matchingLayers = _layerRegistry.findByInputType(currentType);
      if (!matchingLayers.any((l) => l.id == layerId)) continue;
      if (!layer.enabled) continue;

      final payload = <String, dynamic>{
        'thread': thread.name,
        'path': thread.path,
        'currentType': currentType,
        if (files.isNotEmpty) 'files': files,
      };

      final task = AppTask.create(
        currentType,
        payload,
        TaskPriority.high,
      ).copyWith(layerId: layer.id);

      final updatedTask = task.copyWith(
        status: TaskStatus.running,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.tasks.saveTask(updatedTask);
      final savedTask = await _repo.tasks.getTask(updatedTask.uuid);
      final resolvedThreadTask = savedTask ?? updatedTask;

      final layerFutures = <Future<WorkerResult>>[];
      final layerWorkers = (await _repo.workers.listWorkers()).where(
        (w) => w.layerId == layer.id,
      );
      for (final worker in layerWorkers) {
        layerFutures.add(
          _executeWorker(
            resolvedThreadTask,
            worker,
            threadPrompt: thread.contextPrompt,
            layerPrompt: layer.layerPrompt,
          ),
        );
      }

      final layerResults = await Future.wait(layerFutures);
      allResults.addAll(layerResults);

      if (layer.outputTypes.isNotEmpty) {
        currentType = layer.outputTypes.first;
      }

      for (final result in layerResults) {
        if (result.success) {
          for (final outputTask in result.outputTasks) {
            _messageBus.publish(outputTask);
          }
        }
      }
    }

    return allResults;
  }

  Future<Map<String, List<WorkerResult>>> runAllThreads(
    List<ThreadDefinition> threads,
  ) async {
    final results = <String, List<WorkerResult>>{};
    for (final thread in threads) {
      if (!thread.enabled) continue;
      results[thread.name] = await runThread(thread);
    }
    return results;
  }

  Future<WorkerResult> _executeWorker(
    AppTask task,
    WorkerDefinition worker, {
    String? threadPrompt,
    String? layerPrompt,
  }) async {
    final settings = await _repo.settings.getSettings();
    final provider = _createProvider(settings);

    final systemParts = <String>[
      if (threadPrompt != null) threadPrompt,
      if (layerPrompt != null) layerPrompt,
      worker.systemPrompt,
    ];
    final systemMessage = systemParts.join('\n\n');

    final userMessage = 'Task: ${task.taskType}\nPayload: ${task.payload}';

    try {
      final response = await provider.generateWithSystem(
        systemMessage,
        userMessage,
      );

      final outputTask = AppTask.create('analysis_result', {
        'worker': worker.name,
        'response': response,
      }, task.priority).copyWith(depth: task.depth + 1, parentTaskId: task.id);

      await _repo.logs.logExecution(
        taskId: task.id,
        workerId: worker.id,
        status: 'success',
      );

      return WorkerResult(
        success: true,
        outputTasks: [outputTask],
        metadata: {'worker': worker.name},
      );
    } on Exception catch (e) {
      await _repo.logs.logExecution(
        taskId: task.id,
        workerId: worker.id,
        status: 'failed',
        message: e.toString(),
      );

      return WorkerResult(success: false, error: e.toString());
    } finally {
      provider.close();
    }
  }

  LlmProvider _createProvider(ProviderSettings settings) {
    final config = settings.active;
    return switch (config) {
      OpenAIConfig(:final apiKey) => OpenAIProvider(
        apiKey: apiKey,
        model: config.model,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
        topP: settings.defaultTopP,
        frequencyPenalty: settings.defaultFrequencyPenalty,
        presencePenalty: settings.defaultPresencePenalty,
        stopSequences: settings.defaultStopSequences,
        timeout: settings.defaultTimeout,
      ),
      AnthropicConfig(:final apiKey) => AnthropicProvider(
        apiKey: apiKey,
        model: config.model,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
        topP: settings.defaultTopP,
        stopSequences: settings.defaultStopSequences,
        timeout: settings.defaultTimeout,
      ),
      OllamaConfig(:final baseUrl) => OllamaProvider(
        baseUrl: baseUrl,
        model: config.model,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
        topP: settings.defaultTopP,
        timeout: settings.defaultTimeout,
      ),
      CustomConfig(:final baseUrl, :final apiKey, :final apiFormat) =>
        CustomProvider(
          baseUrl: baseUrl,
          model: config.model,
          temperature: settings.defaultTemperature,
          maxTokens: settings.defaultMaxTokens,
          topP: settings.defaultTopP,
          frequencyPenalty: settings.defaultFrequencyPenalty,
          presencePenalty: settings.defaultPresencePenalty,
          stopSequences: settings.defaultStopSequences,
          timeout: settings.defaultTimeout,
          apiFormat: apiFormat,
          apiKey: apiKey,
        ),
    };
  }
}
