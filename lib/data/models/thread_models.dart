enum ThreadStatus { idle, running, completed, failed }

class ThreadDefinition {
  const ThreadDefinition({
    required this.name,
    required this.path,
    required this.layerNames,
    this.contextPrompt,
    this.enabled = true,
    this.status = ThreadStatus.idle,
  });
  final String name;
  final String path;
  final List<String> layerNames;
  final String? contextPrompt;
  final bool enabled;
  final ThreadStatus status;

  ThreadDefinition copyWith({
    String? name,
    String? path,
    List<String>? layerNames,
    String? contextPrompt,
    bool? enabled,
    ThreadStatus? status,
  }) {
    return ThreadDefinition(
      name: name ?? this.name,
      path: path ?? this.path,
      layerNames: layerNames ?? this.layerNames,
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
