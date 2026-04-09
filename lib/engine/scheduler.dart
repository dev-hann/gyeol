import 'dart:io';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';

class LayerRegistry {
  final List<LayerDefinition> _layers = [];

  void register(LayerDefinition layer) {
    _layers
      ..removeWhere((l) => l.name == layer.name)
      ..add(layer)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void remove(String name) {
    _layers.removeWhere((l) => l.name == name);
  }

  void setAll(List<LayerDefinition> layers) {
    _layers
      ..clear()
      ..addAll(layers)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<LayerDefinition> findByInputType(String taskType) {
    return _layers
        .where((l) => l.enabled && l.inputTypes.contains(taskType))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

class MessageBus {
  final Map<String, List<void Function(AppTask)>> _subscribers = {};

  void publish(AppTask task) {
    final specific = _subscribers[task.taskType] ?? [];
    final wildcard = _subscribers['*'] ?? [];
    for (final handler in [...specific, ...wildcard]) {
      handler(task);
    }
  }

  void subscribe(String taskType, void Function(AppTask) handler) {
    _subscribers.putIfAbsent(taskType, () => []).add(handler);
  }
}

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

  String submit(AppTask task) {
    _queue.push(task);
    return task.id;
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
        layerName: layer.name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.saveTask(updatedTask);

      for (final workerName in layer.workerNames) {
        if (taken >= maxConcurrent) break;
        futures.add(_executeWorker(updatedTask, workerName));
        taken++;
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
    if (thread.layerNames.isEmpty) return [];

    final allResults = <WorkerResult>[];
    final files = await collectFilesFromPath(thread.path);

    var currentType = 'raw';

    for (final layerName in thread.layerNames) {
      final layers = _layerRegistry.findByInputType(currentType);
      final layer = layers.where((l) => l.name == layerName).firstOrNull;
      if (layer == null || !layer.enabled) continue;

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
      ).copyWith(layerName: layer.name);

      final updatedTask = task.copyWith(
        status: TaskStatus.running,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.saveTask(updatedTask);

      final layerFutures = <Future<WorkerResult>>[];
      for (final workerName in layer.workerNames) {
        layerFutures.add(_executeWorker(updatedTask, workerName));
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

  Future<WorkerResult> _executeWorker(AppTask task, String workerName) async {
    final workerDef = await _repo.getWorker(workerName);
    if (workerDef == null) {
      return WorkerResult(
        success: false,
        error: "Worker '$workerName' not found",
      );
    }

    final settings = await _repo.getSettings();
    final provider = _createProvider(settings);

    final prompt =
        '${workerDef.systemPrompt}\n\n'
        'Task: ${task.taskType}\n'
        'Payload: ${task.payload}';

    try {
      final response = await provider.generate(prompt);

      final outputTask = AppTask.create('analysis_result', {
        'worker': workerName,
        'response': response,
      }, task.priority).copyWith(depth: task.depth + 1, parentTaskId: task.id);

      await _repo.logExecution(
        taskId: task.id,
        workerName: workerName,
        status: 'success',
      );

      return WorkerResult(
        success: true,
        outputTasks: [outputTask],
        metadata: {'worker': workerName},
      );
    } on Exception catch (e) {
      await _repo.logExecution(
        taskId: task.id,
        workerName: workerName,
        status: 'failed',
        message: e.toString(),
      );

      return WorkerResult(success: false, error: e.toString());
    } finally {
      provider.close();
    }
  }

  LlmProvider _createProvider(ProviderSettings settings) {
    return switch (settings.provider) {
      ProviderType.openAI => OpenAIProvider(
        apiKey: settings.openaiApiKey,
        model: settings.openaiModel,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
      ),
      ProviderType.anthropic => AnthropicProvider(
        apiKey: settings.anthropicApiKey,
        model: settings.anthropicModel,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
      ),
      ProviderType.ollama => OllamaProvider(
        baseUrl: settings.ollamaBaseUrl,
        model: settings.ollamaModel,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
      ),
      ProviderType.custom => CustomProvider(
        baseUrl: settings.customBaseUrl,
        model: settings.customModel,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
        apiFormat: settings.customApiFormat,
        apiKey: settings.customApiKey,
      ),
    };
  }
}
