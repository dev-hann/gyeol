import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/stat_card.dart';
import 'package:gyeol/shared/widgets/status_badge.dart';
import 'package:intl/intl.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final layersAsync = ref.watch(layersProvider);
    final queueSizeAsync = ref.watch(queueSizeProvider);
    final workersAsync = ref.watch(workersProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              description: 'Overview of your AI worker system',
            ),
            const SizedBox(height: 24),
            tasksAsync.when(
              data: (tasks) {
                final queueSize = queueSizeAsync.valueOrNull ?? 0;
                final pending = tasks
                    .where((t) => t.status == TaskStatus.pending)
                    .length;
                final running = tasks
                    .where((t) => t.status == TaskStatus.running)
                    .length;
                final done = tasks
                    .where((t) => t.status == TaskStatus.done)
                    .length;
                final failed = tasks
                    .where((t) => t.status == TaskStatus.failed)
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Queue',
                            value: '$queueSize',
                            icon: Icons.schedule,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.pending_actions,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Running',
                            value: '$running',
                            icon: Icons.play_circle_outline,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Completed',
                            value: '$done',
                            icon: Icons.check_circle_outline,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Failed',
                            value: '$failed',
                            icon: Icons.error_outline,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildWorkersSection(workersAsync),
                    const SizedBox(height: 16),
                    _buildProvidersSection(settingsAsync),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 400,
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Tasks',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  Text(
                                    '${tasks.length} total',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: tasks.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No tasks yet. Create a task or '
                                        'configure layers to get started.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: tasks.take(20).length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) =>
                                          _TaskTile(
                                            task: tasks[index],
                                            layers:
                                                layersAsync.valueOrNull ?? [],
                                            workers:
                                                workersAsync.valueOrNull ?? [],
                                          ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersSection(AsyncValue<List<WorkerDefinition>> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            async.when(
              data: (workers) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Workers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    '${workers.length} total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              loading: () => const Text(
                'Workers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              error: (_, __) => const Text(
                'Workers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            async.when(
              data: (workers) {
                if (workers.isEmpty) {
                  return const Text(
                    'No workers configured',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                final allLayers = ref.read(layersProvider).valueOrNull ?? [];
                final byLayer = <String, List<WorkerDefinition>>{};
                for (final w in workers) {
                  final lName =
                      allLayers
                          .where((l) => l.id == w.layerId)
                          .firstOrNull
                          ?.name ??
                      '';
                  byLayer.putIfAbsent(lName, () => []).add(w);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: byLayer.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: entry.value.map((w) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: w.enabled
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.tertiary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: w.enabled
                                      ? AppColors.success.withValues(alpha: 0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    w.enabled
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 12,
                                    color: w.enabled
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    w.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: w.enabled
                                          ? AppColors.foreground
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    w.model ?? 'default',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    w.enabled ? 'Enabled' : 'Disabled',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: w.enabled
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersSection(AsyncValue<ProviderSettings> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Providers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            async.when(
              data: (settings) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ProviderType.values.map((type) {
                    final isConfigured = settings.isProviderConfigured(type);
                    final isActive = settings.activeProvider == type;
                    final label = switch (type) {
                      ProviderType.openAI => 'OpenAI',
                      ProviderType.anthropic => 'Anthropic',
                      ProviderType.ollama => 'Ollama',
                      ProviderType.custom => 'Custom',
                    };
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : isConfigured
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.tertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : isConfigured
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive
                                ? Icons.star
                                : isConfigured
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 12,
                            color: isActive
                                ? AppColors.primary
                                : isConfigured
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? AppColors.primaryBright
                                  : isConfigured
                                  ? AppColors.foreground
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive
                                ? 'Active'
                                : isConfigured
                                ? 'Configured'
                                : 'Not configured',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? AppColors.primary
                                  : isConfigured
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.layers,
    required this.workers,
  });
  final AppTask task;
  final List<LayerDefinition> layers;
  final List<WorkerDefinition> workers;

  @override
  Widget build(BuildContext context) {
    final layerName = task.layerId != null
        ? layers.where((l) => l.id == task.layerId).firstOrNull?.name
        : null;
    final workerName = task.workerId != null
        ? workers.where((w) => w.id == task.workerId).firstOrNull?.name
        : null;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        task.taskType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: task.statusLabel),
                      const SizedBox(width: 6),
                      StatusBadge(status: task.priorityLabel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (layerName != null)
                        Text(
                          'Layer: $layerName',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (workerName != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.north_east,
                          size: 10,
                          color: AppColors.textMuted,
                        ),
                        Text(
                          workerName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Text(
                        DateFormat.Hms().format(
                          DateTime.fromMillisecondsSinceEpoch(task.createdAt),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              task.uuid.substring(0, 8),
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
