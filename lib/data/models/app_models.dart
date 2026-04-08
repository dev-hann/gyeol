import 'package:uuid/uuid.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { pending, running, done, failed }

class AppTask {
  final String id;
  final String taskType;
  final dynamic payload;
  final TaskPriority priority;
  final TaskStatus status;
  final int retryCount;
  final int maxRetries;
  final int depth;
  final String? parentTaskId;
  final String? layerName;
  final String? workerName;
  final int createdAt;
  final int updatedAt;

  const AppTask({
    required this.id,
    required this.taskType,
    required this.payload,
    required this.priority,
    required this.status,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.depth = 0,
    this.parentTaskId,
    this.layerName,
    this.workerName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppTask.create(
    String taskType,
    dynamic payload,
    TaskPriority priority,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AppTask(
      id: const Uuid().v4(),
      taskType: taskType,
      payload: payload,
      priority: priority,
      status: TaskStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }

  AppTask copyWith({
    TaskStatus? status,
    String? layerName,
    String? workerName,
    int? retryCount,
    int? depth,
    String? parentTaskId,
    int? updatedAt,
  }) {
    return AppTask(
      id: id,
      taskType: taskType,
      payload: payload,
      priority: priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      depth: depth ?? this.depth,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      layerName: layerName ?? this.layerName,
      workerName: workerName ?? this.workerName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  String get statusLabel {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.running:
        return 'Running';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.failed:
        return 'Failed';
    }
  }
}

class WorkerResult {
  final bool success;
  final List<AppTask> outputTasks;
  final String? error;
  final Map<String, dynamic>? metadata;

  const WorkerResult({
    required this.success,
    this.outputTasks = const [],
    this.error,
    this.metadata,
  });
}

class EvaluationResult {
  final bool passed;
  final double score;
  final List<String> reasons;

  const EvaluationResult({
    required this.passed,
    required this.score,
    required this.reasons,
  });
}

class LayerDefinition {
  final String name;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final List<String> workerNames;
  final int order;
  final bool enabled;

  const LayerDefinition({
    required this.name,
    required this.inputTypes,
    required this.outputTypes,
    required this.workerNames,
    this.order = 0,
    this.enabled = true,
  });

  LayerDefinition copyWith({
    List<String>? inputTypes,
    List<String>? outputTypes,
    List<String>? workerNames,
    int? order,
    bool? enabled,
  }) {
    return LayerDefinition(
      name: name,
      inputTypes: inputTypes ?? this.inputTypes,
      outputTypes: outputTypes ?? this.outputTypes,
      workerNames: workerNames ?? this.workerNames,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}

class WorkerDefinition {
  final String name;
  final String layerName;
  final String systemPrompt;
  final String? model;
  final double? temperature;
  final int? maxTokens;
  final bool enabled;

  const WorkerDefinition({
    required this.name,
    required this.layerName,
    required this.systemPrompt,
    this.model,
    this.temperature,
    this.maxTokens,
    this.enabled = true,
  });

  WorkerDefinition copyWith({
    String? layerName,
    String? systemPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? enabled,
  }) {
    return WorkerDefinition(
      name: name,
      layerName: layerName ?? this.layerName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enabled: enabled ?? this.enabled,
    );
  }
}

enum ProviderType { openAI, anthropic, ollama }

class ProviderSettings {
  final ProviderType provider;
  final String openaiApiKey;
  final String openaiModel;
  final String anthropicApiKey;
  final String anthropicModel;
  final String ollamaBaseUrl;
  final String ollamaModel;
  final double defaultTemperature;
  final int defaultMaxTokens;

  const ProviderSettings({
    this.provider = ProviderType.openAI,
    this.openaiApiKey = '',
    this.openaiModel = 'gpt-4o',
    this.anthropicApiKey = '',
    this.anthropicModel = 'claude-sonnet-4-20250514',
    this.ollamaBaseUrl = 'http://localhost:11434',
    this.ollamaModel = 'llama3',
    this.defaultTemperature = 0.7,
    this.defaultMaxTokens = 4096,
  });

  factory ProviderSettings.fromJson(Map<String, dynamic> json) {
    return ProviderSettings(
      provider: switch (json['provider']) {
        'Anthropic' => ProviderType.anthropic,
        'Ollama' => ProviderType.ollama,
        _ => ProviderType.openAI,
      },
      openaiApiKey: json['openai_api_key'] as String? ?? '',
      openaiModel: json['openai_model'] as String? ?? 'gpt-4o',
      anthropicApiKey: json['anthropic_api_key'] as String? ?? '',
      anthropicModel:
          json['anthropic_model'] as String? ?? 'claude-sonnet-4-20250514',
      ollamaBaseUrl:
          json['ollama_base_url'] as String? ?? 'http://localhost:11434',
      ollamaModel: json['ollama_model'] as String? ?? 'llama3',
      defaultTemperature:
          (json['default_temperature'] as num?)?.toDouble() ?? 0.7,
      defaultMaxTokens: (json['default_max_tokens'] as num?)?.toInt() ?? 4096,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': switch (provider) {
      ProviderType.openAI => 'OpenAI',
      ProviderType.anthropic => 'Anthropic',
      ProviderType.ollama => 'Ollama',
    },
    'openai_api_key': openaiApiKey,
    'openai_model': openaiModel,
    'anthropic_api_key': anthropicApiKey,
    'anthropic_model': anthropicModel,
    'ollama_base_url': ollamaBaseUrl,
    'ollama_model': ollamaModel,
    'default_temperature': defaultTemperature,
    'default_max_tokens': defaultMaxTokens,
  };

  ProviderSettings copyWith({
    ProviderType? provider,
    String? openaiApiKey,
    String? openaiModel,
    String? anthropicApiKey,
    String? anthropicModel,
    String? ollamaBaseUrl,
    String? ollamaModel,
    double? defaultTemperature,
    int? defaultMaxTokens,
  }) {
    return ProviderSettings(
      provider: provider ?? this.provider,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      openaiModel: openaiModel ?? this.openaiModel,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      anthropicModel: anthropicModel ?? this.anthropicModel,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      defaultTemperature: defaultTemperature ?? this.defaultTemperature,
      defaultMaxTokens: defaultMaxTokens ?? this.defaultMaxTokens,
    );
  }
}
