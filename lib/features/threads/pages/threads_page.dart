import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/status_badge.dart';

class ThreadsPage extends ConsumerStatefulWidget {
  const ThreadsPage({super.key});

  @override
  ConsumerState<ThreadsPage> createState() => _ThreadsPageState();
}

class _ThreadsPageState extends ConsumerState<ThreadsPage> {
  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(threadsProvider);
    final layersAsync = ref.watch(layersProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.account_tree_outlined,
              title: 'Threads',
              description:
                  'Execution units combining layers with a working directory',
              action: OutlinedButton.icon(
                onPressed: () => _showAddThreadDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Thread'),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: threadsAsync.when(
                data: (threads) {
                  if (threads.isEmpty) {
                    return EmptyState(
                      icon: Icons.account_tree_outlined,
                      title: 'No threads yet',
                      description:
                          'Create a thread to run layers against a directory',
                      action: ElevatedButton.icon(
                        onPressed: () => _showAddThreadDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Thread'),
                      ),
                    );
                  }
                  return layersAsync.when(
                    data: (layers) => _buildThreadList(threads, layers),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadList(
    List<ThreadDefinition> threads,
    List<LayerDefinition> layers,
  ) {
    return ListView.separated(
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _ThreadCard(
          thread: thread,
          layers: layers,
          onRun: () => _runThread(thread),
          onDelete: () => _deleteThread(thread),
          onEdit: () => _showEditThreadDialog(context, thread, layers),
        );
      },
    );
  }

  Future<void> _runThread(ThreadDefinition thread) async {
    final scheduler = ref.read(schedulerProvider);
    await scheduler.runThread(thread);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text('Thread "${thread.name}" completed'),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _deleteThread(ThreadDefinition thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Delete Thread',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Text('Delete thread "${thread.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(threadsProvider.notifier).deleteThread(thread.id);
    }
  }

  void _showAddThreadDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final pathCtl = TextEditingController();
    final promptCtl = TextEditingController();
    final selectedLayers = <String>[];

    _showThreadDialog(
      context: context,
      title: 'New Thread',
      nameCtl: nameCtl,
      pathCtl: pathCtl,
      promptCtl: promptCtl,
      selectedLayers: selectedLayers,
      onConfirm: () async {
        if (nameCtl.text.isEmpty || pathCtl.text.isEmpty) return;
        final allLayers = ref.read(layersProvider).valueOrNull ?? [];
        final nameToId = <String, int>{for (final l in allLayers) l.name: l.id};
        final layerIds = selectedLayers
            .map((n) => nameToId[n])
            .whereType<int>()
            .toList();
        final thread = ThreadDefinition(
          id: 0,
          name: nameCtl.text,
          path: pathCtl.text,
          layerIds: layerIds,
          contextPrompt: promptCtl.text.isEmpty ? null : promptCtl.text,
        );
        await ref.read(threadsProvider.notifier).saveThread(thread);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  void _showEditThreadDialog(
    BuildContext context,
    ThreadDefinition thread,
    List<LayerDefinition> layers,
  ) {
    final nameCtl = TextEditingController(text: thread.name);
    final pathCtl = TextEditingController(text: thread.path);
    final promptCtl = TextEditingController(text: thread.contextPrompt ?? '');
    final selectedLayers = <String>[];
    final idToName = <int, String>{for (final l in layers) l.id: l.name};
    for (final id in thread.layerIds) {
      final name = idToName[id];
      if (name != null) selectedLayers.add(name);
    }

    _showThreadDialog(
      context: context,
      title: 'Edit Thread',
      nameCtl: nameCtl,
      pathCtl: pathCtl,
      promptCtl: promptCtl,
      selectedLayers: selectedLayers,
      onConfirm: () async {
        if (nameCtl.text.isEmpty || pathCtl.text.isEmpty) return;
        final nameToId = <String, int>{for (final l in layers) l.name: l.id};
        final newLayerIds = selectedLayers
            .map((n) => nameToId[n])
            .whereType<int>()
            .toList();
        final updated = thread.copyWith(
          path: pathCtl.text,
          layerIds: newLayerIds,
          contextPrompt: promptCtl.text.isEmpty ? null : promptCtl.text,
        );
        await ref.read(threadsProvider.notifier).saveThread(updated);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  void _showThreadDialog({
    required BuildContext context,
    required String title,
    required TextEditingController nameCtl,
    required TextEditingController pathCtl,
    required TextEditingController promptCtl,
    required List<String> selectedLayers,
    required VoidCallback onConfirm,
  }) {
    final layersAsync = ref.read(layersProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: Text(
                title,
                style: const TextStyle(color: AppColors.foreground),
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Thread name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pathCtl,
                            decoration: const InputDecoration(
                              labelText: 'Working Directory',
                              hintText: '/path/to/project',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () async {
                            final result = await FilePicker.getDirectoryPath(
                              dialogTitle: 'Select Working Directory',
                            );
                            if (result != null) {
                              pathCtl.text = result;
                            }
                          },
                          icon: const Icon(Icons.folder_open, size: 20),
                          tooltip: 'Browse',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: promptCtl,
                      decoration: const InputDecoration(
                        labelText: 'Context Prompt',
                        hintText: 'Global context for all workers (optional)',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Layers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: layersAsync.when(
                        data: (layers) {
                          if (layers.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No layers available. Create layers first.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: layers.length,
                            itemBuilder: (_, i) {
                              final layer = layers[i];
                              final isSelected = selectedLayers.contains(
                                layer.name,
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(
                                  layer.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${layer.inputTypes.join(", ")} → '
                                  '${layer.outputTypes.join(", ")}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked ?? false) {
                                      selectedLayers.add(layer.name);
                                    } else {
                                      selectedLayers.remove(layer.name);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    if (selectedLayers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Order: ${selectedLayers.join(" → ")}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(onPressed: onConfirm, child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.layers,
    required this.onRun,
    required this.onDelete,
    required this.onEdit,
  });

  final ThreadDefinition thread;
  final List<LayerDefinition> layers;
  final VoidCallback onRun;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final threadLayers = thread.layerIds
        .map((id) => layers.where((l) => l.id == id).firstOrNull)
        .whereType<LayerDefinition>()
        .toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: thread.enabled ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        thread.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: thread.statusLabel, fontSize: 10),
                      if (threadLayers.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        StatusBadge(
                          status:
                              '${threadLayers.length} layer'
                              '${threadLayers.length != 1 ? 's' : ''}',
                          fontSize: 10,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        thread.path,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  if (threadLayers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: threadLayers
                          .map(
                            (l) => Chip(
                              label: Text(
                                l.name,
                                style: const TextStyle(fontSize: 10),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  tooltip: 'Run Thread',
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.success,
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
