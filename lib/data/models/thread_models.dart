enum ThreadStatus { idle, running, completed, failed }

class ThreadDefinition {
  const ThreadDefinition({
    required this.id,
    required this.name,
    required this.path,
    this.contextPrompt,
    this.enabled = true,
    this.status = ThreadStatus.idle,
  });

  final int id;
  final String name;
  final String path;
  final String? contextPrompt;
  final bool enabled;
  final ThreadStatus status;

  ThreadDefinition copyWith({
    int? id,
    String? name,
    String? path,
    String? contextPrompt,
    bool? enabled,
    ThreadStatus? status,
  }) {
    return ThreadDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
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
