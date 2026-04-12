enum ProviderType { openAI, anthropic, ollama, custom }

enum CustomApiFormat { openAICompatible, anthropicCompatible, ollamaCompatible }

sealed class ProviderConfig {
  const ProviderConfig({this.model = ''});

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    final type = switch (json['type']) {
      'anthropic' => ProviderType.anthropic,
      'ollama' => ProviderType.ollama,
      'custom' => ProviderType.custom,
      _ => ProviderType.openAI,
    };
    return switch (type) {
      ProviderType.openAI => OpenAIConfig(
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'gpt-4o',
      ),
      ProviderType.anthropic => AnthropicConfig(
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'claude-sonnet-4-20250514',
      ),
      ProviderType.ollama => OllamaConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? 'llama3',
      ),
      ProviderType.custom => CustomConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? '',
        apiFormat: switch (json['apiFormat']) {
          'anthropic' => CustomApiFormat.anthropicCompatible,
          'ollama' => CustomApiFormat.ollamaCompatible,
          _ => CustomApiFormat.openAICompatible,
        },
      ),
    };
  }

  final String model;
  ProviderType get type;
  bool get isConfigured;

  Map<String, dynamic> toJson();
}

class OpenAIConfig extends ProviderConfig {
  const OpenAIConfig({this.apiKey = '', super.model = 'gpt-4o'});

  @override
  ProviderType get type => ProviderType.openAI;

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'openai',
    'apiKey': apiKey,
    'model': model,
  };

  OpenAIConfig copyWith({String? apiKey, String? model}) {
    return OpenAIConfig(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  final String apiKey;
}

class AnthropicConfig extends ProviderConfig {
  const AnthropicConfig({
    this.apiKey = '',
    super.model = 'claude-sonnet-4-20250514',
  });

  @override
  ProviderType get type => ProviderType.anthropic;

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'anthropic',
    'apiKey': apiKey,
    'model': model,
  };

  AnthropicConfig copyWith({String? apiKey, String? model}) {
    return AnthropicConfig(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  final String apiKey;
}

class OllamaConfig extends ProviderConfig {
  const OllamaConfig({this.baseUrl = '', super.model = 'llama3'});

  @override
  ProviderType get type => ProviderType.ollama;

  @override
  bool get isConfigured => baseUrl.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ollama',
    'baseUrl': baseUrl,
    'model': model,
  };

  OllamaConfig copyWith({String? baseUrl, String? model}) {
    return OllamaConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }

  final String baseUrl;
}

class CustomConfig extends ProviderConfig {
  const CustomConfig({
    this.baseUrl = '',
    this.apiKey = '',
    super.model = '',
    this.apiFormat = CustomApiFormat.openAICompatible,
  });

  @override
  ProviderType get type => ProviderType.custom;

  @override
  bool get isConfigured => baseUrl.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'custom',
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'apiFormat': switch (apiFormat) {
      CustomApiFormat.openAICompatible => 'openai',
      CustomApiFormat.anthropicCompatible => 'anthropic',
      CustomApiFormat.ollamaCompatible => 'ollama',
    },
  };

  CustomConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    CustomApiFormat? apiFormat,
  }) {
    return CustomConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      apiFormat: apiFormat ?? this.apiFormat,
    );
  }

  final String baseUrl;
  final String apiKey;
  final CustomApiFormat apiFormat;
}

class ProviderSettings {
  const ProviderSettings({
    this.activeProvider = ProviderType.openAI,
    this.configs = const {
      ProviderType.openAI: OpenAIConfig(),
      ProviderType.anthropic: AnthropicConfig(),
      ProviderType.ollama: OllamaConfig(),
      ProviderType.custom: CustomConfig(),
    },
    this.defaultTemperature = 0.7,
    this.defaultMaxTokens = 4096,
    this.defaultTopP = 1.0,
    this.defaultFrequencyPenalty = 0.0,
    this.defaultPresencePenalty = 0.0,
    this.defaultStopSequences = const [],
    this.defaultTimeout = 60000,
  });

  factory ProviderSettings.fromJson(Map<String, dynamic> json) {
    final active = switch (json['activeProvider']) {
      'Anthropic' => ProviderType.anthropic,
      'Ollama' => ProviderType.ollama,
      'Custom' => ProviderType.custom,
      _ => ProviderType.openAI,
    };
    final configsMap = json['configs'] as Map<String, dynamic>? ?? {};
    final result = <ProviderType, ProviderConfig>{
      ProviderType.openAI: const OpenAIConfig(),
      ProviderType.anthropic: const AnthropicConfig(),
      ProviderType.ollama: const OllamaConfig(),
      ProviderType.custom: const CustomConfig(),
    };
    for (final entry in configsMap.entries) {
      final type = switch (entry.key) {
        'openAI' => ProviderType.openAI,
        'anthropic' => ProviderType.anthropic,
        'ollama' => ProviderType.ollama,
        'custom' => ProviderType.custom,
        _ => null,
      };
      if (type != null && entry.value is Map<String, dynamic>) {
        result[type] = ProviderConfig.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return ProviderSettings(
      activeProvider: active,
      configs: Map.unmodifiable(result),
      defaultTemperature:
          (json['default_temperature'] as num?)?.toDouble() ?? 0.7,
      defaultMaxTokens: (json['default_max_tokens'] as num?)?.toInt() ?? 4096,
      defaultTopP: (json['default_top_p'] as num?)?.toDouble() ?? 1.0,
      defaultFrequencyPenalty:
          (json['default_frequency_penalty'] as num?)?.toDouble() ?? 0.0,
      defaultPresencePenalty:
          (json['default_presence_penalty'] as num?)?.toDouble() ?? 0.0,
      defaultStopSequences: _safeStringList(json['default_stop_sequences']),
      defaultTimeout: (json['default_timeout'] as num?)?.toInt() ?? 60000,
    );
  }

  static List<String> _safeStringList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  final ProviderType activeProvider;
  final Map<ProviderType, ProviderConfig> configs;
  final double defaultTemperature;
  final int defaultMaxTokens;
  final double defaultTopP;
  final double defaultFrequencyPenalty;
  final double defaultPresencePenalty;
  final List<String> defaultStopSequences;
  final int defaultTimeout;

  ProviderConfig get active => configs[activeProvider] ?? configs.values.first;

  List<ProviderConfig> get configured =>
      configs.values.where((c) => c.isConfigured).toList();

  bool isProviderConfigured(ProviderType type) =>
      configs[type]?.isConfigured ?? false;

  Map<String, dynamic> toJson() => {
    'activeProvider': switch (activeProvider) {
      ProviderType.openAI => 'openAI',
      ProviderType.anthropic => 'Anthropic',
      ProviderType.ollama => 'Ollama',
      ProviderType.custom => 'Custom',
    },
    'configs': {
      for (final entry in configs.entries) entry.key.name: entry.value.toJson(),
    },
    'default_temperature': defaultTemperature,
    'default_max_tokens': defaultMaxTokens,
    'default_top_p': defaultTopP,
    'default_frequency_penalty': defaultFrequencyPenalty,
    'default_presence_penalty': defaultPresencePenalty,
    'default_stop_sequences': defaultStopSequences,
    'default_timeout': defaultTimeout,
  };

  ProviderSettings copyWith({
    ProviderType? activeProvider,
    Map<ProviderType, ProviderConfig>? configs,
    double? defaultTemperature,
    int? defaultMaxTokens,
    double? defaultTopP,
    double? defaultFrequencyPenalty,
    double? defaultPresencePenalty,
    List<String>? defaultStopSequences,
    int? defaultTimeout,
  }) {
    return ProviderSettings(
      activeProvider: activeProvider ?? this.activeProvider,
      configs: configs ?? this.configs,
      defaultTemperature: defaultTemperature ?? this.defaultTemperature,
      defaultMaxTokens: defaultMaxTokens ?? this.defaultMaxTokens,
      defaultTopP: defaultTopP ?? this.defaultTopP,
      defaultFrequencyPenalty:
          defaultFrequencyPenalty ?? this.defaultFrequencyPenalty,
      defaultPresencePenalty:
          defaultPresencePenalty ?? this.defaultPresencePenalty,
      defaultStopSequences: defaultStopSequences ?? this.defaultStopSequences,
      defaultTimeout: defaultTimeout ?? this.defaultTimeout,
    );
  }

  ProviderSettings withConfig(ProviderConfig config) {
    return copyWith(configs: {...configs, config.type: config});
  }
}
