enum ThreadStatus { idle, running, completed, failed }

class ThreadDefinition {
  const ThreadDefinition({
    required this.id,
    required this.name,
    required this.path,
    required this.layerIds,
    this.contextPrompt,
    this.enabled = true,
    this.status = ThreadStatus.idle,
  });

  final int id;
  final String name;
  final String path;
  final List<int> layerIds;
  final String? contextPrompt;
  final bool enabled;
  final ThreadStatus status;

  ThreadDefinition copyWith({
    int? id,
    String? name,
    String? path,
    List<int>? layerIds,
    String? contextPrompt,
    bool? enabled,
    ThreadStatus? status,
  }) {
    return ThreadDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      layerIds: layerIds ?? this.layerIds,
      contextPrompt: contextPrompt ?? this.contextPrompt,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
    );
  }

  String get statusLabel {
    switch (status) {
      case ThreadStatus.idle:
        return 'Idle';
      case ThreadStatus.running:
        return 'Running';
      case ThreadStatus.completed:
        return 'Completed';
      case ThreadStatus.failed:
        return 'Failed';
    }
  }
}
