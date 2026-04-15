import 'dart:io';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/layer_registry.dart';
import 'package:gyeol/engine/message_bus.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/provider_factory.dart';

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
    final allLayers = await _repo.layers.listLayers();
    _layerRegistry.setAll(allLayers);

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

      if (layerWorkers.isEmpty) {
        await _repo.tasks.saveTask(
          resolvedTask.copyWith(
            status: TaskStatus.failed,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        continue;
      }

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
    final settings = await _repo.settings.getSettings();
    if (!settings.active.isConfigured) {
      return [
        WorkerResult(
          success: false,
          error:
              'Provider(${settings.activeProvider.name})가 설정되지 않았습니다. '
              '설정에서 ${settings.activeProvider.name}을(를) 먼저 설정하세요.',
        ),
      ];
    }

    final threadLayers = await _repo.layers.listLayersByThread(thread.id);
    if (threadLayers.isEmpty) {
      return [
        WorkerResult(success: false, error: '스레드에 레이어가 없습니다. 레이어를 먼저 추가하세요.'),
      ];
    }

    final enabledLayers = threadLayers.where((l) => l.enabled).toList();
    if (enabledLayers.isEmpty) {
      return [
        WorkerResult(success: false, error: '활성화된 레이어가 없습니다. 레이어를 활성화하세요.'),
      ];
    }

    final allWorkers = await _repo.workers.listWorkers();

    final allResults = <WorkerResult>[];
    final files = await collectFilesFromPath(thread.path);

    var currentType = 'raw';

    for (final layer in threadLayers) {
      if (!layer.enabled) continue;

      final layerWorkers = allWorkers.where((w) => w.layerId == layer.id);

      if (layerWorkers.isEmpty) {
        allResults.add(
          WorkerResult(
            success: false,
            error: 'Layer "${layer.name}"에 워커가 없습니다.',
            layerName: layer.name,
          ),
        );
        continue;
      }

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
      ).copyWith(layerId: layer.id, threadId: thread.id);

      final updatedTask = task.copyWith(
        status: TaskStatus.running,
        threadId: thread.id,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.tasks.saveTask(updatedTask);
      final savedTask = await _repo.tasks.getTask(updatedTask.uuid);
      final resolvedThreadTask = savedTask ?? updatedTask;

      final layerFutures = <Future<WorkerResult>>[];
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
      final labeledResults = layerResults
          .map(
            (r) => WorkerResult(
              success: r.success,
              outputTasks: r.outputTasks,
              error: r.error,
              metadata: r.metadata,
              layerName: layer.name,
              workerName: r.workerName ?? r.metadata?['worker'] as String?,
            ),
          )
          .toList();
      allResults.addAll(labeledResults);

      if (layer.outputTypes.isNotEmpty) {
        currentType = layer.outputTypes.first;
      }

      for (final result in labeledResults) {
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
    LlmProvider? provider;
    try {
      final settings = await _repo.settings.getSettings();
      provider = _createProvider(settings);

      final systemParts = <String>[
        if (threadPrompt != null) threadPrompt,
        if (layerPrompt != null) layerPrompt,
        worker.systemPrompt,
      ];
      final systemMessage = systemParts.join('\n\n');

      final userMessage = 'Task: ${task.taskType}\nPayload: ${task.payload}';

      final response = await provider.generateWithSystem(
        systemMessage,
        userMessage,
      );

      final outputTask =
          AppTask.create('analysis_result', {
            'worker': worker.name,
            'response': response,
          }, task.priority).copyWith(
            depth: task.depth + 1,
            parentTaskId: task.id,
            threadId: task.threadId,
          );

      await _repo.logs.logExecution(
        taskId: task.id,
        workerId: worker.id,
        status: 'success',
      );

      return WorkerResult(
        success: true,
        outputTasks: [outputTask],
        metadata: {'worker': worker.name},
        workerName: worker.name,
      );
    } on Object catch (e) {
      await _repo.logs.logExecution(
        taskId: task.id,
        workerId: worker.id,
        status: 'failed',
        message: e.toString(),
      );

      return WorkerResult(
        success: false,
        error: e.toString(),
        workerName: worker.name,
      );
    } finally {
      provider?.close();
    }
  }

  LlmProvider _createProvider(ProviderSettings settings) {
    return createLlmProvider(settings);
  }
}
