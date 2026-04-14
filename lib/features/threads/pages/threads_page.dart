import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/threads/pages/thread_detail_page.dart';
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
                  return _buildThreadList(threads);
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

  Widget _buildThreadList(List<ThreadDefinition> threads) {
    return ListView.separated(
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _ThreadCard(
          thread: thread,
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ThreadDetailPage(
                  threadId: thread.id,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          },
          onRun: () => _runThread(thread),
          onDelete: () => _deleteThread(thread),
          onEdit: () => _showEditThreadDialog(context, thread),
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

    _showThreadDialog(
      context: context,
      title: 'New Thread',
      nameCtl: nameCtl,
      pathCtl: pathCtl,
      promptCtl: promptCtl,
      onConfirm: () async {
        if (nameCtl.text.isEmpty || pathCtl.text.isEmpty) return;
        final thread = ThreadDefinition(
          id: 0,
          name: nameCtl.text,
          path: pathCtl.text,
          contextPrompt: promptCtl.text.isEmpty ? null : promptCtl.text,
        );
        await ref.read(threadsProvider.notifier).saveThread(thread);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  void _showEditThreadDialog(BuildContext context, ThreadDefinition thread) {
    final nameCtl = TextEditingController(text: thread.name);
    final pathCtl = TextEditingController(text: thread.path);
    final promptCtl = TextEditingController(text: thread.contextPrompt ?? '');

    _showThreadDialog(
      context: context,
      title: 'Edit Thread',
      nameCtl: nameCtl,
      pathCtl: pathCtl,
      promptCtl: promptCtl,
      onConfirm: () async {
        if (nameCtl.text.isEmpty || pathCtl.text.isEmpty) return;
        final updated = thread.copyWith(
          path: pathCtl.text,
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
    required VoidCallback onConfirm,
  }) {
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

class _ThreadCard extends ConsumerWidget {
  const _ThreadCard({
    required this.thread,
    required this.onTap,
    required this.onRun,
    required this.onDelete,
    required this.onEdit,
  });

  final ThreadDefinition thread;
  final VoidCallback onTap;
  final VoidCallback onRun;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layersAsync = ref.watch(threadLayersProvider(thread.id));

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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
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
                        layersAsync.when(
                          data: (layers) {
                            if (layers.isEmpty) return const SizedBox.shrink();
                            return Row(
                              children: [
                                const SizedBox(width: 4),
                                StatusBadge(
                                  status:
                                      '${layers.length} layer'
                                      '${layers.length != 1 ? 's' : ''}',
                                  fontSize: 10,
                                ),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
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
                    layersAsync.when(
                      data: (layers) {
                        if (layers.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: layers
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
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
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
