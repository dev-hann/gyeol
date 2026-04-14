class LayerDefinition {
  const LayerDefinition({
    required this.id,
    required this.threadId,
    required this.name,
    required this.inputTypes,
    required this.outputTypes,
    this.layerPrompt,
    this.order = 0,
    this.enabled = true,
  });
  final int id;
  final int threadId;
  final String name;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final String? layerPrompt;
  final int order;
  final bool enabled;

  LayerDefinition copyWith({
    int? id,
    int? threadId,
    String? name,
    List<String>? inputTypes,
    List<String>? outputTypes,
    String? layerPrompt,
    int? order,
    bool? enabled,
  }) {
    return LayerDefinition(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      name: name ?? this.name,
      inputTypes: inputTypes ?? this.inputTypes,
      outputTypes: outputTypes ?? this.outputTypes,
      layerPrompt: layerPrompt ?? this.layerPrompt,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}
