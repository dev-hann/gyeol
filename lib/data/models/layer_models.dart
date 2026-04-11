class LayerDefinition {
  const LayerDefinition({
    required this.name,
    required this.inputTypes,
    required this.outputTypes,
    this.layerPrompt,
    this.order = 0,
    this.enabled = true,
  });
  final String name;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final String? layerPrompt;
  final int order;
  final bool enabled;

  LayerDefinition copyWith({
    List<String>? inputTypes,
    List<String>? outputTypes,
    String? layerPrompt,
    int? order,
    bool? enabled,
  }) {
    return LayerDefinition(
      name: name,
      inputTypes: inputTypes ?? this.inputTypes,
      outputTypes: outputTypes ?? this.outputTypes,
      layerPrompt: layerPrompt ?? this.layerPrompt,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}
