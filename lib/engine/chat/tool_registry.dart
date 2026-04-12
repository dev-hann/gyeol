import 'dart:convert';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/model_fetcher.dart';

class ToolRegistry {
  static List<ToolDefinition> getAllTools() => _tools;

  static ToolDefinition? getToolByName(String name) {
    for (final tool in _tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  static Future<String> executeTool(
    String name,
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    try {
      return await switch (name) {
        'create_layer' => _createLayer(args, repo),
        'update_layer' => _updateLayer(args, repo),
        'delete_layer' => _deleteLayer(args, repo),
        'create_worker' => _createWorker(args, repo),
        'update_worker' => _updateWorker(args, repo),
        'delete_worker' => _deleteWorker(args, repo),
        'list_layers' => _listLayers(repo),
        'list_workers' => _listWorkers(args, repo),
        'list_threads' => _listThreads(repo),
        'create_thread' => _createThread(args, repo),
        'update_thread' => _updateThread(args, repo),
        'delete_thread' => _deleteThread(args, repo),
        'run_thread' => _runThread(args, repo),
        'get_status' => _getStatus(args, repo),
        'arrange_layers' => _arrangeLayers(repo),
        'list_providers' => _listProviders(repo),
        'present_choices' => jsonEncode(args),
        'confirm_action' => jsonEncode(args),
        'assign_worker' => _assignWorker(args, repo),
        'unassign_worker' => _unassignWorker(args, repo),
        'list_logs' => _listLogs(args, repo),
        'list_tasks' => _listTasks(args, repo),
        'get_queue_status' => _getQueueStatus(repo),
        'switch_provider' => _switchProvider(args, repo),
        'rename_conversation' => _renameConversation(args, repo),
        'search_messages' => _searchMessages(args, repo),
        'clear_conversation' => _clearConversation(args, repo),
        'export_conversation' => _exportConversation(args, repo),
        'get_worker_details' => _getWorkerDetails(args, repo),
        'submit_task' => _submitTask(args, repo),
        _ => jsonEncode({'error': 'Unknown tool: $name'}),
      };
    } on Object catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  static Future<String> _createLayer(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'create_layer: "name" must be a non-null String',
      });
    }
    if (args['inputTypes'] is! List) {
      return jsonEncode({'error': 'create_layer: "inputTypes" must be a List'});
    }
    if (args['outputTypes'] is! List) {
      return jsonEncode({
        'error': 'create_layer: "outputTypes" must be a List',
      });
    }
    final name = args['name'] as String;
    final inputTypes = (args['inputTypes'] as List)
        .map((e) => e as String)
        .toList();
    final outputTypes = (args['outputTypes'] as List)
        .map((e) => e as String)
        .toList();

    final layer = LayerDefinition(
      id: 0,
      name: name,
      inputTypes: inputTypes,
      outputTypes: outputTypes,
    );

    await repo.layers.saveLayer(layer);
    return jsonEncode({'success': true, 'message': 'Layer "$name" created'});
  }

  static Future<String> _updateLayer(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'update_layer: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final layers = await repo.layers.listLayers();
    final existing = layers.where((l) => l.name == name).firstOrNull;
    if (existing == null) {
      return jsonEncode({'error': 'Layer "$name" not found'});
    }

    final updated = existing.copyWith(
      inputTypes: args['inputTypes'] != null
          ? (args['inputTypes'] as List).map((e) => e as String).toList()
          : null,
      outputTypes: args['outputTypes'] != null
          ? (args['outputTypes'] as List).map((e) => e as String).toList()
          : null,
      layerPrompt: args['layerPrompt'] as String?,
      enabled: args['enabled'] as bool?,
    );

    await repo.layers.saveLayer(updated);
    return jsonEncode({'success': true, 'message': 'Layer "$name" updated'});
  }

  static Future<String> _deleteLayer(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'delete_layer: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final layers = await repo.layers.listLayers();
    final layer = layers.where((l) => l.name == name).firstOrNull;
    if (layer == null) {
      return jsonEncode({'error': 'Layer "$name" not found'});
    }
    await repo.layers.deleteLayer(layer.id);
    return jsonEncode({'success': true, 'message': 'Layer "$name" deleted'});
  }

  static Future<String> _createWorker(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'create_worker: "name" must be a non-null String',
      });
    }
    if (args['layerName'] is! String) {
      return jsonEncode({
        'error': 'create_worker: "layerName" must be a non-null String',
      });
    }
    if (args['systemPrompt'] is! String) {
      return jsonEncode({
        'error': 'create_worker: "systemPrompt" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final layerName = args['layerName'] as String;
    final systemPrompt = args['systemPrompt'] as String;
    final model = args['model'] as String?;
    final temperature = (args['temperature'] as num?)?.toDouble();
    final maxTokens = (args['maxTokens'] as num?)?.toInt();

    final layers = await repo.layers.listLayers();
    final layer = layers.where((l) => l.name == layerName).firstOrNull;
    if (layer == null) {
      return jsonEncode({'error': 'Layer "$layerName" not found'});
    }

    final worker = WorkerDefinition(
      id: 0,
      name: name,
      layerId: layer.id,
      systemPrompt: systemPrompt,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    await repo.workers.saveWorker(worker);
    return jsonEncode({'success': true, 'message': 'Worker "$name" created'});
  }

  static Future<String> _updateWorker(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'update_worker: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final existing = await repo.workers.getWorker(name);
    if (existing == null) {
      return jsonEncode({'error': 'Worker "$name" not found'});
    }

    int? newLayerId;
    if (args['layerName'] != null) {
      final layers = await repo.layers.listLayers();
      final layer = layers
          .where((l) => l.name == args['layerName'])
          .firstOrNull;
      if (layer == null) {
        return jsonEncode({'error': 'Layer "${args['layerName']}" not found'});
      }
      newLayerId = layer.id;
    }

    final updated = existing.copyWith(
      layerId: newLayerId,
      systemPrompt: args['systemPrompt'] as String?,
      model: args['model'] as String?,
      temperature: (args['temperature'] as num?)?.toDouble(),
      maxTokens: (args['maxTokens'] as num?)?.toInt(),
      enabled: args['enabled'] as bool?,
    );

    await repo.workers.saveWorker(updated);
    return jsonEncode({'success': true, 'message': 'Worker "$name" updated'});
  }

  static Future<String> _deleteWorker(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'delete_worker: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final worker = await repo.workers.getWorker(name);
    if (worker == null) {
      return jsonEncode({'error': 'Worker "$name" not found'});
    }
    await repo.workers.deleteWorker(worker.id);
    return jsonEncode({'success': true, 'message': 'Worker "$name" deleted'});
  }

  static Future<String> _listLayers(AppRepository repo) async {
    final layers = await repo.layers.listLayers();
    final workers = await repo.workers.listWorkers();
    final result = layers
        .map(
          (l) => {
            'name': l.name,
            'inputTypes': l.inputTypes,
            'outputTypes': l.outputTypes,
            'workerNames': workers
                .where((w) => w.layerId == l.id)
                .map((w) => w.name)
                .toList(),
            'order': l.order,
            'enabled': l.enabled,
          },
        )
        .toList();
    return jsonEncode({'layers': result});
  }

  static Future<String> _listWorkers(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    final workers = await repo.workers.listWorkers();
    final layers = await repo.layers.listLayers();
    final idToName = <int, String>{for (final l in layers) l.id: l.name};

    final filtered = args['layerName'] != null
        ? () {
            final targetLayer = layers
                .where((l) => l.name == args['layerName'])
                .firstOrNull;
            if (targetLayer == null) return <WorkerDefinition>[];
            return workers.where((w) => w.layerId == targetLayer.id).toList();
          }()
        : workers;
    final result = filtered
        .map(
          (w) => {
            'name': w.name,
            'layerName': idToName[w.layerId] ?? '',
            'model': w.model,
            'temperature': w.temperature,
            'maxTokens': w.maxTokens,
            'enabled': w.enabled,
          },
        )
        .toList();
    return jsonEncode({'workers': result});
  }

  static Future<String> _listThreads(AppRepository repo) async {
    final threads = await repo.threads.listThreads();
    final layers = await repo.layers.listLayers();
    final idToName = <int, String>{for (final l in layers) l.id: l.name};
    final result = threads
        .map(
          (t) => {
            'name': t.name,
            'path': t.path,
            'layerNames': t.layerIds.map((id) => idToName[id] ?? '').toList(),
            'contextPrompt': t.contextPrompt,
            'status': t.status.name,
            'enabled': t.enabled,
          },
        )
        .toList();
    return jsonEncode({'threads': result});
  }

  static Future<String> _createThread(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'create_thread: "name" must be a non-null String',
      });
    }
    if (args['path'] is! String) {
      return jsonEncode({
        'error': 'create_thread: "path" must be a non-null String',
      });
    }
    if (args['layerNames'] is! List) {
      return jsonEncode({
        'error': 'create_thread: "layerNames" must be a List',
      });
    }
    final name = args['name'] as String;
    final path = args['path'] as String;
    final layerNames = (args['layerNames'] as List)
        .map((e) => e as String)
        .toList();

    final layers = await repo.layers.listLayers();
    final nameToId = <String, int>{for (final l in layers) l.name: l.id};
    final layerIds = layerNames
        .map((n) => nameToId[n])
        .whereType<int>()
        .toList();

    final thread = ThreadDefinition(
      id: 0,
      name: name,
      path: path,
      layerIds: layerIds,
    );

    await repo.threads.saveThread(thread);
    return jsonEncode({'success': true, 'message': 'Thread "$name" created'});
  }

  static Future<String> _runThread(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'run_thread: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final thread = await repo.threads.getThread(name);
    if (thread == null) {
      return jsonEncode({'error': 'Thread "$name" not found'});
    }

    final layers = await repo.layers.listLayers();
    final idToName = <int, String>{for (final l in layers) l.id: l.name};

    return jsonEncode({
      'status': 'queued',
      'thread': thread.name,
      'layerNames': thread.layerIds.map((id) => idToName[id] ?? '').toList(),
    });
  }

  static Future<String> _updateThread(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'update_thread: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final existing = await repo.threads.getThread(name);
    if (existing == null) {
      return jsonEncode({'error': 'Thread "$name" not found'});
    }

    List<int>? newLayerIds;
    if (args['layerNames'] != null) {
      final layerNames = (args['layerNames'] as List)
          .map((e) => e as String)
          .toList();
      final layers = await repo.layers.listLayers();
      final nameToId = <String, int>{for (final l in layers) l.name: l.id};
      newLayerIds = layerNames
          .map((n) => nameToId[n])
          .whereType<int>()
          .toList();
    }

    final updated = existing.copyWith(
      path: args['path'] as String?,
      layerIds: newLayerIds,
      contextPrompt: args['contextPrompt'] as String?,
      enabled: args['enabled'] as bool?,
    );

    await repo.threads.saveThread(updated);
    return jsonEncode({'success': true, 'message': 'Thread "$name" updated'});
  }

  static Future<String> _deleteThread(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'delete_thread: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final thread = await repo.threads.getThread(name);
    if (thread == null) {
      return jsonEncode({'error': 'Thread "$name" not found'});
    }
    await repo.threads.deleteThread(thread.id);
    return jsonEncode({'success': true, 'message': 'Thread "$name" deleted'});
  }

  static Future<String> _assignWorker(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['workerName'] is! String) {
      return jsonEncode({
        'error': 'assign_worker: "workerName" must be a non-null String',
      });
    }
    if (args['layerName'] is! String) {
      return jsonEncode({
        'error': 'assign_worker: "layerName" must be a non-null String',
      });
    }
    final workerName = args['workerName'] as String;
    final layerName = args['layerName'] as String;

    final layers = await repo.layers.listLayers();
    final layer = layers.where((l) => l.name == layerName).firstOrNull;
    if (layer == null) {
      return jsonEncode({'error': 'Layer "$layerName" not found'});
    }

    final worker = await repo.workers.getWorker(workerName);
    if (worker == null) {
      return jsonEncode({'error': 'Worker "$workerName" not found'});
    }

    if (worker.layerId == layer.id) {
      return jsonEncode({
        'error': 'Worker "$workerName" already assigned to layer "$layerName"',
      });
    }

    await repo.workers.saveWorker(worker.copyWith(layerId: layer.id));
    return jsonEncode({
      'success': true,
      'message': 'Worker "$workerName" assigned to layer "$layerName"',
    });
  }

  static Future<String> _unassignWorker(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['workerName'] is! String) {
      return jsonEncode({
        'error': 'unassign_worker: "workerName" must be a non-null String',
      });
    }
    if (args['layerName'] is! String) {
      return jsonEncode({
        'error': 'unassign_worker: "layerName" must be a non-null String',
      });
    }
    final workerName = args['workerName'] as String;
    final layerName = args['layerName'] as String;

    final worker = await repo.workers.getWorker(workerName);
    if (worker == null) {
      return jsonEncode({'error': 'Worker "$workerName" not found'});
    }

    final layers = await repo.layers.listLayers();
    final layer = layers.where((l) => l.name == layerName).firstOrNull;
    if (layer == null || worker.layerId != layer.id) {
      return jsonEncode({
        'error': 'Worker "$workerName" not assigned to layer "$layerName"',
      });
    }

    return jsonEncode({
      'error':
          'Cannot unassign worker from layer — layerId is required. '
          'Use assign_worker to reassign.',
    });
  }

  static Future<String> _listLogs(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    final logs = await repo.logs.listExecutionLogs(
      taskId: (args['taskId'] as num?)?.toInt(),
      limit: (args['limit'] as num?)?.toInt() ?? 50,
    );
    final workers = await repo.workers.listWorkers();
    final workerIdToName = <int, String>{for (final w in workers) w.id: w.name};
    final result = logs
        .map(
          (l) => {
            'id': l.id,
            'taskId': l.taskId,
            'workerName': l.workerId != null
                ? workerIdToName[l.workerId] ?? 'unknown'
                : null,
            'status': l.status,
            'message': l.message,
            'createdAt': l.createdAt,
          },
        )
        .toList();
    return jsonEncode({'logs': result});
  }

  static Future<String> _listTasks(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 50;
    final tasks = await repo.tasks.listTasks(limit: limit);
    final layers = await repo.layers.listLayers();
    final workers = await repo.workers.listWorkers();
    final idToName = <int, String>{for (final l in layers) l.id: l.name};
    final workerIdToName = <int, String>{for (final w in workers) w.id: w.name};
    final result = tasks
        .map(
          (t) => {
            'id': t.id,
            'taskType': t.taskType,
            'priority': t.priority.name,
            'status': t.status.name,
            'layerName': t.layerId != null ? idToName[t.layerId] : null,
            'workerName': t.workerId != null
                ? workerIdToName[t.workerId]
                : null,
            'retryCount': t.retryCount,
            'depth': t.depth,
            'createdAt': t.createdAt,
          },
        )
        .toList();
    return jsonEncode({'tasks': result, 'count': result.length});
  }

  static Future<String> _getQueueStatus(AppRepository repo) async {
    final queueSize = await repo.tasks.getQueueSize();
    final layers = await repo.layers.listLayers();
    final workers = await repo.workers.listWorkers();
    final threads = await repo.threads.listThreads();
    return jsonEncode({
      'queueSize': queueSize,
      'layers': layers.length,
      'workers': workers.length,
      'threads': threads.length,
    });
  }

  static Future<String> _switchProvider(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['provider'] is! String) {
      return jsonEncode({
        'error': 'switch_provider: "provider" must be a non-null String',
      });
    }
    final providerName = args['provider'] as String;
    final providerType = switch (providerName.toLowerCase()) {
      'openai' => ProviderType.openAI,
      'anthropic' => ProviderType.anthropic,
      'ollama' => ProviderType.ollama,
      'custom' => ProviderType.custom,
      _ => null,
    };

    if (providerType == null) {
      return jsonEncode({
        'error':
            'Unknown provider "$providerName". '
            'Use: openai, anthropic, ollama, or custom',
      });
    }

    final settings = await repo.settings.getSettings();
    if (!settings.isProviderConfigured(providerType)) {
      return jsonEncode({
        'error': 'Provider "$providerName" is not configured',
      });
    }

    final updated = settings.copyWith(activeProvider: providerType);
    await repo.settings.saveSettings(updated);
    return jsonEncode({
      'success': true,
      'activeProvider': providerName,
      'model': updated.active.model,
    });
  }

  static Future<String> _arrangeLayers(AppRepository repo) async {
    await repo.graph.saveNodePositions({});
    return jsonEncode({
      'success': true,
      'message': 'Layer positions reset — auto-layout will apply on next sync',
    });
  }

  static Future<String> _getStatus(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['threadName'] != null) {
      final name = args['threadName'] as String;
      final thread = await repo.threads.getThread(name);
      if (thread == null) {
        return jsonEncode({'error': 'Thread "$name" not found'});
      }
      final layers = await repo.layers.listLayers();
      final idToName = <int, String>{for (final l in layers) l.id: l.name};
      return jsonEncode({
        'thread': thread.name,
        'status': thread.status.name,
        'layerNames': thread.layerIds.map((id) => idToName[id] ?? '').toList(),
      });
    }

    final layers = await repo.layers.listLayers();
    final workers = await repo.workers.listWorkers();
    final threads = await repo.threads.listThreads();
    return jsonEncode({
      'layers': layers.length,
      'workers': workers.length,
      'threads': threads.length,
    });
  }

  static final List<ToolDefinition> _tools = [
    const ToolDefinition(
      name: 'create_layer',
      description:
          'Create a new processing layer with typed inputs and outputs',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Unique name for the layer',
          },
          'inputTypes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of input data types this layer accepts',
          },
          'outputTypes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of output data types this layer produces',
          },
        },
        'required': ['name', 'inputTypes', 'outputTypes'],
      },
    ),
    const ToolDefinition(
      name: 'update_layer',
      description: "Update an existing layer's configuration",
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the layer to update',
          },
          'inputTypes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'New input types (optional)',
          },
          'outputTypes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'New output types (optional)',
          },
          'layerPrompt': {
            'type': 'string',
            'description':
                'Layer-level prompt injected during '
                'thread execution (optional)',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'Enable or disable the layer (optional)',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'delete_layer',
      description: 'Delete a layer by name',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the layer to delete',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'create_worker',
      description: 'Create a new AI worker assigned to a layer',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Unique name for the worker',
          },
          'layerName': {
            'type': 'string',
            'description': 'Name of the layer to assign this worker to',
          },
          'systemPrompt': {
            'type': 'string',
            'description': 'System prompt for the AI worker',
          },
          'model': {
            'type': 'string',
            'description': 'AI model to use (optional)',
          },
          'temperature': {
            'type': 'number',
            'description': 'Sampling temperature 0-1 (optional)',
          },
          'maxTokens': {
            'type': 'integer',
            'description': 'Maximum tokens in response (optional)',
          },
        },
        'required': ['name', 'layerName', 'systemPrompt'],
      },
    ),
    const ToolDefinition(
      name: 'update_worker',
      description: "Update an existing worker's configuration",
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the worker to update',
          },
          'layerName': {
            'type': 'string',
            'description': 'Reassign worker to a different layer (optional)',
          },
          'systemPrompt': {
            'type': 'string',
            'description': 'New system prompt (optional)',
          },
          'model': {'type': 'string', 'description': 'New AI model (optional)'},
          'temperature': {
            'type': 'number',
            'description': 'Sampling temperature 0-1 (optional)',
          },
          'maxTokens': {
            'type': 'integer',
            'description': 'Maximum tokens in response (optional)',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'Enable or disable the worker (optional)',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'delete_worker',
      description: 'Delete a worker by name',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the worker to delete',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'list_layers',
      description: 'List all registered layers with their configuration',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    const ToolDefinition(
      name: 'list_workers',
      description: 'List all workers, optionally filtered by layer',
      parameters: {
        'type': 'object',
        'properties': {
          'layerName': {
            'type': 'string',
            'description': 'Filter workers by layer name (optional)',
          },
        },
      },
    ),
    const ToolDefinition(
      name: 'list_threads',
      description: 'List all configured execution threads',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    const ToolDefinition(
      name: 'create_thread',
      description:
          'Create a new execution thread with a file path and ordered layers',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Unique name for the thread',
          },
          'path': {
            'type': 'string',
            'description': 'File system path to process',
          },
          'layerNames': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Ordered list of layer names to execute',
          },
        },
        'required': ['name', 'path', 'layerNames'],
      },
    ),
    const ToolDefinition(
      name: 'run_thread',
      description:
          'Execute a thread by name, processing files through its layers',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the thread to run',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'arrange_layers',
      description:
          'Reset all layer positions and apply connection-based auto-layout',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    const ToolDefinition(
      name: 'get_status',
      description: 'Get system status or status of a specific thread',
      parameters: {
        'type': 'object',
        'properties': {
          'threadName': {
            'type': 'string',
            'description': 'Thread name to check status for (optional)',
          },
        },
      },
    ),
    const ToolDefinition(
      name: 'list_providers',
      description:
          'List all configured AI providers and their available models. '
          'Use this when the user asks about available models, providers, '
          'or wants to know what AI models they can use.',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    const ToolDefinition(
      name: 'present_choices',
      description:
          'Present a list of choices to the user as clickable buttons. '
          'Use this when the user needs to select from multiple options, '
          'such as choosing a model, picking a configuration, or selecting '
          'from a list of items. The UI will render clickable choice chips. '
          'When the user clicks a choice, it will be sent back as their '
          'response.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Title/question to display above the choices',
          },
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of choice options to display',
          },
        },
        'required': ['title', 'options'],
      },
    ),
    const ToolDefinition(
      name: 'confirm_action',
      description:
          'Present a confirmation dialog to the user before executing '
          'a potentially destructive or important action. '
          'Use this BEFORE calling delete operations, batch changes, '
          'or any action that significantly modifies the system. '
          'The UI will show approve/reject buttons. '
          'Wait for the user response before proceeding.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Title of the action to confirm',
          },
          'description': {
            'type': 'string',
            'description': 'Detailed description of what will happen',
          },
          'action': {
            'type': 'string',
            'description': 'The action identifier (e.g. delete_worker)',
          },
        },
        'required': ['title', 'description', 'action'],
      },
    ),
    const ToolDefinition(
      name: 'update_thread',
      description: "Update an existing thread's configuration",
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the thread to update',
          },
          'path': {
            'type': 'string',
            'description': 'New file system path (optional)',
          },
          'layerNames': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'New ordered list of layer names (optional)',
          },
          'contextPrompt': {
            'type': 'string',
            'description':
                'Context prompt for thread execution '
                '(optional, set to empty string to clear)',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'Enable or disable the thread (optional)',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'delete_thread',
      description: 'Delete a thread by name',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the thread to delete',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'assign_worker',
      description: 'Assign an existing worker to a layer',
      parameters: {
        'type': 'object',
        'properties': {
          'workerName': {
            'type': 'string',
            'description': 'Name of the worker to assign',
          },
          'layerName': {
            'type': 'string',
            'description': 'Name of the layer to assign the worker to',
          },
        },
        'required': ['workerName', 'layerName'],
      },
    ),
    const ToolDefinition(
      name: 'unassign_worker',
      description: 'Remove a worker from a layer',
      parameters: {
        'type': 'object',
        'properties': {
          'workerName': {
            'type': 'string',
            'description': 'Name of the worker to remove',
          },
          'layerName': {
            'type': 'string',
            'description': 'Name of the layer to remove the worker from',
          },
        },
        'required': ['workerName', 'layerName'],
      },
    ),
    const ToolDefinition(
      name: 'list_logs',
      description:
          'List execution logs showing worker run history, errors, and results',
      parameters: {
        'type': 'object',
        'properties': {
          'taskId': {
            'type': 'string',
            'description': 'Filter logs by task ID (optional)',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of logs to return (default 50)',
          },
        },
      },
    ),
    const ToolDefinition(
      name: 'list_tasks',
      description: 'List tasks in the processing queue',
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of tasks to return (default 50)',
          },
        },
      },
    ),
    const ToolDefinition(
      name: 'get_queue_status',
      description: 'Get the current task queue size and system summary',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    const ToolDefinition(
      name: 'switch_provider',
      description:
          'Switch the active AI provider. '
          'Use list_providers first to see available options.',
      parameters: {
        'type': 'object',
        'properties': {
          'provider': {
            'type': 'string',
            'description':
                'Provider name: openai, anthropic, ollama, or custom',
          },
        },
        'required': ['provider'],
      },
    ),
    const ToolDefinition(
      name: 'rename_conversation',
      description: 'Rename a chat conversation',
      parameters: {
        'type': 'object',
        'properties': {
          'conversationId': {
            'type': 'string',
            'description': 'ID of the conversation to rename',
          },
          'title': {
            'type': 'string',
            'description': 'New title for the conversation',
          },
        },
        'required': ['conversationId', 'title'],
      },
    ),
    const ToolDefinition(
      name: 'search_messages',
      description: 'Search chat messages by keyword',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search keyword to find in message content',
          },
          'conversationId': {
            'type': 'string',
            'description': 'Limit search to a specific conversation (optional)',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default 20)',
          },
        },
        'required': ['query'],
      },
    ),
    const ToolDefinition(
      name: 'clear_conversation',
      description: 'Delete all messages in a conversation',
      parameters: {
        'type': 'object',
        'properties': {
          'conversationId': {
            'type': 'string',
            'description': 'ID of the conversation to clear',
          },
        },
        'required': ['conversationId'],
      },
    ),
    const ToolDefinition(
      name: 'export_conversation',
      description: 'Export a conversation as markdown text',
      parameters: {
        'type': 'object',
        'properties': {
          'conversationId': {
            'type': 'string',
            'description': 'ID of the conversation to export',
          },
        },
        'required': ['conversationId'],
      },
    ),
    const ToolDefinition(
      name: 'get_worker_details',
      description:
          'Get detailed info about a specific worker including '
          'system prompt, model config, layer assignment, '
          'and recent execution logs',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the worker to get details for',
          },
        },
        'required': ['name'],
      },
    ),
    const ToolDefinition(
      name: 'submit_task',
      description:
          'Submit a custom task to the processing queue. '
          'The task will be picked up by workers assigned to matching layers.',
      parameters: {
        'type': 'object',
        'properties': {
          'taskType': {
            'type': 'string',
            'description': 'The type of task (e.g. "analysis", "review")',
          },
          'payload': {
            'type': 'object',
            'description': 'JSON object with task data',
          },
          'priority': {
            'type': 'string',
            'description':
                'Priority level: "low", "medium", "high" (default: "medium")',
          },
        },
        'required': ['taskType', 'payload'],
      },
    ),
  ];

  static Future<String> _renameConversation(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['conversationId'] is! String) {
      return jsonEncode({
        'error':
            'rename_conversation: "conversationId" must be a non-null String',
      });
    }
    if (args['title'] is! String) {
      return jsonEncode({
        'error': 'rename_conversation: "title" must be a non-null String',
      });
    }
    final conversationId = args['conversationId'] as String;
    final title = args['title'] as String;

    final convs = await repo.chat.listConversations();
    final existing = convs.where((c) => c.id == conversationId).firstOrNull;
    if (existing == null) {
      return jsonEncode({'error': 'Conversation "$conversationId" not found'});
    }

    await repo.chat.updateConversationTitle(conversationId, title);
    return jsonEncode({
      'success': true,
      'message': 'Conversation renamed to "$title"',
    });
  }

  static Future<String> _searchMessages(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['query'] is! String) {
      return jsonEncode({
        'error': 'search_messages: "query" must be a non-null String',
      });
    }
    final query = (args['query'] as String).toLowerCase();
    final conversationId = args['conversationId'] as String?;
    final limit = (args['limit'] as num?)?.toInt() ?? 20;

    final convs = await repo.chat.listConversations();
    final results = <Map<String, dynamic>>[];

    for (final conv in convs) {
      if (conversationId != null && conv.id != conversationId) continue;

      final messages = await repo.chat.listMessages(conv.id);
      for (final msg in messages) {
        if (results.length >= limit) break;
        if (msg.content.toLowerCase().contains(query)) {
          final preview = msg.content.length > 200
              ? '${msg.content.substring(0, 200)}...'
              : msg.content;
          results.add({
            'conversationId': msg.conversationId,
            'role': msg.role,
            'content': preview,
            'toolName': msg.toolName,
          });
        }
      }
    }

    return jsonEncode({'messages': results});
  }

  static Future<String> _clearConversation(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['conversationId'] is! String) {
      return jsonEncode({
        'error':
            'clear_conversation: "conversationId" must be a non-null String',
      });
    }
    final conversationId = args['conversationId'] as String;
    await repo.chat.clearMessages(conversationId);
    return jsonEncode({
      'success': true,
      'message': 'All messages cleared in conversation',
    });
  }

  static Future<String> _exportConversation(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['conversationId'] is! String) {
      return jsonEncode({
        'error':
            'export_conversation: "conversationId" must be a non-null String',
      });
    }
    final conversationId = args['conversationId'] as String;

    final convs = await repo.chat.listConversations();
    final conv = convs.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) {
      return jsonEncode({'error': 'Conversation "$conversationId" not found'});
    }

    final messages = await repo.chat.listMessages(conversationId);
    final buffer = StringBuffer()
      ..writeln('# ${conv.title}')
      ..writeln();

    for (final msg in messages) {
      final label = switch (msg.role) {
        'user' => '**User**',
        'assistant' => '**Assistant**',
        'tool' => '**Tool (${msg.toolName ?? 'unknown'})**',
        _ => '**${msg.role}**',
      };
      buffer
        ..writeln('$label: ${msg.content}')
        ..writeln();
    }

    return jsonEncode({'markdown': buffer.toString()});
  }

  static Future<String> _getWorkerDetails(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['name'] is! String) {
      return jsonEncode({
        'error': 'get_worker_details: "name" must be a non-null String',
      });
    }
    final name = args['name'] as String;
    final worker = await repo.workers.getWorker(name);
    if (worker == null) {
      return jsonEncode({'error': 'Worker "$name" not found'});
    }

    final layers = await repo.layers.listLayers();
    final idToName = <int, String>{for (final l in layers) l.id: l.name};

    final allLogs = await repo.logs.listExecutionLogs();
    final workerLogs = allLogs
        .where((l) => l.workerId == worker.id)
        .take(5)
        .map(
          (l) => {
            'id': l.id,
            'taskId': l.taskId,
            'status': l.status,
            'message': l.message,
            'createdAt': l.createdAt,
          },
        )
        .toList();

    return jsonEncode({
      'name': worker.name,
      'layerName': idToName[worker.layerId] ?? '',
      'systemPrompt': worker.systemPrompt,
      'model': worker.model,
      'temperature': worker.temperature,
      'maxTokens': worker.maxTokens,
      'enabled': worker.enabled,
      'recentLogs': workerLogs,
    });
  }

  static Future<String> _listProviders(AppRepository repo) async {
    final settings = await repo.settings.getSettings();
    final results = <Map<String, dynamic>>[];

    for (final entry in settings.configs.entries) {
      final providerType = entry.key;
      final config = entry.value;
      final isConfigured = config.isConfigured;

      var models = <String>[];
      if (isConfigured) {
        try {
          models = await ModelFetcher.fetchModels(
            provider: providerType,
            apiKey: switch (config) {
              OpenAIConfig(:final apiKey) => apiKey,
              AnthropicConfig(:final apiKey) => apiKey,
              CustomConfig(:final apiKey) => apiKey,
              _ => null,
            },
            baseUrl: switch (config) {
              OllamaConfig(:final baseUrl) => baseUrl,
              CustomConfig(:final baseUrl) => baseUrl,
              _ => null,
            },
            apiFormat: config is CustomConfig ? config.apiFormat : null,
          );
        } on Object {
          models = [];
        }
      }

      results.add({
        'provider': providerType.name,
        'is_configured': isConfigured,
        'current_model': config.model,
        'available_models': models,
        'is_active': providerType == settings.activeProvider,
      });
    }

    return const JsonEncoder.withIndent('  ').convert(results);
  }

  static Future<String> _submitTask(
    Map<String, dynamic> args,
    AppRepository repo,
  ) async {
    if (args['taskType'] is! String) {
      return jsonEncode({
        'error': 'submit_task: "taskType" must be a non-null String',
      });
    }
    final taskType = args['taskType'] as String;
    final rawPayload = args['payload'];
    if (rawPayload is! Map<String, dynamic>) {
      return jsonEncode({
        'error': 'submit_task: "payload" must be a Map<String, dynamic>',
      });
    }
    final payload = rawPayload;
    final priorityStr = args['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (p) => p.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    final task = AppTask.create(taskType, payload, priority);
    await repo.tasks.saveTask(task);
    return jsonEncode({
      'success': true,
      'taskId': task.uuid,
      'status': 'queued',
    });
  }
}
