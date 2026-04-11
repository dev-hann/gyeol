class WorkerDefinition {
  const WorkerDefinition({
    required this.name,
    required this.layerName,
    required this.systemPrompt,
    this.model,
    this.temperature,
    this.maxTokens,
    this.enabled = true,
  });
  final String name;
  final String layerName;
  final String systemPrompt;
  final String? model;
  final double? temperature;
  final int? maxTokens;
  final bool enabled;

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
