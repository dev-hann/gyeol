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
    final queueSizeAsync = ref.watch(queueSizeProvider);

    return Scaffold(
      body: Padding(
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
            Expanded(
              child: tasksAsync.when(
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
                      Expanded(
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
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
                                          'No tasks yet. Create a task or configure layers to get started.',
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
                                            _TaskTile(task: tasks[index]),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final AppTask task;

  @override
  Widget build(BuildContext context) {
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
                      if (task.layerName != null)
                        Text(
                          'Layer: ${task.layerName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (task.workerName != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.north_east,
                          size: 10,
                          color: AppColors.textMuted,
                        ),
                        Text(
                          task.workerName!,
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
              task.id.substring(0, 8),
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
